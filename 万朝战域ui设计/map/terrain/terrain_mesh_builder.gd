class_name TerrainMeshBuilder
extends RefCounted

const SURFACE_NEUTRAL := 0
const SURFACE_FOREST := 1
const SURFACE_MOUNTAIN := 2
const SURFACE_WETLAND := 3
const SURFACE_CENTRAL := 4
const QUAD_CORNERS: Array[Vector2i] = [
	Vector2i.ZERO,
	Vector2i.DOWN,
	Vector2i.RIGHT,
	Vector2i.ONE,
]
const ROAD_UV_SCALE := 0.12
const BRIDGE_UV_SCALE := 0.05


static func build_ground_mesh(data: DemoMapData, bounds: Rect2i) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var vertex_width := bounds.size.x + 1
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	vertices.resize(vertex_width * (bounds.size.y + 1))
	normals.resize(vertices.size())
	uvs.resize(vertices.size())
	for local_y in range(bounds.size.y + 1):
		for local_x in range(bounds.size.x + 1):
			var index := local_y * vertex_width + local_x
			var vertex_grid := bounds.position + Vector2i(local_x, local_y)
			vertices[index] = Vector3(
				float(local_x) * data.cell_size,
				data.get_height_sample(vertex_grid),
				float(local_y) * data.cell_size
			)
			normals[index] = data.get_surface_normal_at_vertex(vertex_grid)
			uvs[index] = Vector2(vertex_grid) * data.cell_size

	var surface_indices := {
		SURFACE_NEUTRAL: PackedInt32Array(),
		SURFACE_FOREST: PackedInt32Array(),
		SURFACE_MOUNTAIN: PackedInt32Array(),
		SURFACE_WETLAND: PackedInt32Array(),
		SURFACE_CENTRAL: PackedInt32Array(),
	}
	for local_y in range(bounds.size.y):
		for local_x in range(bounds.size.x):
			var grid_position := bounds.position + Vector2i(local_x, local_y)
			if not data.is_valid_grid(grid_position):
				continue
			var surface_key := _get_surface_key(
				data.get_terrain_type_at(grid_position),
				data.get_zone_type_at(grid_position)
			)
			var indices := surface_indices[surface_key] as PackedInt32Array
			_append_quad_indices(indices, local_y * vertex_width + local_x, vertex_width)
			surface_indices[surface_key] = indices

	for surface_key in surface_indices:
		var indices := surface_indices[surface_key] as PackedInt32Array
		if indices.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_name(mesh.get_surface_count() - 1, str(surface_key))
	return mesh


static func build_water_mesh(data: DemoMapData, bounds: Rect2i) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for local_y in range(bounds.size.y):
		for local_x in range(bounds.size.x):
			var grid_position := bounds.position + Vector2i(local_x, local_y)
			if data.get_terrain_type_at(grid_position) != MapTileTypes.Terrain.RIVER:
				continue
			var base_index := vertices.size()
			for corner in QUAD_CORNERS:
				var vertex_grid: Vector2i = grid_position + corner
				vertices.append(Vector3(
					(float(local_x) + float(corner.x)) * data.cell_size,
					data.get_water_height_sample(vertex_grid) + 0.025,
					(float(local_y) + float(corner.y)) * data.cell_size
				))
				normals.append(Vector3.UP)
			indices.append_array(PackedInt32Array([
				base_index,
				base_index + 1,
				base_index + 2,
				base_index + 2,
				base_index + 1,
				base_index + 3,
			]))
	return _create_single_surface_mesh(vertices, normals, indices)


static func build_road_mesh(
	data: DemoMapData,
	bounds: Rect2i,
	bridges: bool,
	road_type_filter: int = MapTileTypes.RoadType.NONE,
	crossing_type_filter: String = ""
) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for local_y in range(bounds.size.y):
		for local_x in range(bounds.size.x):
			var grid_position := bounds.position + Vector2i(local_x, local_y)
			if not data.has_road_at(grid_position):
				continue
			if (
				road_type_filter != MapTileTypes.RoadType.NONE
				and data.get_road_type_at(grid_position) != road_type_filter
			):
				continue
			var is_bridge := (
				data.get_terrain_type_at(grid_position) == MapTileTypes.Terrain.RIVER
			)
			if is_bridge != bridges:
				continue
			if (
				bridges
				and not crossing_type_filter.is_empty()
				and data.get_crossing_type_at(grid_position) != crossing_type_filter
			):
				continue
			var base_index := vertices.size()
			var bridge_direction := Vector2.RIGHT
			if bridges:
				var crossing := data.get_crossing_at_grid(grid_position)
				bridge_direction = (
					crossing.get("road_direction", Vector2.RIGHT) as Vector2
				).normalized()
				if bridge_direction.length_squared() <= 0.0:
					bridge_direction = Vector2.RIGHT
			var bridge_right := Vector2(-bridge_direction.y, bridge_direction.x)
			for corner in QUAD_CORNERS:
				var vertex_grid: Vector2i = grid_position + corner
				var height := (
					data.get_water_height_sample(vertex_grid) + (
						0.04 if crossing_type_filter == "ford" else 0.14
					)
					if bridges
					else data.get_height_sample(vertex_grid) + 0.055
				)
				vertices.append(Vector3(
					(float(local_x) + float(corner.x)) * data.cell_size,
					height,
					(float(local_y) + float(corner.y)) * data.cell_size
				))
				normals.append(Vector3.UP if bridges else data.get_surface_normal_at_vertex(vertex_grid))
				var world_xz := Vector2(vertex_grid) * data.cell_size
				uvs.append(
					Vector2(
						world_xz.dot(bridge_right),
						world_xz.dot(bridge_direction)
					) * BRIDGE_UV_SCALE
					if bridges
					else world_xz * ROAD_UV_SCALE
				)
			indices.append_array(PackedInt32Array([
				base_index,
				base_index + 1,
				base_index + 2,
				base_index + 2,
				base_index + 1,
				base_index + 3,
			]))
	return _create_single_surface_mesh(vertices, normals, indices, uvs)


static func build_collision_faces(data: DemoMapData, bounds: Rect2i) -> PackedVector3Array:
	var faces := PackedVector3Array()
	for local_y in range(bounds.size.y):
		for local_x in range(bounds.size.x):
			var top_left := _get_local_vertex(data, bounds, local_x, local_y)
			var bottom_left := _get_local_vertex(data, bounds, local_x, local_y + 1)
			var top_right := _get_local_vertex(data, bounds, local_x + 1, local_y)
			var bottom_right := _get_local_vertex(data, bounds, local_x + 1, local_y + 1)
			faces.append_array(PackedVector3Array([
				top_left,
				bottom_left,
				top_right,
				top_right,
				bottom_left,
				bottom_right,
			]))
	return faces


static func build_tree_multimesh(data: DemoMapData, bounds: Rect2i) -> MultiMesh:
	var transforms: Array[Transform3D] = []
	for local_y in range(bounds.size.y):
		for local_x in range(bounds.size.x):
			var grid_position := bounds.position + Vector2i(local_x, local_y)
			if (
				data.get_zone_type_at(grid_position) != MapTileTypes.Zone.FOREST
				or data.get_terrain_type_at(grid_position) != MapTileTypes.Terrain.PLAIN
				or data.has_road_at(grid_position)
				or data.get_city_at_grid(grid_position) != null
				or data.get_resource_at_grid(grid_position) != null
			):
				continue
			var random_value := _coordinate_random(grid_position, data.seed)
			if random_value > data.get_forest_density_at(grid_position) * 0.58:
				continue
			var yaw := _coordinate_random(grid_position + Vector2i(71, -43), data.seed) * TAU
			var scale_value := lerpf(
				0.78,
				1.22,
				_coordinate_random(grid_position + Vector2i(-19, 97), data.seed)
			)
			var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_value)
			var origin := Vector3(
				(float(local_x) + 0.5) * data.cell_size,
				data.get_tile_height_at(grid_position) + 0.9 * scale_value,
				(float(local_y) + 0.5) * data.cell_size
			)
			transforms.append(Transform3D(basis, origin))
	if transforms.is_empty():
		return null
	var tree_mesh := CylinderMesh.new()
	tree_mesh.top_radius = 0.08
	tree_mesh.bottom_radius = 0.58
	tree_mesh.height = 1.8
	tree_mesh.radial_segments = 5
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("315b36")
	material.roughness = 1.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tree_mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = tree_mesh
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	return multimesh


static func _get_surface_key(terrain_type: int, zone_type: int) -> int:
	if terrain_type == MapTileTypes.Terrain.MOUNTAIN:
		return SURFACE_MOUNTAIN
	if terrain_type == MapTileTypes.Terrain.RIVER:
		return SURFACE_WETLAND
	match zone_type:
		MapTileTypes.Zone.FOREST:
			return SURFACE_FOREST
		MapTileTypes.Zone.MOUNTAIN:
			return SURFACE_MOUNTAIN
		MapTileTypes.Zone.WETLAND:
			return SURFACE_WETLAND
		MapTileTypes.Zone.CENTRAL:
			return SURFACE_CENTRAL
		_:
			return SURFACE_NEUTRAL


static func _append_quad_indices(indices: PackedInt32Array, top_left: int, width: int) -> void:
	indices.append_array(PackedInt32Array([
		top_left,
		top_left + width,
		top_left + 1,
		top_left + 1,
		top_left + width,
		top_left + width + 1,
	]))


static func _get_local_vertex(
	data: DemoMapData,
	bounds: Rect2i,
	local_x: int,
	local_y: int
) -> Vector3:
	return Vector3(
		float(local_x) * data.cell_size,
		data.get_height_sample(bounds.position + Vector2i(local_x, local_y)),
		float(local_y) * data.cell_size
	)


static func _create_single_surface_mesh(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	indices: PackedInt32Array,
	uvs: PackedVector2Array = PackedVector2Array()
) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if vertices.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	if uvs.size() == vertices.size():
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _coordinate_random(grid_position: Vector2i, generation_seed: int) -> float:
	var value := (
		grid_position.x * 73856093
		^ grid_position.y * 19349663
		^ generation_seed * 83492791
	)
	return float(absi(value) % 10000) / 9999.0
