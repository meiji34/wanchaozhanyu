class_name DemoMapData
extends RefCounted

var map_size: Vector2i
var chunk_size: Vector2i
var cell_size: float
@warning_ignore("shadowed_global_identifier")
var seed: int
var fog_data: FogData
var cities: Array[MapCityData] = []
var resource_points: Array[MapResourcePointData] = []
var passes: Array[Dictionary] = []
var crossings: Array[Dictionary] = []
var road_connections: Array[Dictionary] = []
var height_samples := PackedFloat32Array()
var water_height_samples := PackedFloat32Array()
var terrain_types := PackedByteArray()
var zone_types := PackedByteArray()
var road_types := PackedByteArray()
var tile_heights := PackedFloat32Array()
var tile_slopes := PackedFloat32Array()
var forest_densities := PackedFloat32Array()
var river_masks := PackedFloat32Array()
var tile_water_heights := PackedFloat32Array()
var buildable_flags := PackedByteArray()
## 阵营归属数组，存储值为 faction_id + 1（0=NONE,1=FOREST,2=WETLAND,3=MOUNTAIN）
var faction_types := PackedByteArray()
var min_terrain_height := 0.0
var max_terrain_height := 0.0

var _cities_by_grid: Dictionary = {}
var _cities_by_id: Dictionary = {}
var _resources_by_grid: Dictionary = {}
var _resources_by_id: Dictionary = {}
var _crossings_by_grid: Dictionary = {}


func _init(
	p_map_size: Vector2i = Vector2i(400, 400),
	p_chunk_size: Vector2i = Vector2i(10, 10),
	p_cell_size: float = 2.0,
	p_seed: int = 0
) -> void:
	map_size = p_map_size
	chunk_size = p_chunk_size
	cell_size = p_cell_size
	seed = p_seed
	var sample_count := (map_size.x + 1) * (map_size.y + 1)
	height_samples.resize(sample_count)
	water_height_samples.resize(sample_count)
	var tile_count := map_size.x * map_size.y
	terrain_types.resize(tile_count)
	zone_types.resize(tile_count)
	road_types.resize(tile_count)
	tile_heights.resize(tile_count)
	tile_slopes.resize(tile_count)
	forest_densities.resize(tile_count)
	river_masks.resize(tile_count)
	tile_water_heights.resize(tile_count)
	buildable_flags.resize(tile_count)
	buildable_flags.fill(1)
	faction_types.resize(tile_count)
	# faction_types 默认全 0，对应 FactionId.NONE(-1) → 存储值 = -1 + 1 = 0


func get_min_grid() -> Vector2i:
	return Vector2i(
		-floori(float(map_size.x) / 2.0),
		-floori(float(map_size.y) / 2.0)
	)


func get_max_grid() -> Vector2i:
	var min_grid := get_min_grid()
	return min_grid + map_size - Vector2i.ONE


func get_min_vertex_grid() -> Vector2i:
	return get_min_grid()


func get_max_vertex_grid() -> Vector2i:
	return get_max_grid() + Vector2i.ONE


func is_valid_grid(grid_position: Vector2i) -> bool:
	var min_grid := get_min_grid()
	var max_grid := get_max_grid()
	return (
		grid_position.x >= min_grid.x
		and grid_position.x <= max_grid.x
		and grid_position.y >= min_grid.y
		and grid_position.y <= max_grid.y
	)


func grid_to_world(grid_position: Vector2i, height: float = 0.0) -> Vector3:
	return Vector3(
		float(grid_position.x) * cell_size,
		height,
		float(grid_position.y) * cell_size
	)


## 连续格子坐标（允许半格）转世界坐标。
## 供多格建筑的视觉中心计算使用，与 grid_to_world 保持同一套换算规则。
func grid_to_world_continuous(grid_position: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(
		grid_position.x * cell_size,
		height,
		grid_position.y * cell_size
	)


func vertex_grid_to_world(vertex_grid: Vector2i, height: float = 0.0) -> Vector3:
	# Tile 坐标表示格子中心，因此顶点坐标需要向左上偏移半格。
	return Vector3(
		(float(vertex_grid.x) - 0.5) * cell_size,
		height,
		(float(vertex_grid.y) - 0.5) * cell_size
	)


func world_to_grid(world_position: Vector3) -> Vector2i:
	return Vector2i(
		roundi(world_position.x / cell_size),
		roundi(world_position.z / cell_size)
	)


func grid_to_chunk(grid_position: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(grid_position.x) / float(chunk_size.x)),
		floori(float(grid_position.y) / float(chunk_size.y))
	)


func get_chunk_grid_bounds(chunk_coordinate: Vector2i) -> Rect2i:
	var start := Vector2i(
		chunk_coordinate.x * chunk_size.x,
		chunk_coordinate.y * chunk_size.y
	)
	return Rect2i(start, chunk_size)


func set_tile(tile: MapTileData) -> void:
	if tile == null:
		return
	var index := get_tile_index(tile.grid_position)
	if index < 0:
		return
	terrain_types[index] = tile.terrain_type
	zone_types[index] = tile.zone_type
	road_types[index] = tile.road_type
	tile_heights[index] = tile.height
	tile_slopes[index] = tile.slope
	forest_densities[index] = tile.forest_density
	river_masks[index] = tile.river_mask
	tile_water_heights[index] = tile.water_height
	buildable_flags[index] = 1 if tile.can_build_city else 0
	# 存储 faction_id + 1（PackedByteArray 不支持负值，NONE=-1 存为 0）
	faction_types[index] = tile.faction_id + 1


func get_tile(grid_position: Vector2i) -> MapTileData:
	var index := get_tile_index(grid_position)
	if index < 0:
		return null
	var tile := MapTileData.new(
		grid_position,
		int(terrain_types[index]),
		tile_heights[index],
		int(zone_types[index])
	)
	tile.slope = tile_slopes[index]
	tile.forest_density = forest_densities[index]
	tile.river_mask = river_masks[index]
	tile.water_height = tile_water_heights[index]
	tile.set_road_type(int(road_types[index]))
	tile.can_build_city = buildable_flags[index] != 0
	# 读取 faction_id（存储值 - 1）
	tile.faction_id = int(faction_types[index]) - 1
	return tile


func get_tile_count() -> int:
	return map_size.x * map_size.y


func get_compact_tile_storage_bytes() -> int:
	# 只统计全图连续 Tile/高度数组；城市与少量对象层不计入该基线。
	var byte_array_count := (
		terrain_types.size()
		+ zone_types.size()
		+ road_types.size()
		+ buildable_flags.size()
	)
	var float_array_count := (
		height_samples.size()
		+ water_height_samples.size()
		+ tile_heights.size()
		+ tile_slopes.size()
		+ forest_densities.size()
		+ river_masks.size()
		+ tile_water_heights.size()
	)
	return byte_array_count + float_array_count * 4


func get_tile_index(grid_position: Vector2i) -> int:
	var min_grid := get_min_grid()
	var local := grid_position - min_grid
	if local.x < 0 or local.y < 0 or local.x >= map_size.x or local.y >= map_size.y:
		return -1
	return local.y * map_size.x + local.x


func tile_index_to_grid(index: int) -> Vector2i:
	if index < 0 or index >= get_tile_count():
		return Vector2i(2147483647, 2147483647)
	return get_min_grid() + Vector2i(index % map_size.x, floori(float(index) / map_size.x))


func set_tile_base_data(
	grid_position: Vector2i,
	terrain_type: int,
	zone_type: int,
	river_mask: float,
	water_height: float,
	forest_density: float,
	faction_id: int = DemoPlayerContext.FactionId.NONE
) -> void:
	var index := get_tile_index(grid_position)
	if index < 0:
		return
	terrain_types[index] = terrain_type
	zone_types[index] = zone_type
	river_masks[index] = river_mask
	tile_water_heights[index] = water_height
	forest_densities[index] = forest_density
	faction_types[index] = clampi(faction_id + 1, 0, 255)


func get_terrain_type_at(grid_position: Vector2i) -> int:
	var index := get_tile_index(grid_position)
	return int(terrain_types[index]) if index >= 0 else MapTileTypes.Terrain.PLAIN


func set_terrain_type_at(grid_position: Vector2i, terrain_type: int) -> void:
	var index := get_tile_index(grid_position)
	if index >= 0:
		terrain_types[index] = terrain_type


func get_zone_type_at(grid_position: Vector2i) -> int:
	var index := get_tile_index(grid_position)
	return int(zone_types[index]) if index >= 0 else MapTileTypes.Zone.NEUTRAL


func get_road_type_at(grid_position: Vector2i) -> int:
	var index := get_tile_index(grid_position)
	return int(road_types[index]) if index >= 0 else int(MapTileTypes.RoadType.NONE)


func set_road_type_at(grid_position: Vector2i, road_type: int) -> void:
	var index := get_tile_index(grid_position)
	if index >= 0:
		road_types[index] = road_type


func has_road_at(grid_position: Vector2i) -> bool:
	return get_road_type_at(grid_position) != MapTileTypes.RoadType.NONE


func get_tile_height_at(grid_position: Vector2i) -> float:
	var index := get_tile_index(grid_position)
	return tile_heights[index] if index >= 0 else 0.0


func set_tile_height_at(grid_position: Vector2i, value: float) -> void:
	var index := get_tile_index(grid_position)
	if index >= 0:
		tile_heights[index] = value


func get_slope_at(grid_position: Vector2i) -> float:
	var index := get_tile_index(grid_position)
	return tile_slopes[index] if index >= 0 else 0.0


func set_slope_at(grid_position: Vector2i, value: float) -> void:
	var index := get_tile_index(grid_position)
	if index >= 0:
		tile_slopes[index] = value


func get_forest_density_at(grid_position: Vector2i) -> float:
	var index := get_tile_index(grid_position)
	return forest_densities[index] if index >= 0 else 0.0


func set_forest_density_at(grid_position: Vector2i, value: float) -> void:
	var index := get_tile_index(grid_position)
	if index >= 0:
		forest_densities[index] = value


func get_river_mask_at(grid_position: Vector2i) -> float:
	var index := get_tile_index(grid_position)
	return river_masks[index] if index >= 0 else 0.0


func set_river_mask_at(grid_position: Vector2i, value: float) -> void:
	var index := get_tile_index(grid_position)
	if index >= 0:
		river_masks[index] = value


func get_tile_water_height_at(grid_position: Vector2i) -> float:
	var index := get_tile_index(grid_position)
	return tile_water_heights[index] if index >= 0 else 0.0


func is_buildable_at(grid_position: Vector2i) -> bool:
	var index := get_tile_index(grid_position)
	return index >= 0 and buildable_flags[index] != 0


func set_buildable_at(grid_position: Vector2i, value: bool) -> void:
	var index := get_tile_index(grid_position)
	if index >= 0:
		buildable_flags[index] = 1 if value else 0


## 获取格子阵营 ID
func get_faction_id_at(grid_position: Vector2i) -> int:
	var index := get_tile_index(grid_position)
	if index < 0:
		return DemoPlayerContext.FactionId.NONE
	return int(faction_types[index]) - 1


## 设置格子阵营 ID
func set_faction_id_at(grid_position: Vector2i, faction_id: int) -> void:
	var index := get_tile_index(grid_position)
	if index >= 0:
		faction_types[index] = clampi(faction_id + 1, 0, 255)


func set_height_sample(vertex_grid: Vector2i, height: float) -> void:
	var index := _get_vertex_sample_index(vertex_grid)
	if index >= 0:
		height_samples[index] = height


func get_height_sample(vertex_grid: Vector2i) -> float:
	var clamped_grid := Vector2i(
		clampi(vertex_grid.x, get_min_vertex_grid().x, get_max_vertex_grid().x),
		clampi(vertex_grid.y, get_min_vertex_grid().y, get_max_vertex_grid().y)
	)
	var index := _get_vertex_sample_index(clamped_grid)
	return height_samples[index] if index >= 0 else 0.0


func set_water_height_sample(vertex_grid: Vector2i, height: float) -> void:
	var index := _get_vertex_sample_index(vertex_grid)
	if index >= 0:
		water_height_samples[index] = height


func get_water_height_sample(vertex_grid: Vector2i) -> float:
	var clamped_grid := Vector2i(
		clampi(vertex_grid.x, get_min_vertex_grid().x, get_max_vertex_grid().x),
		clampi(vertex_grid.y, get_min_vertex_grid().y, get_max_vertex_grid().y)
	)
	var index := _get_vertex_sample_index(clamped_grid)
	return water_height_samples[index] if index >= 0 else 0.0


func get_height_at_grid(grid_position: Vector2i) -> float:
	var index := get_tile_index(grid_position)
	return tile_heights[index] if index >= 0 else get_height_at_world(
		float(grid_position.x) * cell_size,
		float(grid_position.y) * cell_size
	)


## 阶梯地形：返回格子量化后的顶部高度（surface_height）。
## 原始高度数据 tile_heights[] 保持不变，此方法仅用于视觉和碰撞。
func get_surface_height_at_grid(grid_position: Vector2i) -> float:
	var raw_height := get_height_at_grid(grid_position)
	var level := roundi(raw_height / MapGenerationConfig.HEIGHT_STEP)
	return float(level) * MapGenerationConfig.HEIGHT_STEP


## 阶梯地形：返回世界坐标处的量化高度（用于射线拾取）。
func get_surface_height_at_world(world_x: float, world_z: float) -> float:
	var grid_position := world_to_grid(Vector3(world_x, 0.0, world_z))
	return get_surface_height_at_grid(grid_position)


func get_height_at_world(world_x: float, world_z: float) -> float:
	var sample_position := Vector2(
		world_x / cell_size + 0.5,
		world_z / cell_size + 0.5
	)
	var sample_min := get_min_vertex_grid()
	var sample_max := get_max_vertex_grid()
	var base := Vector2i(
		clampi(floori(sample_position.x), sample_min.x, sample_max.x - 1),
		clampi(floori(sample_position.y), sample_min.y, sample_max.y - 1)
	)
	var fraction := Vector2(
		clampf(sample_position.x - float(base.x), 0.0, 1.0),
		clampf(sample_position.y - float(base.y), 0.0, 1.0)
	)
	var top := lerpf(
		get_height_sample(base),
		get_height_sample(base + Vector2i.RIGHT),
		fraction.x
	)
	var bottom := lerpf(
		get_height_sample(base + Vector2i.DOWN),
		get_height_sample(base + Vector2i.ONE),
		fraction.x
	)
	return lerpf(top, bottom, fraction.y)


func get_surface_normal_at_vertex(vertex_grid: Vector2i) -> Vector3:
	var left := get_height_sample(vertex_grid + Vector2i.LEFT)
	var right := get_height_sample(vertex_grid + Vector2i.RIGHT)
	var back := get_height_sample(vertex_grid + Vector2i.UP)
	var front := get_height_sample(vertex_grid + Vector2i.DOWN)
	return Vector3(left - right, cell_size * 2.0, back - front).normalized()


func get_surface_world_position(grid_position: Vector2i, offset: float = 0.0) -> Vector3:
	# 使用阶梯量化后的格子顶部高度，确保实体与阶梯地形一致
	return grid_to_world(grid_position, get_surface_height_at_grid(grid_position) + offset)


func recalculate_height_range() -> void:
	if height_samples.is_empty():
		min_terrain_height = 0.0
		max_terrain_height = 0.0
		return
	min_terrain_height = height_samples[0]
	max_terrain_height = height_samples[0]
	for height in height_samples:
		min_terrain_height = minf(min_terrain_height, height)
		max_terrain_height = maxf(max_terrain_height, height)


func intersect_heightfield_ray(
	ray_origin: Vector3,
	ray_direction: Vector3,
	max_distance: float = 2000.0
) -> Variant:
	if ray_direction.y >= -0.0001:
		return null
	var start_distance := maxf(
		0.0,
		(ray_origin.y - (max_terrain_height + 2.0)) / -ray_direction.y
	)
	var end_distance := minf(
		max_distance,
		(ray_origin.y - (min_terrain_height - 2.0)) / -ray_direction.y
	)
	if end_distance <= start_distance:
		return null
	var start_delta := _get_ray_height_delta(ray_origin, ray_direction, start_distance)
	var end_delta := _get_ray_height_delta(ray_origin, ray_direction, end_distance)
	if start_delta < 0.0 or end_delta > 0.0:
		return null
	for iteration in range(24):
		var middle := (start_distance + end_distance) * 0.5
		var delta := _get_ray_height_delta(ray_origin, ray_direction, middle)
		if delta > 0.0:
			start_distance = middle
		else:
			end_distance = middle
	var hit := ray_origin + ray_direction * ((start_distance + end_distance) * 0.5)
	if not is_valid_grid(world_to_grid(hit)):
		return null
	# 返回阶梯量化后的高度，与可视 Mesh 一致
	hit.y = get_surface_height_at_world(hit.x, hit.z)
	return hit


func add_city(city: MapCityData) -> void:
	if city == null:
		return
	cities.append(city)
	_cities_by_id[city.city_id] = city
	var occupied_rect := city.get_occupied_grid_rect()
	for grid_y in range(occupied_rect.position.y, occupied_rect.end.y):
		for grid_x in range(occupied_rect.position.x, occupied_rect.end.x):
			var occupied_grid := Vector2i(grid_x, grid_y)
			if is_valid_grid(occupied_grid):
				_cities_by_grid[occupied_grid] = city


func get_city_at_grid(grid_position: Vector2i) -> MapCityData:
	return _cities_by_grid.get(grid_position) as MapCityData


func get_city_by_id(city_id: String) -> MapCityData:
	return _cities_by_id.get(city_id) as MapCityData


func get_city_by_role(city_role: int) -> MapCityData:
	for city in cities:
		if city.city_role == city_role:
			return city
	return null


func add_resource_point(resource_point: MapResourcePointData) -> void:
	if resource_point == null:
		return
	resource_points.append(resource_point)
	_resources_by_id[resource_point.resource_id] = resource_point
	# 资源点当前使用 3×3 中立交互占位，正式占领范围由玩法层另行定义。
	for y_offset in range(-1, 2):
		for x_offset in range(-1, 2):
			var occupied_grid := resource_point.grid_position + Vector2i(x_offset, y_offset)
			if is_valid_grid(occupied_grid) and not _resources_by_grid.has(occupied_grid):
				_resources_by_grid[occupied_grid] = resource_point


func get_resource_at_grid(grid_position: Vector2i) -> MapResourcePointData:
	return _resources_by_grid.get(grid_position) as MapResourcePointData


func get_resource_by_id(resource_id: String) -> MapResourcePointData:
	return _resources_by_id.get(resource_id) as MapResourcePointData


func get_resources_by_type(resource_type: int) -> Array[MapResourcePointData]:
	var matches: Array[MapResourcePointData] = []
	for resource_point in resource_points:
		if resource_point.resource_type == resource_type:
			matches.append(resource_point)
	return matches


func get_crossing_at_grid(grid_position: Vector2i) -> Dictionary:
	var exact_crossing: Dictionary = _crossings_by_grid.get(grid_position, {})
	if not exact_crossing.is_empty():
		return exact_crossing
	for crossing in crossings:
		var center := crossing.get("grid_position", Vector2i.ZERO) as Vector2i
		var radius := int(crossing.get("selection_radius", 2))
		if (
			absi(grid_position.x - center.x) <= radius
			and absi(grid_position.y - center.y) <= radius
		):
			return crossing
	return {}


func add_crossing(crossing: Dictionary, occupied_cells: Array) -> void:
	if crossing.is_empty():
		return
	crossings.append(crossing)
	for cell_variant in occupied_cells:
		var grid_position := cell_variant as Vector2i
		if is_valid_grid(grid_position):
			_crossings_by_grid[grid_position] = crossing


func get_crossing_type_at(grid_position: Vector2i) -> String:
	var crossing: Dictionary = _crossings_by_grid.get(grid_position, {})
	# 未被显式选为过河点的低级道路交叉保持中断，不能默认渲染成桥梁。
	return str(crossing.get("crossing_type", ""))


func get_world_half_extent() -> Vector2:
	return Vector2(
		float(map_size.x) * cell_size * 0.5,
		float(map_size.y) * cell_size * 0.5
	)


func _get_vertex_sample_index(vertex_grid: Vector2i) -> int:
	var min_vertex := get_min_vertex_grid()
	var max_vertex := get_max_vertex_grid()
	if (
		vertex_grid.x < min_vertex.x
		or vertex_grid.x > max_vertex.x
		or vertex_grid.y < min_vertex.y
		or vertex_grid.y > max_vertex.y
	):
		return -1
	var width := map_size.x + 1
	return (vertex_grid.y - min_vertex.y) * width + vertex_grid.x - min_vertex.x


func _get_ray_height_delta(
	ray_origin: Vector3,
	ray_direction: Vector3,
	distance: float
) -> float:
	var point := ray_origin + ray_direction * distance
	# 使用阶梯量化高度，确保射线拾取与阶梯 Mesh 一致
	return point.y - get_surface_height_at_world(point.x, point.z)
