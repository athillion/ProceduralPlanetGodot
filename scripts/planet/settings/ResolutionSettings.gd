@tool
extends Resource

class_name ResolutionSettings

@export var lod_parameters : Array[LODParameter] = []:
	set(val):
		lod_parameters = val
		emit_changed()
		for n in lod_parameters:
			n.changed.connect(on_data_changed)

@export var collider : int = 100 :
	set(val):
		collider = val
		emit_changed()

const max_allowed_resolution : int = 500

func _init():
	if lod_parameters.size() == 0:
		lod_parameters.append(LODParameter.new())
		lod_parameters.append(LODParameter.new())
		lod_parameters.append(LODParameter.new())
		lod_parameters[0].resolution = 300
		lod_parameters[0].min_distance = 300
		lod_parameters[1].resolution = 100
		lod_parameters[1].min_distance = 1000
		lod_parameters[2].resolution = 50
		lod_parameters[2].min_distance = INF

func on_data_changed():
	emit_changed()

func num_LOD_levels():
	return lod_parameters.size()

func get_lod_resolution(lod_level : int) -> int:
	if lod_level < lod_parameters.size():
		return lod_parameters[lod_level].resolution
	return lod_parameters[-1].resolution

func clamp_resolutions():
	for lod in lod_parameters:
		lod.resolution = min(max_allowed_resolution, lod.resolution)
	collider = min(max_allowed_resolution, collider)
