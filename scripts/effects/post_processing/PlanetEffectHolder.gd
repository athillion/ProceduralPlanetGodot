@tool
extends Node

class_name PlanetEffectHolder

var ocean_effect : Node
var atmosphere_effect : Node

var generator : CelestialBodyGenerator

func _init(
	_generator : CelestialBodyGenerator,
	light : Node
):
	generator = _generator
	if (
		generator.body.shading.has_ocean
		and generator.body.shading.ocean_settings != null
	):
		ocean_effect = OceanEffect.new(light)
	if (
		generator.body.shading.has_atmosphere
		and generator.body.shading.atmosphere_settings != null
	):
		atmosphere_effect = AtmosphereEffect.new(light)

func dist_from_surface(view_pos : Vector3) -> float:
		return max(0.0, (generator.global_position - view_pos).length() - generator.body_scale())
		
