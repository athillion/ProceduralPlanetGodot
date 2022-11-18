extends Node3D

class_name AtmosphereEntryExitMonitor

@export_node_path(Node3D) var planet_path

@export var shake_strength : float = 40.0

@onready var planet : CelestialBodyGenerator = get_node(planet_path)

@onready var atmosphere_inner : Area3D = $AtmosphereInner
@onready var atmosphere_outer : Area3D = $AtmosphereOuter

var prev_intersecting_areas : Array[Area3D] = []

func _ready():
	var atmosphere_radius : float = \
		(1.0 + planet.body.shading.atmosphere_settings.atmosphere_scale) * planet.body_scale()
	# Inner border starts at 30% of atmosphere thickness
	atmosphere_inner.get_child(0).shape.radius = \
		planet.body_scale() + 0.3 * (atmosphere_radius - planet.body_scale())
	# Outer border ends at 130% of atmosphere thickness
	atmosphere_outer.get_child(0).shape.radius = \
		planet.body_scale() + 1.3 * (atmosphere_radius - planet.body_scale())

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	var intersecting_areas : Array[Area3D] = []
	var overlapping_areas_inner = atmosphere_inner.get_overlapping_areas()
	var overlapping_areas_outer = atmosphere_outer.get_overlapping_areas()
	for i in range(overlapping_areas_outer.size()):
		if not overlapping_areas_inner.has(overlapping_areas_outer[i]):
			var other_area : Area3D = overlapping_areas_outer[i]
			var shake_effect = _get_shake_effect(other_area)
			if shake_effect != null:
				shake_effect.is_shaking = true
			var audio_player = _get_audio_stream_player(other_area)
			if audio_player != null and not audio_player.playing:
				audio_player.playing = true
			intersecting_areas.append(other_area)
	
	for area in prev_intersecting_areas:
		if not intersecting_areas.has(area):
			var shake_effect = _get_shake_effect(area)
			if shake_effect != null:
				shake_effect.is_shaking = false
			if not overlapping_areas_inner.has(area):
				var audio_player = _get_audio_stream_player(area)
				if audio_player != null and audio_player.playing:
					audio_player.playing = false
		else:
			var inner_radius = atmosphere_inner.get_child(0).shape.radius
			var outer_radius = atmosphere_outer.get_child(0).shape.radius
			var inner_dist = abs(
				area.global_position.distance_to(self.global_position)
				- inner_radius
			)
			var outer_dist = abs(
				area.global_position.distance_to(self.global_position)
				- outer_radius
			)
			var atmosphere_thickness = outer_radius - inner_radius
			
			var shake_effect = _get_shake_effect(area)
			if shake_effect != null:
				shake_effect.speed = \
					shake_strength * (1.0 - abs(outer_dist - inner_dist) / atmosphere_thickness)
			
			var audio_player = _get_audio_stream_player(area)
			if audio_player != null:
				audio_player.volume_db = \
					-80.0 + 80.0 * min(1.0, exp(-(abs(outer_dist - inner_dist) / atmosphere_thickness)))
				audio_player.max_db = \
					-24.0 + 24.0 * min(1.0, exp(-(abs(outer_dist - inner_dist) / atmosphere_thickness)))
	
	prev_intersecting_areas = intersecting_areas

func _get_shake_effect(node : Node) -> ShakeEffect:
	for child in node.get_parent().get_children():
		if child is ShakeEffect:
			var shake_effect = child as ShakeEffect
			return shake_effect
	return null

func _get_audio_stream_player(node : Node) -> AudioStreamPlayer3D:
	for child in node.get_parent().get_children():
		if child is AudioStreamPlayer3D and child.is_in_group("AtmosphereEffect"):
			var audio_player = child as AudioStreamPlayer3D
			return audio_player
	return null
