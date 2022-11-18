@tool
extends Node

class_name AtmosphereEffect

var light : Node

var material : ShaderMaterial

func _init(_light : Node):
	self.light = _light

func update_settings(
	source_viewport : Viewport,
	generator : CelestialBodyGenerator,
	shader : Shader
):
	if material == null or material.shader != shader:
		material = ShaderMaterial.new()
		material.shader = shader
		material.render_priority = -1
	
	generator.body.shading.atmosphere_settings.set_properties(
		material, generator.body_scale())
	
	var centre : Vector3 = generator.global_position
	var radius : float = generator.get_ocean_radius()
	material.set_shader_parameter("PlanetCentre", centre)
	material.set_shader_parameter("OceanRadius", radius)
	
	var tex = source_viewport.get_texture()
	material.set_shader_parameter("MainTex", tex)
	
	material.set_shader_parameter("ScreenWidth", source_viewport.size.x)
	material.set_shader_parameter("ScreenHeight", source_viewport.size.y)
	
	if light != null:
		material.set_shader_parameter("DirToSun",
			(light.global_position - centre).normalized())
	else:
		material.set_shader_parameter("DirToSun", Vector3.UP)
		print_debug("No DirectionalLight3D found")
	
func get_material():
	return material
