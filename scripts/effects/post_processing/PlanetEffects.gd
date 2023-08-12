@tool
extends Node

class_name PlanetEffects

@export var display_oceans : bool = true
@export var display_atmosphere : bool = false

@export var ocean_shader : Shader
@export var atmosphere_shader : Shader

# Post processing effects are ShaderMaterials slapped onto billboard quads and 
# pressed against your face
@export_node_path("MeshInstance3D") var ocean_target_mesh_path
@export_node_path("MeshInstance3D") var atmosphere_target_mesh_path

@onready var ocean_target_mesh : MeshInstance3D = get_node(ocean_target_mesh_path)
@onready var atmosphere_target_mesh : MeshInstance3D = get_node(atmosphere_target_mesh_path)

# A node which has a light source as a child
@export_node_path("Node3D") var light_path
# A node that is of type CelestialBodyGenerator
@export_node_path("Node3D") var generator_path

# We use viewports as a workaround for Godot's lack of multi pass post processing
@export_node_path("Viewport") var source_viewport_path
@export_node_path("Viewport") var ocean_viewport_path
@export_node_path("Viewport") var atmosphere_viewport_path

@onready var source_viewport : SubViewport = get_node(source_viewport_path)
@onready var ocean_viewport : SubViewport = get_node(ocean_viewport_path)
@onready var atmosphere_viewport : SubViewport = get_node(atmosphere_viewport_path)

# Holds our post processing effect scripts
var effect_holder : PlanetEffectHolder

# TODO: Need a proper multi-pass post processing pipeline for this actaully...

func _process(_delta):

	# Source viewport is our view without any effects
	var next_viewport := source_viewport
	
	# Instantiate our effect holder
	if effect_holder == null:
		effect_holder = PlanetEffectHolder.new(
			get_node(generator_path),
			get_node(light_path)
	)
	
	# Ocean post processing effect
	if display_oceans:
		if effect_holder.ocean_effect != null:
			effect_holder.ocean_effect.update_settings(
				next_viewport, effect_holder.generator, ocean_shader)
			ocean_target_mesh.material_override = effect_holder.ocean_effect.get_material()
			next_viewport = ocean_viewport
	
	# Atmosphere post processing effect
	if display_atmosphere:
		if effect_holder.atmosphere_effect != null:
			effect_holder.atmosphere_effect.update_settings(
				next_viewport, effect_holder.generator, atmosphere_shader)
			atmosphere_target_mesh.material_override = effect_holder.atmosphere_effect.get_material()
			next_viewport = atmosphere_viewport
