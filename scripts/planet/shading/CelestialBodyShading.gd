@tool
extends Resource

class_name CelestialBodyShading

@export var randomize_ : bool :
	set(val):
		randomize_ = val
		emit_signal("changed")

@export var seed_ : int :
	set(val):
		seed_ = val
		emit_signal("changed")

@export var terrain_material : ShaderMaterial :
	set(val):
		terrain_material = val
		emit_signal("changed")

@export var has_ocean : bool :
	set(val):
		has_ocean = val
		emit_signal("changed")

@export_range(0.0, 1.0) var ocean_level : float :
	set(val):
		ocean_level = val
		emit_signal("changed")

@export var ocean_settings : Resource :
	set(val):
		ocean_settings = val
		ocean_settings.resource_name = "Ocean Settings"
		emit_signal("changed")
		ocean_settings.changed.connect(on_data_changed)

@export var has_atmosphere : bool :
	set(val):
		has_atmosphere = val
		emit_signal("changed")

@export var atmosphere_settings : Resource :
	set(val):
		atmosphere_settings = val
		atmosphere_settings.resource_name = "Atmosphere Settings"
		emit_signal("changed")
		atmosphere_settings.changed.connect(on_data_changed)

@export var shading_data_compute : Resource :
	set(val):
		shading_data_compute = val
		shading_data_compute.resource_name = "Shading Data Compute Shader"
		emit_signal("changed")
		shading_data_compute.changed.connect(on_data_changed)

var cached_shading_data : PackedVector2Array

var rng = RandomNumberGenerator.new()

# Initialize
func initialize(_shape : CelestialBodyShape):
	pass

# Set shading properties checked terrain
func set_terrain_properties(_material : Material, _height_min_max : Vector2, _body_scale : float):
	pass

func set_ocean_properties(material : Material):
	ocean_settings.set_properties(material, seed_, randomize_)

func on_data_changed():
	emit_signal("changed")

func generate_shading_data(vertex_array : PackedVector3Array) -> Array:
	rng.set_seed(seed_)
	return shading_data_compute.run(rng, vertex_array)

