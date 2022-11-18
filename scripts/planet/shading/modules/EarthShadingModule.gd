@tool
extends ShadingDataModule

class_name EarthShadingModule

# Noise
@export var detail_warp_noise : SimplexNoiseSettings :
	set(val):
		detail_warp_noise = val
		emit_signal("changed")
		detail_warp_noise.changed.connect(on_data_changed)

@export var detail_noise : SimplexNoiseSettings :
	set(val):
		detail_noise = val
		emit_signal("changed")
		detail_noise.changed.connect(on_data_changed)

@export var large_noise : SimplexNoiseSettings :
	set(val):
		large_noise = val
		emit_signal("changed")
		large_noise.changed.connect(on_data_changed)

@export var small_noise : SimplexNoiseSettings :
	set(val):
		small_noise = val
		emit_signal("changed")
		small_noise.changed.connect(on_data_changed)

# Second warp
var warp2_noise := SimplexNoiseSettings.new()
var noise2_noise := SimplexNoiseSettings.new()

# Create a local rendering device.
var rd := RenderingServer.create_local_rendering_device()

func on_data_changed():
	emit_signal("changed")

func run(rng : RandomNumberGenerator, vertices : PackedVector3Array) -> Array:
	
	var shading_data := PackedFloat32Array()
	shading_data.resize(vertices.size() * 4)

	# Load GLSL shader
	var shader_file := load("res://materials/shaders/compute/EarthShading.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	var shader := rd.shader_create_from_spirv(shader_spirv)

	# Prepare vertices byte array
	var vertices_bytes := vertices.to_byte_array()

	# Prepare shading_data byte array
	var shading_data_bytes := shading_data.to_byte_array()

	# Prepare our params data.
	var params := PackedFloat32Array([
		float(vertices.size()) # numVertices
	])
	var params_bytes := params.to_byte_array()

	# Prepare our noise params data.
	var noise_params := PackedFloat32Array(
		detail_warp_noise.get_noise_params(rng) +
		detail_noise.get_noise_params(rng) +
		large_noise.get_noise_params(rng) +
		small_noise.get_noise_params(rng) +
		warp2_noise.get_noise_params(rng) +
		noise2_noise.get_noise_params(rng)
	)
	var noise_params_bytes := noise_params.to_byte_array()

	# Create vertices storage buffer, vec3 * num_vertices, assume vec3 = float * 3
	var vertices_buffer := rd.storage_buffer_create(4 * 3 * vertices.size(), vertices_bytes)
	var uniform_vertices := RDUniform.new()
	uniform_vertices.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_vertices.binding = 0
	uniform_vertices.add_id(vertices_buffer)

	# Create shading_data storage buffer, float * 4 * num_vertices
	var shading_data_buffer := rd.storage_buffer_create(4 * 4 * vertices.size(), shading_data_bytes)
	var uniform_shading_data := RDUniform.new()
	uniform_shading_data.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_shading_data.binding = 1
	uniform_shading_data.add_id(shading_data_buffer)

	# Create params storage buffer TODO: Should be uniform buffer?
	var params_buffer := rd.storage_buffer_create(4, params_bytes)
	var uniform_params := RDUniform.new()
	uniform_params.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_params.binding = 2
	uniform_params.add_id(params_buffer)

	# Create noise params storage buffer. vec4 * 6 * 3, vec4 consists of 4 float values
	# TODO: Should be uniform buffer?
	var noise_params_buffer := rd.storage_buffer_create(4 * 4 * 6 * 3, noise_params_bytes)
	var uniform_noise_params := RDUniform.new()
	uniform_noise_params.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_noise_params.binding = 3
	uniform_noise_params.add_id(noise_params_buffer)

	var uniform_set := rd.uniform_set_create([
		uniform_vertices,
		uniform_shading_data,
		uniform_params,
		uniform_noise_params
	], shader, 0)

	# Create a compute pipeline
	var pipeline := rd.compute_pipeline_create(shader)
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	# Divide computations into 512-sized work groups, rounded up
	rd.compute_list_dispatch(compute_list, ceil(vertices.size() / 512.0), 1, 1)
	rd.compute_list_end()

	# Submit to GPU and wait for sync
	rd.submit()
	rd.sync()

	# Read back the data from the buffers
	var output_bytes := rd.buffer_get_data(shading_data_buffer)
	var output := output_bytes.to_float32_array()

	var uv1 := PackedVector2Array()
	var uv2 := PackedVector2Array()
	uv1.resize(vertices.size())
	uv2.resize(vertices.size())
	for i in range(vertices.size()):
		var _uv1 := Vector2(output[i * 4], output[i * 4 + 1])
		var _uv2 := Vector2(output[i * 4 + 2], output[i * 4 + 3])
		uv1[i] = _uv1
		uv2[i] = _uv2
	
	return [uv1, uv2]
