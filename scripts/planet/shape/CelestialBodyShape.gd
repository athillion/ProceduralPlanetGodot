@tool
extends Resource

class_name CelestialBodyShape

@export var randomize_ : bool :
	set(val):
		randomize_ = val
		emit_signal("changed")

@export var seed_ : int :
	set(val):
		seed_ = val
		emit_signal("changed")

@export var height_map_compute : Resource :
	set(val):
		height_map_compute = val
		height_map_compute.resource_name = "Height Module"
		emit_signal("changed")
		height_map_compute.changed.connect(on_data_changed)

@export var perturb_vertices : bool :
	set(val):
		perturb_vertices = val
		emit_signal("changed")

@export var perturb_compute : Resource :
	set(val):
		perturb_compute = val
		perturb_compute.resource_name = "Perturb Module"
		emit_signal("changed")
		perturb_compute.changed.connect(on_data_changed)
		
@export_range(0.0, 1.0) var perturb_strength : float = 0.7 :
	set(val):
		perturb_strength = val
		emit_signal("changed")

var height_buffer : PackedFloat32Array

var rng = RandomNumberGenerator.new()

func on_data_changed():
	emit_signal("changed")

func calculate_heights(vertex_array : PackedVector3Array) -> PackedFloat32Array:
	rng.set_seed(seed_)
	return height_map_compute.run(rng, vertex_array)

