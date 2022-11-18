@tool
extends Resource

class_name EarthColors

@export var shore_color_low : Color :
	set(val):
		shore_color_low = val
		emit_signal("changed")

@export var shore_color_high : Color :
	set(val):
		shore_color_high = val
		emit_signal("changed")

@export var flat_color_low_A : Color :
	set(val):
		flat_color_low_A = val
		emit_signal("changed")

@export var flat_color_high_A : Color :
	set(val):
		flat_color_high_A = val
		emit_signal("changed")

@export var flat_color_low_B : Color :
	set(val):
		flat_color_low_B = val
		emit_signal("changed")

@export var flat_color_high_B : Color :
	set(val):
		flat_color_high_B = val
		emit_signal("changed")

@export var steep_low : Color :
	set(val):
		steep_low = val
		emit_signal("changed")

@export var steep_high : Color :
	set(val):
		steep_high = val
		emit_signal("changed")
