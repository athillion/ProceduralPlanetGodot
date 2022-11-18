@tool
extends CelestialBodyShading

class_name EarthShading

@export var customized_colors : Resource :
	set(val):
		customized_colors = val
		customized_colors.resource_name = "Customized Colors"
		emit_signal("changed")
		customized_colors.changed.connect(on_data_changed)

@export var randomized_colors : Resource :
	set(val):
		randomized_colors = val
		randomized_colors.resource_name = "Randomized Colors"
		emit_signal("changed")
		randomized_colors.changed.connect(on_data_changed)

func on_data_changed():
	emit_signal("changed")

func set_terrain_properties(material : Material, height_min_max : Vector2, body_scale : float):
	material.set_shader_parameter("HeightMinMax", height_min_max)
	material.set_shader_parameter("OceanLevel", ocean_level)
	material.set_shader_parameter("BodyScale", body_scale)
	
	if randomize_:
		set_random_colors(material)
		apply_colors(material, randomized_colors)
	else:
		apply_colors(material, customized_colors)

func apply_colors(material : Material, colors : EarthColors):
	material.set_shader_parameter("ShoreLow", colors.shore_color_low)
	material.set_shader_parameter("ShoreHigh", colors.shore_color_high)
	
	material.set_shader_parameter("FlatLowA", colors.flat_color_low_A)
	material.set_shader_parameter("FlatHighA", colors.flat_color_high_A)
	
	material.set_shader_parameter("FlatLowB", colors.flat_color_low_B)
	material.set_shader_parameter("FlatHighB", colors.flat_color_high_B)
	
	material.set_shader_parameter("SteepLow", colors.steep_low)
	material.set_shader_parameter("SteepHigh", colors.steep_high)

func set_random_colors(_material : Material):
	rng.randomize()
	randomized_colors.flat_color_low_A = ColorUtils.random_color(rng, 0.45, 0.6, 0.7, 0.8)
	randomized_colors.flat_color_high_A = ColorUtils.tweak_hsv(
		randomized_colors.flat_color_low_A,
		MathUtils.rand_signed(rng) * 0.2,
		MathUtils.rand_signed(rng) * 0.15,
		rng.randf_range(-0.25, 0.2)
	)

	randomized_colors.flat_color_low_B = ColorUtils.random_color(rng, 0.45, 0.6, 0.7, 0.8)
	randomized_colors.flat_color_high_B = ColorUtils.tweak_hsv(
		randomized_colors.flat_color_low_B,
		MathUtils.rand_signed(rng) * 0.2,
		MathUtils.rand_signed(rng) * 0.15,
		rng.randf_range(-0.25, 0.2)
	)

	randomized_colors.shore_color_low = ColorUtils.random_color(rng, 0.2, 0.3, 0.9, 1.0)
	randomized_colors.shore_color_high = ColorUtils.tweak_hsv(
		randomized_colors.shore_color_low,
		MathUtils.rand_signed(rng) * 0.2,
		MathUtils.rand_signed(rng) * 0.2,
		rng.randf_range(-0.3, 0.2)
	)

	randomized_colors.steep_low = ColorUtils.random_color(rng, 0.3, 0.7, 0.4, 0.6)
	randomized_colors.steep_high = ColorUtils.tweak_hsv(
		randomized_colors.steep_low,
		MathUtils.rand_signed(rng) * 0.2,
		MathUtils.rand_signed(rng) * 0.2,
		rng.randf_range(-0.35, 0.2)
	)
