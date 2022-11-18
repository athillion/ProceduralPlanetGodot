extends Node

func from_to_rotation(from, to) -> Basis:
	var axis : Vector3 = from.cross(to).normalized()
	var angle : float = from.angle_to(to)
	if axis.length() == 0:
		axis = Vector3(1, 0, 0)
		angle = 0
	var basis = Basis(axis, angle)
	return basis

func delta_angle(angleA : float, angleB : float):
	var anti_clockwise_distance : float = abs(180 - angleA) + abs(-180 - angleB)
	var clockwise_distance : float = angleB - angleA
	
	return min(clockwise_distance, anti_clockwise_distance)

func move_towards_angle(angleA : float, angleB : float, speed : float):
	var anti_clockwise_distance : float = abs(180 - angleA) + abs(-180 - angleB)
	var clockwise_distance : float = angleB - angleA
	
	if clockwise_distance < anti_clockwise_distance:
		angleA += speed
		if angleA > 360:
			angleA -= 360
	else:
		angleA -= speed
		if angleA < 0:
			angleA += 360
	
	return angleA

func direction_to_planet(direction : Vector3, origin : Vector3, pivot : Vector3) -> Vector3:
	# direction.x is considered lateral movement
	# direction.y is considered longitudinal movement
	# direction.z is not used (maybe altitude?)
	
	var normal := origin - pivot
	var b := sqrt(direction.length_squared() + normal.length_squared())
	var angle := asin(direction.length_squared() * sin(PI / 2.0) / b)
	
	var projected_origin := Plane(Vector3.UP, 0.0).project(origin)
	var perpendicular_axis := Vector3.UP.cross(projected_origin.normalized())
	
	# Planet up is always Y
	var new_normal := normal.rotated(Vector3.UP, direction.x * angle)
	new_normal = new_normal.rotated(perpendicular_axis, direction.y * angle)
	
	return new_normal.normalized()

func recalculate_normals(vertices : PackedVector3Array, triangles : PackedInt32Array) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	# Recalculate Normals
	for a in range(0, triangles.size(), 3):
		var b : int = a + 1
		var c : int = a + 2
		var ab : Vector3 = vertices[triangles[b]] - vertices[triangles[a]]
		var bc : Vector3 = vertices[triangles[c]] - vertices[triangles[b]]
		var ca : Vector3 = vertices[triangles[a]] - vertices[triangles[c]]
		var cross_ab_bc : Vector3 = ab.cross(bc) * -1.0
		var cross_bc_ca : Vector3 = bc.cross(ca) * -1.0
		var cross_ca_ab : Vector3 = ca.cross(ab) * -1.0
		normals[triangles[a]] += cross_ab_bc + cross_bc_ca + cross_ca_ab
		normals[triangles[b]] += cross_ab_bc + cross_bc_ca + cross_ca_ab
		normals[triangles[c]] += cross_ab_bc + cross_bc_ca + cross_ca_ab
	
	# Make sure normals are within 0 and 1
	for i in range(normals.size()):
		normals[i] = normals[i].normalized()
	
	return normals

# Smooth maximum of two values, controlled by smoothing factor k
# When k = 0, this behaves identically to max(a, b)
func smooth_max(a : float, b : float, k : float) -> float:
	k = min(0.0, -k)
	var h : float = max(0.0, min(1.0, (b - a + k) / (2.0 * k)))
	return a * h + b * (1.0 - h) - k * h * (1.0 - h)

func blend(start_height : float, blend_dst : float, height : float) -> float:
	return smoothstep(start_height - blend_dst / 2.0, start_height + blend_dst / 2.0, height)

func rand_signed(rng) -> float:
	var val : float = rng.randf()
	if val < 0:
		return -1.0
	else:
		return 1.0

func rand_on_unit_sphere(rng) -> Vector3:
	var x : float = rng.randf_range(-1.0, 1.0)
	var y : float = rng.randf_range(-1.0, 1.0)
	var z : float = rng.randf_range(-1.0, 1.0)
	var dir := Vector3(x, y, z).normalized()
	if dir.length() == 0.0:
		dir = Vector3.LEFT
	return dir
