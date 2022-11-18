@tool
extends Node3D

@export_node_path var planet_path

@export var timeOfDay : float
@export var sunDst : float = 1.0
@export var timeSpeed : float = 0.01

@onready var _planet : Node3D = get_node(planet_path)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if not Engine.is_editor_hint():
		timeOfDay += delta * timeSpeed;
	global_transform.origin = Vector3(cos(timeOfDay), sin(timeOfDay), 0) * sunDst
	var planet_to_sun = (self.global_position - _planet.global_position).normalized()
	var up_vector = Vector3(-planet_to_sun.y, planet_to_sun.x, 0.0)
	look_at(_planet.global_position, up_vector)
