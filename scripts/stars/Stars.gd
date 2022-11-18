@tool
extends Node3D

class_name Stars

@export var seed_ : int = 0 : 
	set(val):
		seed_ = val
		on_data_updated()

@export var num_stars : int = 0 :
	set(val):
		num_stars = val
		on_data_updated()

@export var num_verts_per_star : int = 5 :
	set(val):
		num_verts_per_star = val
		on_data_updated()

@export var size_min_max : Vector2 :
	set(val):
		size_min_max = val
		on_data_updated()
		
@export var min_brightness : float = 0.0 :
	set(val):
		min_brightness = val
		on_data_updated()

@export var max_brightness : float = 1.0 :
	set(val):
		max_brightness = val
		on_data_updated()

@export var distance : float = 10.0 :
	set(val):
		distance = val
		on_data_updated()

@export var day_time_fade : float = 4.0 :  # higher value means it needs to be darker before stars will appear 
	set(val):
		day_time_fade = val
		on_data_updated()

@export var material : Material :
	set(val):
		material = val
		on_data_updated()

@export var colour_spectrum : GradientTexture2D :
	set(val):
		colour_spectrum = val
		on_data_updated()
		colour_spectrum.changed.connect(on_data_updated)

@export var cluster_colour_spectrum : GradientTexture2D :
	set(val):
		cluster_colour_spectrum = val
		on_data_updated()
		cluster_colour_spectrum.changed.connect(on_data_updated)

@export var stars_clustering_noise : FastNoiseLite :
	set(val):
		stars_clustering_noise = val
		on_data_updated()
		stars_clustering_noise.changed.connect(on_data_updated)

@export_range(0.0, 10.0) var stars_clustering_amplitude : float = 1.0 :
	set(val):
		stars_clustering_amplitude = val
		on_data_updated()

@export_node_path(Node3D) var generator_path
@export_node_path(Viewport) var source_viewport_path

@onready var generator : CelestialBodyGenerator = get_node(generator_path)
@onready var source_viewport : Viewport = get_node(source_viewport_path)

var cam : Camera3D
var settings_updated : bool = false

var rng = RandomNumberGenerator.new()

# Called when the node enters the scene tree for the first time.
func _ready():
	settings_updated = true
	initialize(settings_updated)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	initialize(settings_updated)
	settings_updated = false

func on_data_updated():
	settings_updated = true

func initialize(regenerate_mesh : bool):
	if regenerate_mesh:
		generate_mesh()
	
	cam = get_viewport().get_camera_3d()
	
	material.set_shader_parameter("MainTex", source_viewport.get_texture())
	material.set_shader_parameter("Spectrum", colour_spectrum)
	material.set_shader_parameter("ClusterSpectrum", cluster_colour_spectrum)
	material.set_shader_parameter("daytimeFade", day_time_fade)
	material.set_shader_parameter("OceanRadius", generator.get_ocean_radius())
	material.set_shader_parameter("PlanetCentre", generator.global_position)

func generate_mesh():
	var mesh : ArrayMesh = ArrayMesh.new()
	
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertices := PackedVector3Array()
	var triangles := PackedInt32Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	
	rng.set_seed(seed_)
	for i in range(num_stars):
		var dir : Vector3 = rand_on_unit_sphere(rng)
		var cluster_noise : float = \
			stars_clustering_amplitude * stars_clustering_noise.get_noise_3dv(dir)
		dir += Vector3.ONE * cluster_noise
		dir = dir.normalized()
		var mesh_data : Array = generate_circle(dir, vertices.size())
		vertices.append_array(mesh_data[0])
		triangles.append_array(mesh_data[1])
		uvs.append_array(mesh_data[2])
		var col_data := PackedColorArray()
		col_data.resize(mesh_data[0].size())
		col_data.fill(Color(abs(cluster_noise),0.0,0.0))
		cols.append_array(col_data)
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = triangles
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cols
	
	# Create mesh
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	call_deferred("_set_mesh", mesh)

func _set_mesh(_mesh : Mesh):
	$StarsMesh.mesh = _mesh
	$StarsMesh.material_override = material.duplicate()

func generate_circle(dir : Vector3, index_offset : int) -> Array:
	var size : float = rng.randf_range(size_min_max.x, size_min_max.y)
	var brightness : float = rng.randf_range(min_brightness, max_brightness)
	var spectrumT : float = rng.randf()
	
	var axisA = dir.cross(Vector3.UP).normalized()
	if axisA == Vector3.ZERO:
		axisA = dir.cross(Vector3.FORWARD).normalized()
	var axisB = dir.cross(axisA)
	var centre : Vector3 = dir * distance
	
	var verts := PackedVector3Array()
	verts.resize(num_verts_per_star + 1)
	var uvs := PackedVector2Array()
	uvs.resize(num_verts_per_star + 1)
	var tris := PackedInt32Array()
	tris.resize(num_verts_per_star * 3)
	
	verts[0] = centre
	uvs[0] = Vector2(brightness, spectrumT)
	
	for vert_index in range(num_verts_per_star):
		var curr_angle := 2.0 * PI * vert_index / float(num_verts_per_star)
		var vert : Vector3 = centre + (axisA * sin(curr_angle) + axisB * cos(curr_angle)) * size
		verts[vert_index + 1] = vert
		uvs[vert_index + 1] = Vector2(0, spectrumT)
		
		if vert_index < num_verts_per_star:
			tris[vert_index * 3] = index_offset
			tris[vert_index * 3 + 1] = (vert_index + 1) + index_offset
			tris[vert_index * 3 + 2] = ((vert_index + 1) % (num_verts_per_star) + 1) + index_offset
	
	var array := []
	array.append(verts)
	array.append(tris)
	array.append(uvs)
	
	return array;

func rand_on_unit_sphere(rng) -> Vector3:
	var x : float = rng.randf_range(-1.0, 1.0)
	var y : float = rng.randf_range(-1.0, 1.0)
	var z : float = rng.randf_range(-1.0, 1.0)
	var dir := Vector3(x, y, z).normalized()
	if dir.length() == 0.0:
		dir = Vector3.LEFT
	return dir
