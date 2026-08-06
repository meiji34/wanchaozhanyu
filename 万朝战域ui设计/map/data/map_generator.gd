class_name DemoMapGenerator
extends RefCounted

const STRATEGIC_CITIES: Array[Dictionary] = [
	{
		"id": "forest_capital",
		"name": "森林主城",
		"position": MapGenerationConfig.FOREST_CAPITAL,
		"faction": "森林阵营",
		"faction_id": DemoPlayerContext.FactionId.FOREST,
		"role": MapCityData.Role.FACTION_CAPITAL,
	},
	{
		"id": "mountain_capital",
		"name": "山地主城",
		"position": MapGenerationConfig.MOUNTAIN_CAPITAL,
		"faction": "山地阵营",
		"faction_id": DemoPlayerContext.FactionId.MOUNTAIN,
		"role": MapCityData.Role.FACTION_CAPITAL,
	},
	{
		"id": "wetland_capital",
		"name": "湿地主城",
		"position": MapGenerationConfig.WETLAND_CAPITAL,
		"faction": "湿地阵营",
		"faction_id": DemoPlayerContext.FactionId.WETLAND,
		"role": MapCityData.Role.FACTION_CAPITAL,
	},
	{
		"id": "central_capital",
		"name": "中央主城",
		"position": MapGenerationConfig.CENTRAL_CAPITAL,
		"faction": "中立",
		"faction_id": DemoPlayerContext.FactionId.NONE,
		"role": MapCityData.Role.CENTRAL_CAPITAL,
	},
]

const MAIN_ROAD_CONNECTIONS: Array[Dictionary] = [
	{"from": "forest_capital", "to": "central_capital"},
	{"from": "mountain_capital", "to": "central_capital"},
	{"from": "wetland_capital", "to": "central_capital"},
]

const RESOURCE_SEEDS: Array[Dictionary] = [
	{"id": "forest_wood_1", "type": MapResourcePointData.ResourceType.WOOD, "seed": Vector2i(-150, -112), "zone": MapTileTypes.Zone.FOREST},
	{"id": "forest_wood_2", "type": MapResourcePointData.ResourceType.WOOD, "seed": Vector2i(-112, -148), "zone": MapTileTypes.Zone.FOREST},
	{"id": "forest_wood_3", "type": MapResourcePointData.ResourceType.WOOD, "seed": Vector2i(-72, -76), "zone": MapTileTypes.Zone.FOREST},
	{"id": "forest_stone_1", "type": MapResourcePointData.ResourceType.STONE, "seed": Vector2i(-160, -54), "zone": MapTileTypes.Zone.FOREST},
	{"id": "forest_food_1", "type": MapResourcePointData.ResourceType.FOOD, "seed": Vector2i(-82, -116), "zone": MapTileTypes.Zone.FOREST},
	{"id": "mountain_stone_1", "type": MapResourcePointData.ResourceType.STONE, "seed": Vector2i(-154, 116), "zone": MapTileTypes.Zone.MOUNTAIN},
	{"id": "mountain_stone_2", "type": MapResourcePointData.ResourceType.STONE, "seed": Vector2i(-110, 150), "zone": MapTileTypes.Zone.MOUNTAIN},
	{"id": "mountain_stone_3", "type": MapResourcePointData.ResourceType.STONE, "seed": Vector2i(-66, 92), "zone": MapTileTypes.Zone.MOUNTAIN},
	{"id": "mountain_wood_1", "type": MapResourcePointData.ResourceType.WOOD, "seed": Vector2i(-160, 58), "zone": MapTileTypes.Zone.MOUNTAIN},
	{"id": "mountain_food_1", "type": MapResourcePointData.ResourceType.FOOD, "seed": Vector2i(-82, 132), "zone": MapTileTypes.Zone.MOUNTAIN},
	{"id": "wetland_food_1", "type": MapResourcePointData.ResourceType.FOOD, "seed": Vector2i(164, -62), "zone": MapTileTypes.Zone.WETLAND},
	{"id": "wetland_food_2", "type": MapResourcePointData.ResourceType.FOOD, "seed": Vector2i(164, 72), "zone": MapTileTypes.Zone.WETLAND},
	{"id": "wetland_food_3", "type": MapResourcePointData.ResourceType.FOOD, "seed": Vector2i(74, 12), "zone": MapTileTypes.Zone.WETLAND},
	{"id": "wetland_wood_1", "type": MapResourcePointData.ResourceType.WOOD, "seed": Vector2i(70, -62), "zone": MapTileTypes.Zone.WETLAND},
	{"id": "wetland_stone_1", "type": MapResourcePointData.ResourceType.STONE, "seed": Vector2i(68, 92), "zone": MapTileTypes.Zone.WETLAND},
	{"id": "fe_1", "name": "铁矿 Fe-1", "type": MapResourcePointData.ResourceType.IRON, "seed": Vector2i(-70, -144), "zone": MapTileTypes.Zone.FOREST},
	{"id": "fe_2", "name": "铁矿 Fe-2", "type": MapResourcePointData.ResourceType.IRON, "seed": Vector2i(-70, 144), "zone": MapTileTypes.Zone.MOUNTAIN},
	{"id": "fe_3", "name": "铁矿 Fe-3", "type": MapResourcePointData.ResourceType.IRON, "seed": Vector2i(96, -110), "zone": MapTileTypes.Zone.WETLAND},
	{"id": "fe_4", "name": "铁矿 Fe-4", "type": MapResourcePointData.ResourceType.IRON, "seed": Vector2i(96, 110), "zone": MapTileTypes.Zone.WETLAND},
	{"id": "fe_5", "name": "铁矿 Fe-5", "type": MapResourcePointData.ResourceType.IRON, "seed": Vector2i(-156, 0), "zone": MapTileTypes.Zone.NEUTRAL},
]


static func generate(config: MapGenerationConfig) -> DemoMapData:
	var data := DemoMapData.new(
		config.map_size,
		config.chunk_size,
		config.cell_size,
		config.seed
	)
	TerrainFieldGenerator.generate_height_samples(data, config)
	TerrainFieldGenerator.populate_tiles(data, config)
	_generate_strategic_cities(data)
	_terrace_strategic_cities(data)
	# 铁矿是路网锚点，先确定铁矿再生成道路；普通资源在路网完成后避让道路选址。
	_generate_resource_points(data, true)
	_generate_road_network(data)
	_generate_resource_points(data, false)
	TerrainFieldGenerator.refresh_tile_surface_data(data)
	_apply_city_site_overrides(data)
	_assign_tile_factions(data)
	_assign_city_tile_factions(data)
	_generate_mountain_pass(data)
	_generate_crossings(data)
	_validate_second_version_layout(data)
	return data


static func _generate_strategic_cities(data: DemoMapData) -> void:
	for city_config in STRATEGIC_CITIES:
		var city := MapCityData.new(
			str(city_config.get("id", "")),
			str(city_config.get("name", "未命名主城")),
			city_config.get("position", Vector2i.ZERO) as Vector2i,
			3 if int(city_config.get("role", 0)) == MapCityData.Role.CENTRAL_CAPITAL else 1,
			MapCityData.DEFAULT_FOOTPRINT_SIZE,
			int(city_config.get("role", MapCityData.Role.FACTION_CAPITAL)),
			str(city_config.get("faction", "中立")),
			int(city_config.get("faction_id", DemoPlayerContext.FactionId.NONE))
		)
		data.add_city(city)


static func _terrace_strategic_cities(data: DemoMapData) -> void:
	for city in data.cities:
		TerrainFieldGenerator.terrace_city_site(
			data,
			city.grid_position,
			city.footprint_size,
			MapGenerationConfig.CITY_TERRACE_BLEND_RADIUS
		)


static func _generate_resource_points(data: DemoMapData, iron_only: bool) -> void:
	var occupied: Dictionary = {}
	for existing_resource in data.resource_points:
		occupied[existing_resource.grid_position] = true
	for seed_config in RESOURCE_SEEDS:
		var resource_type := int(seed_config.get("type", MapResourcePointData.ResourceType.WOOD))
		if (resource_type == MapResourcePointData.ResourceType.IRON) != iron_only:
			continue
		var seed_position := seed_config.get("seed", Vector2i.ZERO) as Vector2i
		var zone_type := int(seed_config.get("zone", MapTileTypes.Zone.NEUTRAL))
		var resolved_position := _find_resource_site(
			data,
			seed_position,
			zone_type,
			occupied,
			not iron_only
		)
		var display_name := str(seed_config.get(
			"name",
			"%s资源点" % MapResourcePointData.get_type_display_name(resource_type)
		))
		var resource_point := MapResourcePointData.new(
			str(seed_config.get("id", "resource")),
			display_name,
			resource_type,
			resolved_position,
			seed_position,
			data.get_zone_type_at(resolved_position)
		)
		data.add_resource_point(resource_point)
		occupied[resolved_position] = true


static func _find_resource_site(
	data: DemoMapData,
	seed_position: Vector2i,
	preferred_zone: int,
	occupied: Dictionary,
	avoid_roads: bool
) -> Vector2i:
	var fallback := seed_position
	var best_score := INF
	for radius in range(0, MapGenerationConfig.RESOURCE_SEARCH_RADIUS + 1):
		for y_offset in range(-radius, radius + 1):
			for x_offset in range(-radius, radius + 1):
				if radius > 0 and absi(x_offset) != radius and absi(y_offset) != radius:
					continue
				var candidate := seed_position + Vector2i(x_offset, y_offset)
				if not _is_valid_resource_site(
					data,
					candidate,
					preferred_zone,
					occupied,
					avoid_roads
				):
					continue
				var score := candidate.distance_squared_to(seed_position)
				if score < best_score:
					fallback = candidate
					best_score = score
		if best_score < INF:
			break
	return fallback


static func _is_valid_resource_site(
	data: DemoMapData,
	grid_position: Vector2i,
	preferred_zone: int,
	occupied: Dictionary,
	avoid_roads: bool
) -> bool:
	if not data.is_valid_grid(grid_position) or occupied.has(grid_position):
		return false
	if preferred_zone != MapTileTypes.Zone.NEUTRAL:
		if data.get_zone_type_at(grid_position) != preferred_zone:
			return false
	elif data.get_zone_type_at(grid_position) == MapTileTypes.Zone.CENTRAL:
		return false
	if (
		data.get_terrain_type_at(grid_position) == MapTileTypes.Terrain.RIVER
		or data.get_river_mask_at(grid_position) > 0.2
		or data.get_city_at_grid(grid_position) != null
		or data.get_slope_at(grid_position) > 0.7
	):
		return false
	if avoid_roads and not _has_resource_road_clearance(data, grid_position):
		return false
	for existing_variant in occupied:
		var existing := existing_variant as Vector2i
		if existing.distance_squared_to(grid_position) < 36:
			return false
	return true


static func _has_resource_road_clearance(data: DemoMapData, grid_position: Vector2i) -> bool:
	var clearance := MapGenerationConfig.RESOURCE_ROAD_CLEARANCE
	for y_offset in range(-clearance, clearance + 1):
		for x_offset in range(-clearance, clearance + 1):
			if data.has_road_at(grid_position + Vector2i(x_offset, y_offset)):
				return false
	return true


static func _generate_road_network(data: DemoMapData) -> void:
	_generate_main_roads(data)
	var fe_1 := data.get_resource_by_id("fe_1").grid_position
	var fe_2 := data.get_resource_by_id("fe_2").grid_position
	var fe_3 := data.get_resource_by_id("fe_3").grid_position
	var fe_4 := data.get_resource_by_id("fe_4").grid_position
	var fe_5 := data.get_resource_by_id("fe_5").grid_position
	_add_road_polyline(data, "forest_secondary", MapTileTypes.RoadType.NORMAL, MapGenerationConfig.NORMAL_ROAD_WIDTH, [MapGenerationConfig.FOREST_CAPITAL, Vector2i(-140, -42), fe_5])
	_add_road_polyline(data, "mountain_secondary", MapTileTypes.RoadType.NORMAL, MapGenerationConfig.NORMAL_ROAD_WIDTH, [MapGenerationConfig.MOUNTAIN_CAPITAL, Vector2i(-142, 42), fe_5])
	_add_road_polyline(data, "wetland_secondary", MapTileTypes.RoadType.NORMAL, MapGenerationConfig.NORMAL_ROAD_WIDTH, [MapGenerationConfig.WETLAND_CAPITAL, Vector2i(132, -44), fe_3])
	_add_road_polyline(data, "outer_ring", MapTileTypes.RoadType.RING, MapGenerationConfig.RING_ROAD_WIDTH, [fe_1, Vector2i(24, -154), fe_3, Vector2i(78, -62), Vector2i(78, 88), fe_4, Vector2i(24, 154), fe_2, Vector2i(-150, 92), fe_5, Vector2i(-150, -92), fe_1])
	_add_road_polyline(data, "forest_hidden", MapTileTypes.RoadType.HIDDEN, MapGenerationConfig.HIDDEN_PATH_WIDTH, [MapGenerationConfig.FOREST_CAPITAL, Vector2i(-96, -120), fe_1])
	_add_road_polyline(data, "mountain_hidden", MapTileTypes.RoadType.HIDDEN, MapGenerationConfig.HIDDEN_PATH_WIDTH, [MapGenerationConfig.MOUNTAIN_CAPITAL, Vector2i(-96, 120), fe_2])


static func _generate_main_roads(data: DemoMapData) -> void:
	for connection in MAIN_ROAD_CONNECTIONS:
		var from_id := str(connection.get("from", ""))
		var to_id := str(connection.get("to", ""))
		var from_city := data.get_city_by_id(from_id)
		var to_city := data.get_city_by_id(to_id)
		if from_city == null or to_city == null:
			push_warning("主干道端点缺失：%s -> %s" % [from_id, to_id])
			continue
		var route_points: Array = [from_city.grid_position, to_city.grid_position]
		if from_id == "mountain_capital":
			# 先沿山脊穿过明确关隘，再转向中央，避免道路从山脉边缘直接滑出。
			route_points = [from_city.grid_position, Vector2i(-94, 98), Vector2i(-68, 82), to_city.grid_position]
		_add_road_polyline(data, "%s_to_%s" % [from_id, to_id], MapTileTypes.RoadType.MAIN, MapGenerationConfig.MAIN_ROAD_WIDTH, route_points, {"from_city_id": from_id, "to_city_id": to_id})


static func _add_road_polyline(
	data: DemoMapData,
	road_id: String,
	road_type: int,
	width: int,
	points: Array,
	extra_metadata: Dictionary = {}
) -> void:
	if points.size() < 2:
		return
	for index in range(points.size() - 1):
		var from_grid := points[index] as Vector2i
		var to_grid := points[index + 1] as Vector2i
		# 所有道路共享同一套连续缓坡处理，避免支路、环路和小径悬空或切入地形。
		TerrainFieldGenerator.smooth_road_corridor(data, from_grid, to_grid, width)
		_mark_road_line(data, from_grid, to_grid, width, road_type)
	var connection := {
		"road_id": road_id,
		"road_type": road_type,
		"width": width,
		"points": points.duplicate(),
		"visible_initially": road_type != MapTileTypes.RoadType.HIDDEN,
	}
	connection.merge(extra_metadata, true)
	data.road_connections.append(connection)


static func _mark_road_line(data: DemoMapData, from_grid: Vector2i, to_grid: Vector2i, width: int, road_type: int) -> void:
	var current := from_grid
	var delta := Vector2i(absi(to_grid.x - from_grid.x), -absi(to_grid.y - from_grid.y))
	var step := Vector2i(1 if from_grid.x < to_grid.x else -1, 1 if from_grid.y < to_grid.y else -1)
	var error := delta.x + delta.y
	while true:
		_stamp_road(data, current, width, road_type)
		if current == to_grid:
			break
		var previous := current
		var doubled_error := error * 2
		if doubled_error >= delta.y:
			error += delta.y
			current.x += step.x
		if doubled_error <= delta.x:
			error += delta.x
			current.y += step.y
		# 一格道路出现斜向步时补一个正交连接格，确保四方向寻路不会把道路判为断开。
		if current.x != previous.x and current.y != previous.y:
			_stamp_road(data, Vector2i(current.x, previous.y), width, road_type)


static func _stamp_road(data: DemoMapData, center: Vector2i, width: int, road_type: int) -> void:
	# 偶数宽度采用一侧多一格的确定性覆盖，避免 2 格配置实际被扩成 3 格。
	var safe_width := maxi(1, width)
	var min_offset := -floori(float(safe_width - 1) * 0.5)
	var max_offset := ceili(float(safe_width - 1) * 0.5)
	for y_offset in range(min_offset, max_offset + 1):
		for x_offset in range(min_offset, max_offset + 1):
			var grid_position := center + Vector2i(x_offset, y_offset)
			if not data.is_valid_grid(grid_position):
				continue
			var current_type := data.get_road_type_at(grid_position)
			if MapTileTypes.get_road_priority(road_type) > MapTileTypes.get_road_priority(current_type):
				data.set_road_type_at(grid_position, road_type)


static func _generate_mountain_pass(data: DemoMapData) -> void:
	var target := Vector2i(-88, 94)
	var best_position := target
	var best_distance := INF
	for grid_y in range(target.y - 34, target.y + 35):
		for grid_x in range(target.x - 34, target.x + 35):
			var candidate := Vector2i(grid_x, grid_y)
			if (
				data.get_road_type_at(candidate) != MapTileTypes.RoadType.MAIN
				or data.get_zone_type_at(candidate) != MapTileTypes.Zone.MOUNTAIN
			):
				continue
			var distance := candidate.distance_squared_to(target)
			if distance < best_distance:
				best_distance = distance
				best_position = candidate
	data.passes.append({
		"pass_id": "mountain_main_pass",
		"display_name": "山地关隘",
		"grid_position": best_position,
		"opening_width": MapGenerationConfig.PASS_OPENING_WIDTH,
		"neutral_interactable": true,
	})


static func _generate_crossings(data: DemoMapData) -> void:
	var remaining: Dictionary = {}
	for tile_index in range(data.get_tile_count()):
		var grid_position := data.tile_index_to_grid(tile_index)
		if data.has_road_at(grid_position) and data.get_terrain_type_at(grid_position) == MapTileTypes.Terrain.RIVER:
			remaining[grid_position] = true
	var components: Array[Array] = []
	var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	while not remaining.is_empty():
		var start := remaining.keys()[0] as Vector2i
		remaining.erase(start)
		var queue: Array[Vector2i] = [start]
		var cursor := 0
		while cursor < queue.size():
			var current := queue[cursor]
			cursor += 1
			for direction in directions:
				var neighbor := current + direction
				if remaining.erase(neighbor):
					queue.append(neighbor)
		components.append(queue)
	var mandatory_components: Array[Array] = []
	var optional_components: Array[Array] = []
	for component in components:
		if _component_has_main_road(data, component):
			mandatory_components.append(component)
		else:
			optional_components.append(component)
	optional_components.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())
	var selected_components: Array[Array] = mandatory_components.duplicate()
	var target_count := mini(MapGenerationConfig.CROSSING_COUNT_MAX, components.size())
	target_count = maxi(MapGenerationConfig.CROSSING_COUNT_MIN, target_count)
	for component in optional_components:
		if selected_components.size() >= target_count:
			break
		selected_components.append(component)
	for index in range(selected_components.size()):
		var component: Array = selected_components[index]
		var center := _get_component_center(component)
		var carries_main_road := _component_has_main_road(data, component)
		var kind := (
			"ford"
			if not carries_main_road and index == selected_components.size() - 1
			else "bridge"
		)
		var crossing := {
			"crossing_id": "crossing_%d" % (index + 1),
			"display_name": "浅滩" if kind == "ford" else "桥梁",
			"grid_position": center,
			"crossing_type": kind,
			"selection_radius": 3,
			"cell_count": component.size(),
			"road_type": MapTileTypes.RoadType.MAIN if carries_main_road else data.get_road_type_at(center),
			"road_direction": _get_component_road_direction(component),
			"visual_mode": "textured_deck_placeholder" if kind == "bridge" else "ford_placeholder",
			"model_scene_path": "",
		}
		data.add_crossing(crossing, component)


static func _component_has_main_road(data: DemoMapData, component: Array) -> bool:
	for point_variant in component:
		if data.get_road_type_at(point_variant as Vector2i) == MapTileTypes.RoadType.MAIN:
			return true
	return false


static func _get_component_road_direction(component: Array) -> Vector2:
	if component.size() < 2:
		return Vector2.RIGHT
	var center := Vector2.ZERO
	for point_variant in component:
		center += Vector2(point_variant as Vector2i)
	center /= float(component.size())
	var xx := 0.0
	var xy := 0.0
	var yy := 0.0
	for point_variant in component:
		var offset := Vector2(point_variant as Vector2i) - center
		xx += offset.x * offset.x
		xy += offset.x * offset.y
		yy += offset.y * offset.y
	var angle := 0.5 * atan2(2.0 * xy, xx - yy)
	var direction := Vector2(cos(angle), sin(angle)).normalized()
	return direction if direction.length_squared() > 0.0 else Vector2.RIGHT


static func _get_component_center(component: Array) -> Vector2i:
	var sum := Vector2.ZERO
	for point_variant in component:
		sum += Vector2(point_variant as Vector2i)
	var average := sum / float(maxi(1, component.size()))
	var best := component[0] as Vector2i
	var best_distance := Vector2(best).distance_squared_to(average)
	for point_variant in component:
		var point := point_variant as Vector2i
		var distance := Vector2(point).distance_squared_to(average)
		if distance < best_distance:
			best = point
			best_distance = distance
	return best


static func _apply_city_site_overrides(data: DemoMapData) -> void:
	for city in data.cities:
		var occupied_rect := city.get_occupied_grid_rect()
		for grid_y in range(occupied_rect.position.y, occupied_rect.end.y):
			for grid_x in range(occupied_rect.position.x, occupied_rect.end.x):
				var grid_position := Vector2i(grid_x, grid_y)
				if not data.is_valid_grid(grid_position):
					continue
				data.set_terrain_type_at(grid_position, MapTileTypes.Terrain.PLAIN)
				data.set_forest_density_at(grid_position, 0.0)
				data.set_river_mask_at(grid_position, 0.0)
				data.set_slope_at(grid_position, 0.0)
				data.set_buildable_at(grid_position, true)


## 根据区域(zone)分配阵营归属。zone_type 指地形区域，faction_id 指政治归属，两者独立。
static func _assign_tile_factions(data: DemoMapData) -> void:
	var min_grid: Vector2i = data.get_min_grid()
	var max_grid: Vector2i = data.get_max_grid()
	for grid_y in range(min_grid.y, max_grid.y + 1):
		for grid_x in range(min_grid.x, max_grid.x + 1):
			var grid_position: Vector2i = Vector2i(grid_x, grid_y)
			var zone_type: int = data.get_zone_type_at(grid_position)
			var assigned_faction_id: int = DemoPlayerContext.FactionId.NONE
			match zone_type:
				MapTileTypes.Zone.FOREST:
					assigned_faction_id = DemoPlayerContext.FactionId.FOREST
				MapTileTypes.Zone.MOUNTAIN:
					assigned_faction_id = DemoPlayerContext.FactionId.MOUNTAIN
				MapTileTypes.Zone.WETLAND:
					assigned_faction_id = DemoPlayerContext.FactionId.WETLAND
				_:
					assigned_faction_id = DemoPlayerContext.FactionId.NONE
			data.set_faction_id_at(grid_position, assigned_faction_id)


## 将主城占地区域的格子阵营设为主城阵营
static func _assign_city_tile_factions(data: DemoMapData) -> void:
	for city in data.cities:
		if city.faction_id == DemoPlayerContext.FactionId.NONE:
			continue
		var occupied_rect := city.get_occupied_grid_rect()
		for grid_y in range(occupied_rect.position.y, occupied_rect.end.y):
			for grid_x in range(occupied_rect.position.x, occupied_rect.end.x):
				var grid_position := Vector2i(grid_x, grid_y)
				if data.is_valid_grid(grid_position):
					data.set_faction_id_at(grid_position, city.faction_id)


static func _validate_second_version_layout(data: DemoMapData) -> void:
	if data.cities.size() != MapGenerationConfig.STRATEGIC_CITY_COUNT:
		push_warning("战略城市数量异常：%d" % data.cities.size())
	if data.resource_points.size() != MapGenerationConfig.RESOURCE_POINT_COUNT:
		push_warning("第二版资源点数量异常：%d" % data.resource_points.size())
	if data.get_resources_by_type(MapResourcePointData.ResourceType.IRON).size() != MapGenerationConfig.IRON_POINT_COUNT:
		push_warning("第二版铁矿数量异常")
	if data.crossings.size() < MapGenerationConfig.CROSSING_COUNT_MIN:
		push_warning("湿地过河点不足：%d" % data.crossings.size())
	for city_config in STRATEGIC_CITIES:
		var city_id := str(city_config.get("id", ""))
		var city := data.get_city_by_id(city_id)
		var expected_position := city_config.get("position", Vector2i.ZERO) as Vector2i
		if city == null or city.grid_position != expected_position:
			push_warning("战略城市锚点异常：%s" % city_id)
