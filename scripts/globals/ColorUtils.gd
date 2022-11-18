extends Node

func random_color(rng, sat_min : float, sat_max : float, val_min : float, val_max : float) -> Color:
	return Color.from_hsv(
		rng.randf(), rng.randf_range(sat_min, sat_max), rng.randf_range(val_min, val_max))

func tweak_hsv(color : Color, deltaH : float, deltaS : float, deltaV : float) -> Color:
	return Color.from_hsv(fmod(color.h + deltaH, 1.0), color.s + deltaS, color.v + deltaV)
