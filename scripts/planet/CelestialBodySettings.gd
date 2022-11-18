@tool
extends Resource

class_name CelestialBodySettings

signal shape_changed
signal shade_changed

@export var shape : Resource :
	get:
		return shape
	set(val):
		shape = val
		emit_signal("shape_changed")
		shape.changed.connect(on_shape_data_changed)

@export var shading : Resource :
	get:
		return shading
	set(val):
		shading = val
		emit_signal("shade_changed")
		shading.changed.connect(on_shade_data_changed)

func on_shape_data_changed():
	emit_signal("shape_changed")

func on_shade_data_changed():
	emit_signal("shade_changed")
