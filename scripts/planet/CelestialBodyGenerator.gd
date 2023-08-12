@tool
extends Node3D

class_name CelestialBodyGenerator

@export var is_ocean : bool = false :
	set(val):
		is_ocean = val
		on_shape_data_changed()

enum PreviewMode {LOD0, LOD1, LOD2, CollisionRes}
@export var resolution_settings : Resource :
	set(val):
		resolution_settings = val
		resolution_settings.resource_name = "Resolution Settings"
		resolution_settings.changed.connect(on_resolution_data_changed)

@export var preview_mode: PreviewMode = PreviewMode.LOD2 :
	set(val):
		preview_mode = val
		on_shape_data_changed()

@export_node_path("Camera3D") var camera_path
@onready var camera : Camera3D = get_node(camera_path)

@export var body : Resource :
	get:
		return body
	set(val):
		body = val
		body.resource_name = "Body Settings"
		body.shape_changed.connect(on_shape_data_changed)
		body.shade_changed.connect(on_shade_data_changed)

var debug_double_update : bool = true
var debug_num_updates : int

@onready var preview_mesh := ArrayMesh.new()
var collision_mesh : Mesh
var lod_meshes : Array

#var vertex_buffer : PackedVector3Array

var shape_settings_updated : bool = true
var shading_noise_settings_updated : bool = true

var height_min_max : Vector2

var active_LOD_index : int = -1
# material is mesh.material_override

var sphere_generators := {} # int -> PlanetSphereMesh

func _ready():
	#on_data_changed()
	if not Engine.is_editor_hint():
		handle_game_mode_generation() 

func on_shape_data_changed():
	shape_settings_updated = true

func on_shade_data_changed():
	shading_noise_settings_updated = true

func on_resolution_data_changed():
	if resolution_settings != null:
		resolution_settings.clamp_resolutions()

func _process(_delta):
	if Engine.is_editor_hint():
		handle_edit_mode_generation()
	else:
		var distance_to_camera : float = \
			self.global_position.distance_to(camera.global_position)
		
		if lod_meshes.size() > 0:
			for i in range(resolution_settings.lod_parameters.size()):
				var lod : LODParameter = resolution_settings.lod_parameters[i]
				if distance_to_camera < body_scale() + lod.min_distance:
					set_LOD(i)
					# Do not pick a lower resolution if within
					# distance for a higher one.
					break  

func handle_game_mode_generation():
	if can_generate_mesh():
		# Generate LOD meshes
		lod_meshes.clear()
		lod_meshes.resize(resolution_settings.num_LOD_levels())
		for i in range(lod_meshes.size()):
			lod_meshes[i] = ArrayMesh.new()
		for i in range(lod_meshes.size()):
			if lod_meshes[i] == null:
				lod_meshes[i] = ArrayMesh.new()
			else:
				lod_meshes[i].clear_surfaces()
			var lod_terrain_height_min_max : Vector2 = generate_terrain_mesh(
				lod_meshes[i], resolution_settings.get_lod_resolution(i))
			if i == 0:
				height_min_max = lod_terrain_height_min_max
		
		# Generate collision mesh
		collision_mesh = ArrayMesh.new()
		generate_collision_mesh(resolution_settings.collider)
		
		if body.shading != null:
			# Create terrain renderer and set shading properties checked the
			# instanced material
			$MeshInstance3d.material_override = \
				body.shading.terrain_material.duplicate()
			body.shading.initialize(body.shape)
			body.shading.set_terrain_properties(
				$MeshInstance3d.material_override, height_min_max, body_scale())
		
		set_LOD(2)
	
	elif is_ocean:
		
		# Generate LOD meshes
		lod_meshes.clear()
		lod_meshes.resize(resolution_settings.num_LOD_levels())
		for i in range(lod_meshes.size()):
			lod_meshes[i] = ArrayMesh.new()
		for i in range(lod_meshes.size()):
			if lod_meshes[i] == null:
				lod_meshes[i] = ArrayMesh.new()
			else:
				lod_meshes[i].clear_surfaces()
			generate_ocean_mesh(
				lod_meshes[i], resolution_settings.get_lod_resolution(i))
		
		# Generate collision mesh
		collision_mesh = ArrayMesh.new()
		generate_collision_mesh(resolution_settings.collider, true)

# Handles creation of celestial body in the editor
# This allows for updating the shape/shading settings
func handle_edit_mode_generation():
	if can_generate_mesh():
		# Update shape settings and shading noise
		if shape_settings_updated:
			shading_noise_settings_updated = true
			
			if preview_mesh == null:
				preview_mesh = ArrayMesh.new()
			else:
				preview_mesh.clear_surfaces()
			height_min_max = generate_terrain_mesh(preview_mesh, pick_terrain_res())

			call_deferred("_set_mesh", preview_mesh)

		# If only shading noise has changed, update it separately from shape to save time
		if shading_noise_settings_updated and body.shading != null:
			shading_noise_settings_updated = false

			# Create terrain renderer and set shading properties checked the instanced material
			$MeshInstance3d.material_override = body.shading.terrain_material.duplicate()
			body.shading.initialize(body.shape)
			body.shading.set_terrain_properties(
				$MeshInstance3d.material_override, height_min_max, body_scale())
			
			if not shape_settings_updated:
				var arrays : Array = preview_mesh.surface_get_arrays(0)
				
				# Shading noise data
				body.shading.initialize(body.shape)
				var shading_data : Array = \
					body.shading.generate_shading_data(arrays[Mesh.ARRAY_VERTEX])
				var uv1 : PackedVector2Array = shading_data[0]
				var uv2 : PackedVector2Array = shading_data[1]
				arrays[Mesh.ARRAY_TEX_UV] = uv1
				arrays[Mesh.ARRAY_TEX_UV2] = uv2
				
				preview_mesh.clear_surfaces()
				preview_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				
				call_deferred("_set_mesh", preview_mesh)
		
		shape_settings_updated = false
		shading_noise_settings_updated = false
			
	elif is_ocean:
		if shape_settings_updated:
			shape_settings_updated = false
			shading_noise_settings_updated = false
			
			if preview_mesh == null:
				preview_mesh = ArrayMesh.new()
			else:
				preview_mesh.clear_surfaces()
			generate_ocean_mesh(preview_mesh, pick_terrain_res())
			
			call_deferred("_set_mesh", preview_mesh)

func can_generate_mesh() -> bool:
	return body != null and body.shape != null and body.shape.height_map_compute != null

func set_LOD(LOD_index : int):
	if LOD_index != active_LOD_index:
		active_LOD_index = LOD_index
		call_deferred("_set_mesh", lod_meshes[LOD_index])

func _set_mesh(_mesh : Mesh):
	$MeshInstance3d.mesh = _mesh

func _set_collision_mesh(_mesh : Mesh):
	var shape : Shape3D = _mesh.create_trimesh_shape()
	$CollisionShape3d.shape = shape

# Generates terrain mesh based checked heights generated by the Shape3D object
# Shading data from the Shading object is stored in the mesh uvs
# Returns the min/max height of the terrain
func generate_terrain_mesh(_mesh : ArrayMesh, resolution : int) -> Vector2:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var verts_and_tris : Array = create_sphere_verts_and_tris(resolution)
	var vertices : PackedVector3Array = verts_and_tris[0]
	var triangles : PackedInt32Array = verts_and_tris[1]
	
	var edge_length : float = (vertices[triangles[0]] - vertices[triangles[1]]).length()
	
	# Set heights
	var heights : PackedFloat32Array = body.shape.calculate_heights(vertices)
	
	# Perturb vertices to give terrain a less perfectly smooth appearance
	if body.shape.perturb_vertices and body.shape.perturb_compute != null:
		var perturb : Resource = body.shape.perturb_compute
		var max_perturb_strength : float = body.shape.perturb_strength * edge_length / 2.0
		
		var pert_data : PackedVector3Array = perturb.run(vertices, max_perturb_strength)
		vertices = pert_data
	
	# Calculate terrain min/max height and set heights of vertices
	var min_height : float = INF
	var max_height : float = -INF
	for i in range(heights.size()):
		var height : float = heights[i]
		vertices[i] *= height
		min_height = min(min_height, height)
		max_height = max(max_height, height)
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = triangles
	
	var normals : PackedVector3Array = recalculate_normals(vertices, triangles)
	arrays[Mesh.ARRAY_NORMAL] = normals
	
	# Shading noise data
	if body.shading != null:
		body.shading.initialize(body.shape)
		var shading_data : Array = body.shading.generate_shading_data(vertices)
		var uv1 : PackedVector2Array = shading_data[0]
		var uv2 : PackedVector2Array = shading_data[1]
		arrays[Mesh.ARRAY_TEX_UV] = uv1
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
	
	# Create crude tangents (vectors perpendicular to surface normal)
	# This is needed (even though normal mapping is being done with triplanar)
	# because surfaceshader wants normals in tangent space
	var crude_tangents := PackedFloat32Array()
	crude_tangents.resize(vertices.size() * 4)
	for i in range(vertices.size()):
		var normal : Vector3 = normals[i]
		crude_tangents[i * 4] = -normal.z
		crude_tangents[i * 4 + 1] = 0.0
		crude_tangents[i * 4 + 2] = normal.x
		crude_tangents[i * 4 + 3] = 1.0
	
	arrays[Mesh.ARRAY_TANGENT] = crude_tangents
	
	# Create mesh
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	return Vector2(min_height, max_height)

func generate_collision_mesh(resolution : int, _is_ocean : bool = false):
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var verts_and_tris : Array = create_sphere_verts_and_tris(resolution)
	var vertices : PackedVector3Array = verts_and_tris[0]
	var triangles : PackedInt32Array = verts_and_tris[1]
	
	if not _is_ocean:
		var edge_length : float = (vertices[triangles[0]] - vertices[triangles[1]]).length()
		
		# Set heights
		var heights : PackedFloat32Array = body.shape.calculate_heights(vertices)
		
		# Perturb vertices to give terrain a less perfectly smooth appearance
		if body.shape.perturb_vertices and body.shape.perturb_compute != null:
			var perturb : Resource = body.shape.perturb_compute
			var max_perturb_strength : float = body.shape.perturb_strength * edge_length / 2.0
			
			var pert_data : PackedVector3Array = perturb.run(vertices, max_perturb_strength)
			vertices = pert_data
		
		for i in range(heights.size()):
			var height : float = heights[i]
			vertices[i] *= height
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = triangles
	
	# Create mesh
	collision_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	call_deferred("_set_collision_mesh", collision_mesh)

func generate_ocean_mesh(_mesh : ArrayMesh, resolution : int):
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var verts_and_tris : Array = create_sphere_verts_and_tris(resolution)
	var vertices : PackedVector3Array = verts_and_tris[0]
	var triangles : PackedInt32Array = verts_and_tris[1]
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = triangles
	
	var normals : PackedVector3Array = recalculate_normals(vertices, triangles)
	arrays[Mesh.ARRAY_NORMAL] = normals
	
	# Create mesh
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func pick_terrain_res() -> int:
	if Engine.is_editor_hint():
		if preview_mode == PreviewMode.LOD0 and resolution_settings.num_LOD_levels() > 0:
			return resolution_settings.lod_parameters[0].resolution
		if preview_mode == PreviewMode.LOD1 and resolution_settings.num_LOD_levels() > 1:
			return resolution_settings.lod_parameters[1].resolution
		if preview_mode == PreviewMode.LOD2 and resolution_settings.num_LOD_levels() > 2:
			return resolution_settings.lod_parameters[2].resolution
		if preview_mode == PreviewMode.CollisionRes:
			return resolution_settings.collider
	return 0

func get_ocean_radius() -> float:
	if not body.shading.has_ocean:
		return 0.0
	return unscaled_ocean_radius() * body_scale()

func unscaled_ocean_radius() -> float:
	return lerp(height_min_max.x, 1.0, body.shading.ocean_level)

func body_scale() -> float:
	# Body radius is determined by the celestial body class,
	# which sets the local scale of the generator object (this object)
	return transform.basis.x.length()

func point_on_planet(dir_from_origin : Vector3):
	var vertex := PackedVector3Array([dir_from_origin.normalized()])
	var height : PackedFloat32Array = body.shape.calculate_heights(vertex)
	return dir_from_origin * height[0] * body_scale()

# Generate sphere (or reuse if already generated) and return a copy of the vertices and triangles
func create_sphere_verts_and_tris(resolution : int) -> Array:
	
	if not sphere_generators.has(resolution):
		sphere_generators[resolution] = PlanetSphereMesh.new(resolution)
	
	var generator : PlanetSphereMesh = sphere_generators[resolution] as PlanetSphereMesh
	
	var vertices : PackedVector3Array = generator.vertices.duplicate()
	var triangles : PackedInt32Array = generator.triangles.duplicate()
	return [vertices, triangles]

class TerrainData:
	var heights : PackedFloat32Array
	var uv1 : PackedVector2Array
	var uv2 : PackedVector2Array

func recalculate_normals(
	vertices : PackedVector3Array,
	triangles : PackedInt32Array
) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	# Recalculate Normals
	for a in range(0, triangles.size(), 3):
		var b : int = a + 1
		var c : int = a + 2
		var ab : Vector3 = vertices[triangles[b]] - vertices[triangles[a]]
		var bc : Vector3 = vertices[triangles[c]] - vertices[triangles[b]]
		var ca : Vector3 = vertices[triangles[a]] - vertices[triangles[c]]
		var cross_ab_bc : Vector3 = ab.cross(bc) * -1.0
		var cross_bc_ca : Vector3 = bc.cross(ca) * -1.0
		var cross_ca_ab : Vector3 = ca.cross(ab) * -1.0
		normals[triangles[a]] += cross_ab_bc + cross_bc_ca + cross_ca_ab
		normals[triangles[b]] += cross_ab_bc + cross_bc_ca + cross_ca_ab
		normals[triangles[c]] += cross_ab_bc + cross_bc_ca + cross_ca_ab
	
	# Make sure normals are within 0 and 1
	for i in range(normals.size()):
		normals[i] = normals[i].normalized()
	
	return normals
