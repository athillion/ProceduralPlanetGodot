@tool
extends Node

class_name OceanEffect

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
	
	var centre : Vector3 = generator.global_position
	var radius : float = generator.get_ocean_radius()
	material.set_shader_parameter("OceanCentre", centre)
	material.set_shader_parameter("OceanRadius", radius)
	
	var tex = source_viewport.get_texture()
	material.set_shader_parameter("MainTex", tex)

	material.set_shader_parameter("PlanetScale", generator.body_scale())
	if light != null:
		material.set_shader_parameter("DirToSun", (light.global_position - centre).normalized())
	else:
		material.set_shader_parameter("DirToSun", Vector3.UP)
		print_debug("No DirectionalLight3D found")
	generator.body.shading.set_ocean_properties(material)
	
func get_material():
	return material
