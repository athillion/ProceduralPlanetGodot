@tool
extends Resource

class_name PlanetSphereMesh

# TODO: Add QuadTree here!

var vertices : PackedVector3Array
var triangles : PackedInt32Array
var resolution : int

var _num_divisions : int
var _num_verts_per_face : int

# Indices of the vertex pairs that make up each of the initial 12 edges
const vertex_pairs : Array = [0, 1, 0, 2, 0, 3, 0, 4, 1, 2, 2, 3, 3, 4, 4, 1, 5, 1, 5, 2, 5, 3, 5, 4]
# Indices of the edge triplets that make up the initial 8 GLTFAccessor
const edge_triplets : Array = [0, 1, 4, 1, 2, 5, 2, 3, 6, 3, 0, 7, 8, 9, 4, 9, 10, 5, 10, 11, 6, 11, 8, 7]
# The six initial vertices
const base_vertices : Array = [Vector3.UP, Vector3.LEFT, Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.DOWN]

func _init(_resolution : int):
	resolution = _resolution
	_num_divisions = max(0, resolution)
	_num_verts_per_face = ((_num_divisions + 3) * (_num_divisions + 3) - (_num_divisions + 3)) / 2
	
	vertices = PackedVector3Array()
	triangles = PackedInt32Array()
	
	vertices.append_array(PackedVector3Array(base_vertices))
	
	# Create 12 edges, with n vertices added along them (n = numDivisions)
	var edges := []
	edges.resize(12)
	for i in range(0, vertex_pairs.size(), 2):
		var start_vertex : Vector3 = vertices[vertex_pairs[i]]
		var end_vertex : Vector3 = vertices[vertex_pairs[i + 1]]
		
		var edge_vertex_indices := PackedInt32Array()
		edge_vertex_indices.resize(_num_divisions + 2)
		edge_vertex_indices[0] = vertex_pairs[i]
		
		# Add vertices along edge
		for division_index in range(_num_divisions):
			var t : float = (division_index + 1.0) / (_num_divisions + 1.0)
			edge_vertex_indices[division_index + 1] = vertices.size()
			vertices.append(start_vertex.slerp(end_vertex, t))
		edge_vertex_indices[_num_divisions + 1] = vertex_pairs[i + 1]
		var edge_index : int = i / 2
		edges[edge_index] = Edge.new(edge_vertex_indices)

	# Create faces
	for i in range(0, edge_triplets.size(), 3):
		var face_index : int = i / 3
		var reverse : bool = face_index >= 4
		create_face(
			edges[edge_triplets[i]],
			edges[edge_triplets[i + 1]],
			edges[edge_triplets[i + 2]],
			reverse
		)

func create_face(sideA : Edge, sideB : Edge, bottom : Edge, reverse : bool):
	var num_points_in_edge = sideA.vertex_indices.size()
	var vertex_map := PackedInt32Array()
	#vertex_map.resize(_num_verts_per_face)
	vertex_map.append(sideA.vertex_indices[0])  # top of triangle
	
	for i in range(1, num_points_in_edge - 1):
		# Side A vertex
		vertex_map.append(sideA.vertex_indices[i])
		
		# Add vertices between sideA and sideB
		var sideA_vertex : Vector3 = vertices[sideA.vertex_indices[i]]
		var sideB_vertex : Vector3 = vertices[sideB.vertex_indices[i]]
		var num_inner_points : int = i - 1
		for j in range(num_inner_points):
			var t : float = (j + 1.0) / (num_inner_points + 1.0)
			vertex_map.append(vertices.size())
			vertices.append(sideA_vertex.slerp(sideB_vertex, t))
		
		# Side B vertex
		vertex_map.append(sideB.vertex_indices[i])
	
	# Add bottom edge vertices
	for i in range(num_points_in_edge):
		vertex_map.append(bottom.vertex_indices[i])
	
	# Triangulate
	var num_rows : int = _num_divisions + 1
	for row in range(num_rows):
		# vertices down left edge follow quadratic sequence: 0, 1, 3, 6, 10, 15...
		# the nth term can be calculated with: (n^2 - n)/2
		var top_vertex : int = ((row + 1) * (row + 1) - row - 1) / 2
		var bottom_vertex : int = ((row + 2) * (row + 2) - row - 2) / 2
		
		var num_triangles_in_row : int = 1 + 2 * row
		for column in range(num_triangles_in_row):
			var v0 : int
			var v1 : int
			var v2 : int
			
			if column % 2 == 0:
				v0 = top_vertex
				v1 = bottom_vertex + 1
				v2 = bottom_vertex
				top_vertex += 1
				bottom_vertex += 1
			else:
				v0 = top_vertex
				v1 = bottom_vertex
				v2 = top_vertex - 1
			
			triangles.append(vertex_map[v0])
			if reverse:
				triangles.append(vertex_map[v2])
				triangles.append(vertex_map[v1])
			else:
				triangles.append(vertex_map[v1])
				triangles.append(vertex_map[v2])

class Edge:
	var vertex_indices : PackedInt32Array
	
	func _init(_vertex_indices : PackedInt32Array):
		self.vertex_indices = _vertex_indices
