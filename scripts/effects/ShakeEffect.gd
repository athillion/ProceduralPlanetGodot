extends Node

class_name ShakeEffect

@export var enabled : bool = true

@export var is_shaking : bool = false
@export var amount : Vector3 = Vector3.ZERO
@export var speed : float = 0.0

var rng := RandomNumberGenerator.new()

var prev_diff : Vector3 = Vector3.ZERO

func _process(delta):
	if not (get_parent() is Camera3D and get_parent().current and enabled):
		return
	
	get_parent().position -= prev_diff
	prev_diff = Vector3.ZERO
	
	if not is_shaking:
		return
	
	var vec := Vector3(
		rng.randf_range(-1.0, 1.0),
		rng.randf_range(-1.0, 1.0),
		rng.randf_range(-1.0, 1.0)
	)
	
	var diff : Vector3 = get_parent().global_transform.basis * amount * vec * speed * delta
	get_parent().position += diff
	prev_diff = diff
	
