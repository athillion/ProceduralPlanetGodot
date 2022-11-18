@tool
extends HeightModule

class_name EarthHeightModule

@export var continents_noise : SimplexNoiseSettings :
	set(val):
		continents_noise = val
		emit_signal("changed")
		continents_noise.changed.connect(on_data_changed)

@export var mountains_noise : RidgeNoiseSettings :
	set(val):
		mountains_noise = val
		emit_signal("changed")
		mountains_noise.changed.connect(on_data_changed)

@export var mask_noise : SimplexNoiseSettings :
	set(val):
		mask_noise = val
		emit_signal("changed")
		mask_noise.changed.connect(on_data_changed)

# Continent settings:
@export var ocean_depth_multiplier : float = 5.0 :
	set(val):
		ocean_depth_multiplier = val
		emit_signal("changed")

@export var ocean_floor_depth : float = 1.5 :
	set(val):
		ocean_floor_depth = val
		emit_signal("changed")

@export var ocean_floor_smoothing : float = 0.5 :
	set(val):
		ocean_floor_smoothing = val
		emit_signal("changed")

@export var mountain_blend : float = 1.2 :
	set(val):
		mountain_blend = val
		emit_signal("changed")

# Create a local rendering device.
var rd := RenderingServer.create_local_rendering_device()

func on_data_changed():
	emit_signal("changed")

func run(rng : RandomNumberGenerator, vertices : PackedVector3Array) -> PackedFloat32Array:
	# Load GLSL shader
	var shader_file := load("res://materials/shaders/compute/EarthHeight.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	var shader := rd.shader_create_from_spirv(shader_spirv)

	# Prepare vertices byte array
	var vertices_bytes := vertices.to_byte_array()

	# Prepare heights byte array
	var heights := PackedFloat32Array()
	heights.resize(vertices.size())
	var heights_bytes := heights.to_byte_array()

	# Prepare our params data.
	var params := PackedFloat32Array([
		float(vertices.size()), # numVertices
		ocean_depth_multiplier, # oceanDepthMultiplier
		ocean_floor_depth, # oceanFloorDepth
		ocean_floor_smoothing, # oceanFloorSmoothing
		mountain_blend # mountainBlend
	])
	var params_bytes := params.to_byte_array()

	# Prepare our noise params data.
	var noise_params := PackedFloat32Array(
		continents_noise.get_noise_params(rng) +
		mask_noise.get_noise_params(rng) +
		mountains_noise.get_noise_params(rng)
	)
	var noise_params_bytes := noise_params.to_byte_array()

	# Create vertices storage buffer, vec3 * num_vertices, assume vec3 = float * 3
	var vertices_buffer := rd.storage_buffer_create(4 * 3 * vertices.size(), vertices_bytes)
	var uniform_vertices := RDUniform.new()
	uniform_vertices.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_vertices.binding = 0
	uniform_vertices.add_id(vertices_buffer)

	# Create heights storage buffer, float * num_vertices
	var heights_buffer := rd.storage_buffer_create(4 * vertices.size(), heights_bytes)
	var uniform_heights := RDUniform.new()
	uniform_heights.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_heights.binding = 1
	uniform_heights.add_id(heights_buffer)

	# Create params storage buffer
	# TODO: Should be uniform buffer?
	var params_buffer := rd.storage_buffer_create(4 * 5, params_bytes)
	var uniform_params := RDUniform.new()
	uniform_params.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_params.binding = 2
	uniform_params.add_id(params_buffer)

	# Create noise params storage buffer. vec4 * 3 * 3, vec4 consists of 4 float values
	# TODO: Should be uniform buffer?
	var noise_params_buffer := rd.storage_buffer_create(4 * 4 * 3 * 3, noise_params_bytes)
	var uniform_noise_params := RDUniform.new()
	uniform_noise_params.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_noise_params.binding = 3
	uniform_noise_params.add_id(noise_params_buffer)

	var uniform_set := rd.uniform_set_create([
		uniform_vertices,
		uniform_heights,
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

	#var start_time := Time.get_unix_time_from_system()

	# Submit to GPU and wait for sync
	rd.submit()
	rd.sync()

	#print_debug("%.16f" % (Time.get_unix_time_from_system() - start_time))

	# Read back the data from the buffers
	var output_bytes := rd.buffer_get_data(heights_buffer)
	var output := output_bytes.to_float32_array()

	return output
