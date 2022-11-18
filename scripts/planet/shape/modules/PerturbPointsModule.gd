@tool
extends PerturbModule

class_name PerturbPointsModule

# Create a local rendering device.
var rd := RenderingServer.create_local_rendering_device()

func run(vertices : PackedVector3Array, max_perturb_strength : float) -> PackedVector3Array:
	
	# Load GLSL shader
	var shader_file := load("res://materials/shaders/compute/PerturbPoints.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	var shader := rd.shader_create_from_spirv(shader_spirv)
	
	# Prepare vertices byte array
	var vertices_bytes := vertices.to_byte_array()
	
	# Prepare our params data.
	var params := PackedFloat32Array([
		float(vertices.size()), # numVertices
		max_perturb_strength # maxStrength
	])
	var params_bytes := params.to_byte_array()

	# Create vertices storage buffer, vec3 * num_vertices, assume vec3 = float * 3
	var vertices_buffer := rd.storage_buffer_create(4 * 3 * vertices.size(), vertices_bytes)
	var uniform_vertices := RDUniform.new()
	uniform_vertices.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_vertices.binding = 0
	uniform_vertices.add_id(vertices_buffer)

	# Create params storage buffer TODO: Should be uniform buffer?
	var params_buffer := rd.storage_buffer_create(4 * 2, params_bytes)
	var uniform_params := RDUniform.new()
	uniform_params.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_params.binding = 1
	uniform_params.add_id(params_buffer)
	
	var uniform_set := rd.uniform_set_create([
		uniform_vertices,
		uniform_params
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
	var output_bytes := rd.buffer_get_data(vertices_buffer)
	var output := output_bytes.to_float32_array()
	
	for i in range(vertices.size()):
		vertices[i].x = output[i * 3]
		vertices[i].y = output[i * 3 + 1]
		vertices[i].z = output[i * 3 + 2]

	return vertices
