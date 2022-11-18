extends Resource

class_name LODParameter

@export var resolution : int :
	set(val):
		resolution = val
		emit_changed()

@export var min_distance : float :
	set(val):
		min_distance = val
		emit_changed()
