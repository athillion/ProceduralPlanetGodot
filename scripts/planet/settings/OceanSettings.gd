@tool
extends Resource

class_name OceanSettings

@export var depth_multiplier : float = 10.0 :
	set(val):
		depth_multiplier = val
		emit_signal("changed")

@export var alpha_multiplier : float = 70.0 :
	set(val):
		alpha_multiplier = val
		emit_signal("changed")

@export var colA : Color :
	set(val):
		colA = val
		emit_signal("changed")

@export var colB : Color :
	set(val):
		colB = val
		emit_signal("changed")

@export var specular_col : Color = Color(1.0, 1.0, 1.0) :
	set(val):
		specular_col = val
		emit_signal("changed")

@export var wave_normal_A : Texture2D :
	set(val):
		wave_normal_A = val
		emit_signal("changed")

@export var wave_normal_B : Texture2D :
	set(val):
		wave_normal_B = val
		emit_signal("changed")

@export_range(0.0, 1.0) var wave_strength : float = 0.15 :
	set(val):
		wave_strength = val
		emit_signal("changed")

@export var wave_scale : float = 15.0 :
	set(val):
		wave_scale = val
		emit_signal("changed")

@export var wave_speed : float = 0.5 :
	set(val):
		wave_speed = val
		emit_signal("changed")

@export var shore_wave_height : float = 0.1 :
	set(val):
		shore_wave_height = val
		emit_signal("changed")

@export_range(0.0, 1.0) var smoothness : float = 0.92 :
	set(val):
		smoothness = val
		emit_signal("changed")

@export var specular_intensity : float = 0.5 :
	set(val):
		specular_intensity = val
		emit_signal("changed")

@export var foam_noise_texture : Texture2D :
	set(val):
		foam_noise_texture = val
		emit_signal("changed")

@export var foam_color : Color :
	set(val):
		foam_color = val
		emit_signal("changed")

@export var foam_noise_scale : float = 1.0 :
	set(val):
		foam_noise_scale = val
		emit_signal("changed")

@export var foam_falloff_distance : float = 0.5 :
	set(val):
		foam_falloff_distance = val
		emit_signal("changed")

@export var foam_leading_edge_falloff : float = 1.0 :
	set(val):
		foam_leading_edge_falloff = val
		emit_signal("changed")

@export var foam_edge_falloff_bias : float = 0.5 :
	set(val):
		foam_edge_falloff_bias = val
		emit_signal("changed")

@export_range(0.0, 2.0) var refraction_scale : float = 1.0 :
	set(val):
		refraction_scale = val
		emit_signal("changed")

var rng = RandomNumberGenerator.new()

func on_data_changed():
	emit_signal("changed")

func set_properties(material : Material, seed_ : int, randomize_ : bool):
	material.set_shader_parameter("DepthMultiplier", depth_multiplier)
	material.set_shader_parameter("AlphaMultiplier", alpha_multiplier)
	
	material.set_shader_parameter("WaveNormalA", wave_normal_A)
	material.set_shader_parameter("WaveNormalB", wave_normal_B)
	material.set_shader_parameter("WaveStrength", wave_strength)
	material.set_shader_parameter("WaveNormalScale", wave_scale)
	material.set_shader_parameter("WaveSpeed", wave_speed)
	material.set_shader_parameter("ShoreWaveHeight", shore_wave_height)
	material.set_shader_parameter("Smoothness", smoothness)
	material.set_shader_parameter("SpecularIntensity", specular_intensity)
	material.set_shader_parameter("FoamNoiseTexture", foam_noise_texture)
	material.set_shader_parameter("FoamColor", foam_color)
	material.set_shader_parameter("FoamNoiseScale", foam_noise_scale)
	material.set_shader_parameter("FoamFalloffDistance", foam_falloff_distance)
	material.set_shader_parameter("FoamLeadingEdgeFalloff", foam_leading_edge_falloff)
	material.set_shader_parameter("FoamEdgeFalloffBias", foam_edge_falloff_bias)
	material.set_shader_parameter("RefractionScale", refraction_scale)
	
	if randomize_:
		rng.set_seed(seed_)
		rng.randomize()
		var random_ColA := Color.from_hsv(
			rng.randf(), rng.randf_range(0.6, 0.8), rng.randf_range(0.65, 1.0))
		var random_ColB : Color = ColorUtils.tweak_hsv(
			random_ColA,
			MathUtils.rand_signed(rng) * 0.2,
			MathUtils.rand_signed(rng) * 0.2,
			rng.randf_range(-0.5, 0.4)
		)
		
		material.set_shader_parameter("ColA", random_ColA)
		material.set_shader_parameter("ColB", random_ColB)
		material.set_shader_parameter("SpecularCol", Color(1.0, 1.0, 1.0))
	else:
		material.set_shader_parameter("ColA", colA)
		material.set_shader_parameter("ColB", colB)
		material.set_shader_parameter("SpecularCol", specular_col)
