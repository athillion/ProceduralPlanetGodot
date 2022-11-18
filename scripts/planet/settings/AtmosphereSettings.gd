@tool
extends Resource

class_name AtmosphereSettings

@export var texture_size : int = 256 :
	set(val):
		texture_size = val
		on_data_changed()

@export var in_scattering_points : int = 10 :
	set(val):
		in_scattering_points = val
		on_data_changed()

@export var optical_depth_points : int = 10 :
	set(val):
		optical_depth_points = val
		on_data_changed()

@export var density_falloff : float = 0.25 :
	set(val):
		density_falloff = val
		on_data_changed()

@export var wavelengths := Vector3(700, 530, 460) :
	set(val):
		wavelengths = val
		on_data_changed()

@export var scattering_strength : float = 20.0 :
	set(val):
		scattering_strength = val
		on_data_changed()

@export var intensity : float = 1.0 :
	set(val):
		intensity = val
		on_data_changed()

@export var dither_strength : float = 0.8 :
	set(val):
		dither_strength = val
		on_data_changed()

@export var dither_scale : float = 4.0 :
	set(val):
		dither_scale = val
		on_data_changed()

@export_range(0.0, 1.0) var atmosphere_scale : float = 0.5 :
	set(val):
		atmosphere_scale = val
		on_data_changed()

@export var blue_noise_texture : Texture2D :
	set(val):
		blue_noise_texture = val
		on_data_changed()

@onready var rng = RandomNumberGenerator.new()

var optical_depth_baked : bool = false
@export var optical_depth_texture := ImageTexture.new()

# Create a local rendering device.
var rd := RenderingServer.create_local_rendering_device()

func on_data_changed():
	optical_depth_baked = false
	emit_signal("changed")

func set_properties(material : Material, body_radius : float):
	var atmosphere_radius : float = (1.0 + atmosphere_scale) * body_radius
	
	material.set_shader_parameter("NumInScatteringPoints", in_scattering_points)
	material.set_shader_parameter("NumOpticalDepthPoints", optical_depth_points)
	material.set_shader_parameter("AtmosphereRadius", atmosphere_radius)
	material.set_shader_parameter("PlanetRadius", body_radius)
	material.set_shader_parameter("DensityFalloff", density_falloff)
	
	# Strength of (rayleigh) scattering is inversely proportional to wavelength^4
	var scatterX : float = pow(400.0 / wavelengths.x, 4.0);
	var scatterY : float = pow(400.0 / wavelengths.y, 4.0);
	var scatterZ : float = pow(400.0 / wavelengths.z, 4.0);
	material.set_shader_parameter("ScatteringCoefficients",
		Vector3(scatterX, scatterY, scatterZ) * scattering_strength)
	material.set_shader_parameter("Intensity", intensity)
	material.set_shader_parameter("DitherStrength", dither_strength)
	material.set_shader_parameter("DitherScale", dither_scale)
	
	material.set_shader_parameter("BlueNoise", blue_noise_texture)
	
	if not optical_depth_baked:# and not Engine.is_editor_hint():
		optical_depth_baked = true

		optical_depth_compute()
	
	material.set_shader_parameter("BakedOpticalDepth", optical_depth_texture)

func optical_depth_compute():
	
	# Load GLSL shader
	var shader_file := load("res://materials/shaders/compute/AtmosphereTexture.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	var shader := rd.shader_create_from_spirv(shader_spirv)
	
	# Prepare our rendering texture
	var fmt = RDTextureFormat.new()
	fmt.width = texture_size
	fmt.height = texture_size
	fmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT\
					| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT\
					| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	fmt.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	var view = RDTextureView.new()
	var texture_buffer := rd.texture_create(fmt, view)
	
	# Prepare our data. We use doubles in the shader, so we need 64 bit.
	var input_params := PackedFloat32Array([
		texture_size, # textureSize
		optical_depth_points, # numOutScatteringSteps
		1.0 + atmosphere_scale, # atmosphereRadius
		density_falloff # densityFalloff
	])
	var input_bytes := input_params.to_byte_array()

	# Create image2D uniform
	var uniform_tex := RDUniform.new()
	uniform_tex.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_tex.binding = 0
	uniform_tex.add_id(texture_buffer)
	
	# Create a storage buffer that can hold 4 float values.
	# 4 bytes * 4 variables
	var buffer := rd.storage_buffer_create(4 * 4, input_bytes)
	var uniform_params := RDUniform.new()
	uniform_params.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_params.binding = 1
	uniform_params.add_id(buffer)
	
	var uniform_set := rd.uniform_set_create([uniform_tex, uniform_params], shader, 0)
	
	# Create a compute pipeline
	var pipeline := rd.compute_pipeline_create(shader)
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list,
		ceil(texture_size / 16.0), ceil(texture_size / 16.0), 1)
	rd.compute_list_end()

	# Submit to GPU and wait for sync
	rd.submit()
	rd.sync()

	# Read back the data from the buffers
	var output_bytes := rd.texture_get_data(texture_buffer, 0)
	
	var img := Image.new()
	img = Image.create_from_data(
		texture_size, texture_size, false, Image.FORMAT_RGBAF, output_bytes)
	optical_depth_texture = ImageTexture.create_from_image(img)
