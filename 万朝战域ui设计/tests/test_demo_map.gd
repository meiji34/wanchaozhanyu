@tool
extends McpTestSuite

var _generated_map_data: DemoMapData
var _generation_duration_ms := -1


func suite_name() -> String:
	return "demo_map"


func _get_generated_map_data() -> DemoMapData:
	if _generated_map_data == null:
		var started_ms := Time.get_ticks_msec()
		_generated_map_data = DemoMapGenerator.generate(MapGenerationConfig.new())
		_generation_duration_ms = Time.get_ticks_msec() - started_ms
	return _generated_map_data


func test_coordinate_round_trip_and_bounds() -> void:
	var config := MapGenerationConfig.new()
	var data := DemoMapData.new(
		config.map_size,
		config.chunk_size,
		config.cell_size,
		config.seed
	)
	var samples: Array[Vector2i] = [
		Vector2i(-200, -200),
		Vector2i(-1, -1),
		Vector2i.ZERO,
		Vector2i(199, 199),
	]
	for grid_position in samples:
		assert_eq(
			data.world_to_grid(data.grid_to_world(grid_position)),
			grid_position,
			"格子与世界坐标应可往返转换"
		)
	assert_true(data.is_valid_grid(Vector2i(-200, -200)))
	assert_true(data.is_valid_grid(Vector2i(199, 199)))
	assert_false(data.is_valid_grid(Vector2i(200, 0)))
	assert_eq(data.grid_to_chunk(Vector2i(-1, -1)), Vector2i(-1, -1))
	assert_eq(data.grid_to_chunk(Vector2i(0, 0)), Vector2i.ZERO)


func test_compact_tile_storage_and_generation_budget() -> void:
	var data := _get_generated_map_data()
	var expected_count := data.map_size.x * data.map_size.y
	assert_eq(data.terrain_types.size(), expected_count)
	assert_eq(data.zone_types.size(), expected_count)
	assert_eq(data.road_types.size(), expected_count)
	assert_eq(data.tile_heights.size(), expected_count)
	assert_eq(data.tile_slopes.size(), expected_count)
	assert_eq(data.forest_densities.size(), expected_count)
	assert_eq(data.river_masks.size(), expected_count)
	assert_eq(data.buildable_flags.size(), expected_count)
	assert_true(
		data.get_compact_tile_storage_bytes() < 6 * 1024 * 1024,
		"首版连续 Tile/高度数据应控制在 6 MiB 内"
	)
	assert_true(
		_generation_duration_ms <= 2500,
		"400×400 地图数据生成应在 2.5 秒预算内，当前为 %d ms" % _generation_duration_ms
	)

	var sample_grid := MapGenerationConfig.CENTRAL_CAPITAL
	var original_terrain := data.get_terrain_type_at(sample_grid)
	var snapshot := data.get_tile(sample_grid)
	assert_true(snapshot != null)
	if snapshot != null:
		snapshot.terrain_type = MapTileTypes.Terrain.RIVER
		assert_eq(
			data.get_terrain_type_at(sample_grid),
			original_terrain,
			"TileData 兼容对象必须是只读快照，写入必须走 MapData 接口"
		)


func test_generator_produces_required_demo_content() -> void:
	var data := _get_generated_map_data()
	var terrain_counts := {
		MapTileTypes.Terrain.PLAIN: 0,
		MapTileTypes.Terrain.MOUNTAIN: 0,
		MapTileTypes.Terrain.RIVER: 0,
	}
	var zone_counts := {
		MapTileTypes.Zone.FOREST: 0,
		MapTileTypes.Zone.MOUNTAIN: 0,
		MapTileTypes.Zone.WETLAND: 0,
		MapTileTypes.Zone.CENTRAL: 0,
	}
	var road_count := 0
	var mountain_outside_zone_count := 0
	var river_outside_zone_count := 0
	for index in range(data.get_tile_count()):
		var grid_position := data.tile_index_to_grid(index)
		var terrain_type := data.get_terrain_type_at(grid_position)
		var zone_type := data.get_zone_type_at(grid_position)
		terrain_counts[terrain_type] += 1
		if zone_counts.has(zone_type):
			zone_counts[zone_type] += 1
		if data.has_road_at(grid_position):
			road_count += 1
		if (
			terrain_type == MapTileTypes.Terrain.MOUNTAIN
			and zone_type != MapTileTypes.Zone.MOUNTAIN
		):
			mountain_outside_zone_count += 1
		if (
			terrain_type == MapTileTypes.Terrain.RIVER
			and zone_type != MapTileTypes.Zone.WETLAND
		):
			river_outside_zone_count += 1
	assert_eq(data.get_tile_count(), 160000, "演示地图必须生成 400×400 个格子")
	assert_eq(data.map_size, Vector2i(400, 400))
	assert_eq(
		MapGenerationConfig.FOREST_ZONE_RECT,
		Rect2i(Vector2i(-190, -184), Vector2i(147, 161))
	)
	assert_eq(
		MapGenerationConfig.MOUNTAIN_ZONE_RECT,
		Rect2i(Vector2i(-190, 24), Vector2i(155, 167))
	)
	assert_eq(
		MapGenerationConfig.WETLAND_ZONE_RECT,
		Rect2i(Vector2i(40, -156), Vector2i(151, 313))
	)
	assert_eq(data.cities.size(), 4, "第二版继续复用四座战略主城")
	assert_eq(MapGenerationConfig.CITY_CAPACITY, 12, "地图数据仍保留 12 座城市容量")
	assert_eq(data.road_connections.size(), 9, "第二版应形成主干道、支路、环路与小径网络")
	assert_eq(data.passes.size(), 1, "第二版必须生成山地主关隘")
	var expected_capitals := {
		"forest_capital": MapGenerationConfig.FOREST_CAPITAL,
		"mountain_capital": MapGenerationConfig.MOUNTAIN_CAPITAL,
		"wetland_capital": MapGenerationConfig.WETLAND_CAPITAL,
		"central_capital": MapGenerationConfig.CENTRAL_CAPITAL,
	}
	for city_id in expected_capitals:
		var strategic_city := data.get_city_by_id(str(city_id))
		assert_true(strategic_city != null, "战略主城必须存在：%s" % city_id)
		if strategic_city != null:
			assert_eq(strategic_city.grid_position, expected_capitals[city_id], "战略主城坐标必须固定")
			assert_eq(
				data.get_tile(strategic_city.grid_position).road_type,
				MapTileTypes.RoadType.MAIN,
				"每座战略主城必须接入主干道"
			)
	assert_eq(
		data.get_tile(MapGenerationConfig.FOREST_CAPITAL).zone_type,
		MapTileTypes.Zone.FOREST
	)
	assert_eq(
		data.get_tile(MapGenerationConfig.MOUNTAIN_CAPITAL).zone_type,
		MapTileTypes.Zone.MOUNTAIN
	)
	assert_eq(
		data.get_tile(MapGenerationConfig.WETLAND_CAPITAL).zone_type,
		MapTileTypes.Zone.WETLAND
	)
	assert_eq(
		data.get_tile(MapGenerationConfig.CENTRAL_CAPITAL).zone_type,
		MapTileTypes.Zone.CENTRAL
	)
	for city in data.cities:
		assert_eq(city.footprint_size, Vector2i(13, 13), "每座城池必须占用 13×13 格")
		assert_eq(
			city.get_world_footprint_size(data.cell_size),
			Vector2(26.0, 26.0),
			"单格 2 世界单位时城池占地必须为 26×26 世界单位"
		)
		var occupied_rect := city.get_occupied_grid_rect()
		for grid_y in range(occupied_rect.position.y, occupied_rect.end.y):
			for grid_x in range(occupied_rect.position.x, occupied_rect.end.x):
				assert_eq(
					data.get_city_at_grid(Vector2i(grid_x, grid_y)),
					city,
					"城池占地区域内的任意格子都应命中该城池"
				)
	assert_gt(terrain_counts[MapTileTypes.Terrain.PLAIN], 40000)
	assert_gt(terrain_counts[MapTileTypes.Terrain.MOUNTAIN], 2000)
	assert_gt(terrain_counts[MapTileTypes.Terrain.RIVER], 800)
	assert_eq(mountain_outside_zone_count, 0, "山脉必须位于放大后的山地区")
	assert_eq(river_outside_zone_count, 0, "河流必须位于放大后的湿地区")
	assert_gt(road_count, 1000)
	assert_gt(zone_counts[MapTileTypes.Zone.FOREST], 4000)
	assert_gt(zone_counts[MapTileTypes.Zone.MOUNTAIN], 4000)
	assert_gt(zone_counts[MapTileTypes.Zone.WETLAND], 4000)
	assert_gt(zone_counts[MapTileTypes.Zone.CENTRAL], 4000)


func test_second_version_strategic_objects_and_routes() -> void:
	var data := _get_generated_map_data()
	assert_eq(data.resource_points.size(), MapGenerationConfig.RESOURCE_POINT_COUNT)
	var iron_points := data.get_resources_by_type(MapResourcePointData.ResourceType.IRON)
	assert_eq(iron_points.size(), MapGenerationConfig.IRON_POINT_COUNT)
	var expected_iron_seeds := {
		"fe_1": Vector2i(-70, -144),
		"fe_2": Vector2i(-70, 144),
		"fe_3": Vector2i(96, -110),
		"fe_4": Vector2i(96, 110),
		"fe_5": Vector2i(-156, 0),
	}
	var base_resource_types_by_zone := {
		MapTileTypes.Zone.FOREST: {},
		MapTileTypes.Zone.MOUNTAIN: {},
		MapTileTypes.Zone.WETLAND: {},
	}
	for resource_point in data.resource_points:
		assert_true(data.is_valid_grid(resource_point.grid_position))
		assert_ne(
			data.get_terrain_type_at(resource_point.grid_position),
			MapTileTypes.Terrain.RIVER,
			"资源点实体不能落在河床中"
		)
		assert_true(data.get_city_at_grid(resource_point.grid_position) == null)
		if resource_point.resource_type == MapResourcePointData.ResourceType.IRON:
			assert_eq(resource_point.seed_grid_position, expected_iron_seeds[resource_point.resource_id])
			assert_true(
				resource_point.grid_position.distance_to(resource_point.seed_grid_position) <= 16.0,
				"铁矿允许为避开河床局部偏移，但不能离开策划种子区域"
			)
			assert_true(data.has_road_at(resource_point.grid_position), "五处铁矿必须接入外围道路网络")
		else:
			for y_offset in range(-MapGenerationConfig.RESOURCE_ROAD_CLEARANCE, MapGenerationConfig.RESOURCE_ROAD_CLEARANCE + 1):
				for x_offset in range(-MapGenerationConfig.RESOURCE_ROAD_CLEARANCE, MapGenerationConfig.RESOURCE_ROAD_CLEARANCE + 1):
					assert_false(
						data.has_road_at(resource_point.grid_position + Vector2i(x_offset, y_offset)),
						"普通资源点及其交互占位必须避开道路走廊：%s @ %s" % [
							resource_point.resource_id,
							resource_point.grid_position,
						]
					)
			if base_resource_types_by_zone.has(resource_point.zone_type):
				base_resource_types_by_zone[resource_point.zone_type][resource_point.resource_type] = true
	for zone_type in base_resource_types_by_zone:
		var available_types: Dictionary = base_resource_types_by_zone[zone_type]
		assert_true(available_types.has(MapResourcePointData.ResourceType.WOOD), "每个阵营本土必须有木材")
		assert_true(available_types.has(MapResourcePointData.ResourceType.STONE), "每个阵营本土必须有石料")
		assert_true(available_types.has(MapResourcePointData.ResourceType.FOOD), "每个阵营本土必须有粮食")

	var connection_counts := {
		MapTileTypes.RoadType.MAIN: 0,
		MapTileTypes.RoadType.NORMAL: 0,
		MapTileTypes.RoadType.RING: 0,
		MapTileTypes.RoadType.HIDDEN: 0,
	}
	var road_cells: Dictionary = {}
	for connection in data.road_connections:
		var road_type := int(connection.get("road_type", MapTileTypes.RoadType.NONE))
		connection_counts[road_type] = int(connection_counts.get(road_type, 0)) + 1
		var expected_widths := {
			MapTileTypes.RoadType.MAIN: MapGenerationConfig.MAIN_ROAD_WIDTH,
			MapTileTypes.RoadType.NORMAL: MapGenerationConfig.NORMAL_ROAD_WIDTH,
			MapTileTypes.RoadType.RING: MapGenerationConfig.RING_ROAD_WIDTH,
			MapTileTypes.RoadType.HIDDEN: MapGenerationConfig.HIDDEN_PATH_WIDTH,
		}
		assert_eq(int(connection.get("width", 0)), int(expected_widths[road_type]))
	for tile_index in range(data.get_tile_count()):
		var grid_position := data.tile_index_to_grid(tile_index)
		var road_type := data.get_road_type_at(grid_position)
		if road_type != MapTileTypes.RoadType.NONE:
			road_cells[grid_position] = true
		if road_type == MapTileTypes.RoadType.RING:
			assert_gt(Vector2(grid_position).length(), 52.0, "外围环路不得切入中央核心区")
	assert_eq(connection_counts[MapTileTypes.RoadType.MAIN], 3)
	assert_eq(connection_counts[MapTileTypes.RoadType.NORMAL], 3)
	assert_eq(connection_counts[MapTileTypes.RoadType.RING], 1)
	assert_eq(connection_counts[MapTileTypes.RoadType.HIDDEN], 2)

	var reachable := _get_reachable_cells(road_cells, MapGenerationConfig.CENTRAL_CAPITAL)
	for city in data.cities:
		assert_true(reachable.has(city.grid_position), "所有战略城市必须处于同一道路连通分量")
	for iron_point in iron_points:
		assert_true(reachable.has(iron_point.grid_position), "外围环路必须接通五个铁矿方向")

	assert_true(data.crossings.size() >= MapGenerationConfig.CROSSING_COUNT_MIN)
	assert_true(data.crossings.size() <= MapGenerationConfig.CROSSING_COUNT_MAX)
	var crossing_types: Dictionary = {}
	for crossing in data.crossings:
		var crossing_position := crossing.get("grid_position", Vector2i.ZERO) as Vector2i
		assert_eq(data.get_terrain_type_at(crossing_position), MapTileTypes.Terrain.RIVER)
		assert_true(data.has_road_at(crossing_position))
		crossing_types[str(crossing.get("crossing_type", ""))] = true
	assert_true(crossing_types.has("bridge"), "过河点必须包含桥梁")
	assert_true(crossing_types.has("ford"), "过河点必须包含浅滩")

	assert_eq(data.passes.size(), 1)
	var mountain_pass: Dictionary = data.passes[0]
	var pass_position := mountain_pass.get("grid_position", Vector2i.ZERO) as Vector2i
	assert_eq(data.get_zone_type_at(pass_position), MapTileTypes.Zone.MOUNTAIN)
	assert_eq(data.get_terrain_type_at(pass_position), MapTileTypes.Terrain.PLAIN, "关隘开口应被道路削平，但仍保留山地区域语义")
	assert_eq(data.get_road_type_at(pass_position), MapTileTypes.RoadType.MAIN)
	assert_eq(int(mountain_pass.get("opening_width", 0)), MapGenerationConfig.PASS_OPENING_WIDTH)


func test_all_road_types_are_smoothed_and_bridges_have_uvs() -> void:
	var data := _get_generated_map_data()
	var slope_sums := {
		MapTileTypes.RoadType.MAIN: 0.0,
		MapTileTypes.RoadType.NORMAL: 0.0,
		MapTileTypes.RoadType.RING: 0.0,
		MapTileTypes.RoadType.HIDDEN: 0.0,
	}
	var slope_counts := {
		MapTileTypes.RoadType.MAIN: 0,
		MapTileTypes.RoadType.NORMAL: 0,
		MapTileTypes.RoadType.RING: 0,
		MapTileTypes.RoadType.HIDDEN: 0,
	}
	var unselected_river_road_count := 0
	for tile_index in range(data.get_tile_count()):
		var grid_position := data.tile_index_to_grid(tile_index)
		var road_type := data.get_road_type_at(grid_position)
		if road_type == MapTileTypes.RoadType.NONE:
			continue
		if data.get_terrain_type_at(grid_position) == MapTileTypes.Terrain.RIVER:
			if data.get_crossing_type_at(grid_position).is_empty():
				unselected_river_road_count += 1
			continue
		slope_sums[road_type] = float(slope_sums[road_type]) + data.get_slope_at(grid_position)
		slope_counts[road_type] = int(slope_counts[road_type]) + 1
	for road_type in slope_counts:
		var sample_count := int(slope_counts[road_type])
		var average_slope := float(slope_sums[road_type]) / float(maxi(sample_count, 1))
		assert_gt(sample_count, 0, "每种道路都必须有可验证的陆地缓坡样本")
		assert_true(
			average_slope < MapGenerationConfig.MAX_ROAD_AVERAGE_SLOPE,
			"%s 必须使用连续缓坡处理，当前平均坡度 %.4f" % [
				MapTileTypes.get_road_display_name(int(road_type)),
				average_slope,
			]
		)
	assert_gt(unselected_river_road_count, 0, "低级道路允许被河流阻断")

	var expected_bridge_cell_count := 0
	for crossing in data.crossings:
		var direction := crossing.get("road_direction", Vector2.ZERO) as Vector2
		assert_true(direction.is_normalized(), "过河点必须保存桥面贴图朝向")
		assert_true(crossing.has("model_scene_path"), "过河点必须预留正式模型场景路径")
		if str(crossing.get("crossing_type", "")) == "bridge":
			expected_bridge_cell_count += int(crossing.get("cell_count", 0))
			assert_eq(str(crossing.get("visual_mode", "")), "textured_deck_placeholder")
	var bridge_mesh := TerrainMeshBuilder.build_road_mesh(
		data,
		Rect2i(data.get_min_grid(), data.map_size),
		true,
		MapTileTypes.RoadType.NONE,
		"bridge"
	)
	assert_eq(bridge_mesh.get_surface_count(), 1, "桥梁贴图层必须生成独立网格")
	if bridge_mesh.get_surface_count() > 0:
		var arrays := bridge_mesh.surface_get_arrays(0)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var uvs := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
		assert_eq(vertices.size(), expected_bridge_cell_count * 4)
		assert_eq(uvs.size(), vertices.size(), "桥梁网格必须携带连续贴图 UV")


func _get_reachable_cells(cells: Dictionary, start: Vector2i) -> Dictionary:
	var reachable: Dictionary = {}
	if not cells.has(start):
		return reachable
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	reachable[start] = true
	var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		for direction in directions:
			var neighbor := current + direction
			if cells.has(neighbor) and not reachable.has(neighbor):
				reachable[neighbor] = true
				queue.append(neighbor)
	return reachable


func test_continuous_heightfield_and_chunk_seams() -> void:
	var data := _get_generated_map_data()
	assert_eq(
		data.height_samples.size(),
		(data.map_size.x + 1) * (data.map_size.y + 1),
		"高度场必须覆盖完整的 401×401 共享顶点网格"
	)
	assert_true(data.min_terrain_height < -0.5, "河床必须低于基础地表")
	assert_gt(data.max_terrain_height, 6.0, "山地必须形成可辨识的高程起伏")

	var bounds_a := Rect2i(Vector2i(-200, -200), data.chunk_size)
	var bounds_b := Rect2i(Vector2i(-190, -200), data.chunk_size)
	var mesh_a := TerrainMeshBuilder.build_ground_mesh(data, bounds_a)
	var mesh_b := TerrainMeshBuilder.build_ground_mesh(data, bounds_b)
	assert_gt(mesh_a.get_surface_count(), 0)
	assert_gt(mesh_b.get_surface_count(), 0)
	var vertices_a := mesh_a.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var vertices_b := mesh_b.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var vertex_width := data.chunk_size.x + 1
	for local_y in range(data.chunk_size.y + 1):
		var edge_a := vertices_a[local_y * vertex_width + data.chunk_size.x]
		var edge_b := vertices_b[local_y * vertex_width]
		assert_eq(edge_a.y, edge_b.y, "相邻 Chunk 必须复用同一条边界高度")
		var world_a := data.vertex_grid_to_world(bounds_a.position) + edge_a
		var world_b := data.vertex_grid_to_world(bounds_b.position) + edge_b
		assert_eq(world_a, world_b, "相邻 Chunk 的边界顶点必须在世界坐标中完全重合")


func test_mountain_and_river_distribution_is_coherent() -> void:
	var data := _get_generated_map_data()
	var mountain_count := 0
	var river_count := 0
	var river_cells: Dictionary = {}
	var river_water_min := INF
	var river_water_max := -INF
	var mountain_height_min := INF
	var mountain_height_max := -INF
	var bridge_count := 0
	var main_road_river_cells := 0
	var tributary_region_counts: Array[int] = [0, 0, 0, 0]
	var tributary_regions: Array[Rect2i] = [
		Rect2i(Vector2i(48, -140), Vector2i(48, 44)),
		Rect2i(Vector2i(120, -112), Vector2i(64, 48)),
		Rect2i(Vector2i(48, -32), Vector2i(48, 44)),
		Rect2i(Vector2i(120, 32), Vector2i(64, 52)),
	]
	for index in range(data.get_tile_count()):
		var grid_position := data.tile_index_to_grid(index)
		var terrain_type := data.get_terrain_type_at(grid_position)
		if terrain_type == MapTileTypes.Terrain.MOUNTAIN:
			mountain_count += 1
			mountain_height_min = minf(
				mountain_height_min,
				data.get_tile_height_at(grid_position)
			)
			mountain_height_max = maxf(
				mountain_height_max,
				data.get_tile_height_at(grid_position)
			)
		elif terrain_type == MapTileTypes.Terrain.RIVER:
			river_count += 1
			river_cells[grid_position] = true
			river_water_min = minf(
				river_water_min,
				data.get_tile_water_height_at(grid_position)
			)
			river_water_max = maxf(
				river_water_max,
				data.get_tile_water_height_at(grid_position)
			)
			if data.has_road_at(grid_position):
				bridge_count += 1
				assert_gt(
					data.get_tile_water_height_at(grid_position)
					- data.get_tile_height_at(grid_position),
					0.5,
					"桥下必须保留可见河床净空"
				)
			if data.get_road_type_at(grid_position) == MapTileTypes.RoadType.MAIN:
				main_road_river_cells += 1
				assert_false(
					data.get_crossing_at_grid(grid_position).is_empty(),
					"所有主干道与河流的交点都必须由桥梁覆盖"
				)
			for region_index in range(tributary_regions.size()):
				if tributary_regions[region_index].has_point(grid_position):
					tributary_region_counts[region_index] += 1

	assert_gt(mountain_count, 2000, "山脉需要形成连续且有规模的山地区域")
	assert_gt(mountain_height_max - mountain_height_min, 4.0, "山脉内部需要有明显高低层次")
	assert_gt(river_count, 800, "河流需要形成可见的主河道与支流")
	assert_gt(bridge_count, 0, "主干道跨河处必须被识别为桥梁")
	assert_gt(main_road_river_cells, 0, "湿地主干道必须与主河道形成受控交点")
	for tributary_index in range(tributary_region_counts.size()):
		assert_gt(
			tributary_region_counts[tributary_index],
			12,
			"湿地区支流 %d 必须形成可读河段，当前格数 %d" % [
				tributary_index + 1,
				tributary_region_counts[tributary_index],
			]
		)
	assert_gt(river_water_max - river_water_min, 0.2, "河面需要具有从上游到下游的缓坡")

	var largest_river_component := _get_largest_component_size(river_cells)
	assert_gt(
		float(largest_river_component) / float(maxi(river_count, 1)),
		0.9,
		"主河道与支流必须保持连通，不能散落成噪声斑点"
	)
	var wetland := MapGenerationConfig.WETLAND_ZONE_RECT
	var touches_upstream := false
	var touches_downstream := false
	for grid_variant in river_cells:
		var grid_position := grid_variant as Vector2i
		if (
			grid_position.y
			<= wetland.position.y + ceili(MapGenerationConfig.ZONE_BOUNDARY_VARIATION) + 2
		):
			touches_upstream = true
		if (
			grid_position.y
			>= wetland.end.y - ceili(MapGenerationConfig.ZONE_BOUNDARY_VARIATION) - 3
		):
			touches_downstream = true
	assert_true(touches_upstream, "主河道必须进入扰动后的湿地区域上游边缘")
	assert_true(touches_downstream, "主河道必须离开扰动后的湿地区域下游边缘")


func test_zone_boundaries_are_naturally_irregular() -> void:
	var data := _get_generated_map_data()
	var zone_samples := [
		{
			"name": "森林区",
			"rect": MapGenerationConfig.FOREST_ZONE_RECT,
			"zone": MapTileTypes.Zone.FOREST,
		},
		{
			"name": "山地区",
			"rect": MapGenerationConfig.MOUNTAIN_ZONE_RECT,
			"zone": MapTileTypes.Zone.MOUNTAIN,
		},
		{
			"name": "湿地区",
			"rect": MapGenerationConfig.WETLAND_ZONE_RECT,
			"zone": MapTileTypes.Zone.WETLAND,
		},
	]
	for sample in zone_samples:
		var rect := sample.get("rect") as Rect2i
		var zone_type := int(sample.get("zone", MapTileTypes.Zone.NEUTRAL))
		var left_span := _get_zone_left_boundary_span(data, rect, zone_type)
		var top_span := _get_zone_top_boundary_span(data, rect, zone_type)
		assert_gt(
			left_span,
			4,
			"%s 左侧边界不能保持直线" % str(sample.get("name", "区域"))
		)
		assert_gt(
			top_span,
			4,
			"%s 上侧边界不能保持直线" % str(sample.get("name", "区域"))
		)

	var central_radii := PackedInt32Array()
	for angle_index in range(32):
		var angle := TAU * float(angle_index) / 32.0
		var last_inside_radius := 0
		for radius in range(1, MapGenerationConfig.CENTRAL_ZONE_RADIUS + 16):
			var grid_position := Vector2i(
				roundi(cos(angle) * float(radius)),
				roundi(sin(angle) * float(radius))
			)
			if data.get_zone_type_at(grid_position) == MapTileTypes.Zone.CENTRAL:
				last_inside_radius = radius
		central_radii.append(last_inside_radius)
	assert_gt(
		_get_integer_span(central_radii),
		6,
		"中央区边界不能保持规则圆形"
	)


func _get_zone_left_boundary_span(
	data: DemoMapData,
	rect: Rect2i,
	zone_type: int
) -> int:
	var positions := PackedInt32Array()
	var variation := ceili(MapGenerationConfig.ZONE_BOUNDARY_VARIATION) + 2
	for grid_y in range(rect.position.y + 12, rect.end.y - 12, 4):
		for grid_x in range(rect.position.x - variation, rect.position.x + variation + 1):
			if data.get_zone_type_at(Vector2i(grid_x, grid_y)) == zone_type:
				positions.append(grid_x)
				break
	return _get_integer_span(positions)


func _get_zone_top_boundary_span(
	data: DemoMapData,
	rect: Rect2i,
	zone_type: int
) -> int:
	var positions := PackedInt32Array()
	var variation := ceili(MapGenerationConfig.ZONE_BOUNDARY_VARIATION) + 2
	for grid_x in range(rect.position.x + 12, rect.end.x - 12, 4):
		for grid_y in range(rect.position.y - variation, rect.position.y + variation + 1):
			if data.get_zone_type_at(Vector2i(grid_x, grid_y)) == zone_type:
				positions.append(grid_y)
				break
	return _get_integer_span(positions)


func _get_integer_span(values: PackedInt32Array) -> int:
	if values.is_empty():
		return 0
	var minimum := values[0]
	var maximum := values[0]
	for value in values:
		minimum = mini(minimum, value)
		maximum = maxi(maximum, value)
	return maximum - minimum


func _get_largest_component_size(cells: Dictionary) -> int:
	var unvisited := cells.duplicate()
	var largest := 0
	var directions: Array[Vector2i] = [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN,
	]
	while not unvisited.is_empty():
		var start := unvisited.keys()[0] as Vector2i
		unvisited.erase(start)
		var queue: Array[Vector2i] = [start]
		var cursor := 0
		while cursor < queue.size():
			var current := queue[cursor]
			cursor += 1
			for direction in directions:
				var neighbor := current + direction
				if unvisited.erase(neighbor):
					queue.append(neighbor)
		largest = maxi(largest, queue.size())
	return largest


func test_map_world_scene_has_stable_mount_structure() -> void:
	var packed := load("res://map/map_world.tscn") as PackedScene
	assert_true(packed != null, "地图主场景应可加载")
	if packed == null:
		return
	var world := track(packed.instantiate()) as Node
	assert_true(world is Node3D)
	assert_true(world.has_node("MapController"))
	assert_true(world.has_node("CameraRig/Camera3D"))
	assert_true(world.has_node("ChunkRoot"))
	assert_true(world.has_node("EntityRoot"))
	assert_true(world.has_node("SelectionRoot"))


func test_camera_supports_management_and_battle_modes() -> void:
	var camera_rig := track(MapCameraRig.new()) as MapCameraRig
	assert_eq(camera_rig.view_mode, MapCameraRig.ViewMode.MANAGEMENT_3D)
	assert_eq(camera_rig.perspective_distance, 150.0, "经营 3D 默认视距必须扩大")
	assert_eq(MapCameraRig.DEFAULT_ORTHO_SIZE, 60.0, "战争 2.5D 默认视野必须扩大")
	assert_eq(MapController.CHUNK_LOAD_RADIUS, 3, "扩大视野后必须加载三圈 Chunk")
	camera_rig.zoom_by_factor(100.0, Vector2(960.0, 540.0))
	assert_eq(camera_rig.perspective_distance, 35.0, "经营 3D 视距必须保持安全下限")

	var starting_yaw := camera_rig.yaw_radians
	var starting_pitch := camera_rig.pitch_degrees
	camera_rig.orbit_by_screen_delta(Vector2(120.0, 50.0))
	assert_ne(camera_rig.yaw_radians, starting_yaw, "水平拖动必须改变相机方位")
	assert_gt(camera_rig.pitch_degrees, starting_pitch, "向下拖动必须提高俯仰角")

	camera_rig.set_pitch_degrees(-100.0)
	assert_eq(camera_rig.pitch_degrees, 20.0, "经营视角俯仰下限必须保持安全")
	camera_rig.set_pitch_degrees(100.0)
	assert_eq(camera_rig.pitch_degrees, 75.0, "经营视角俯仰上限必须保持安全")

	camera_rig.set_view_mode(MapCameraRig.ViewMode.BATTLE_2_5D)
	assert_eq(camera_rig.view_mode, MapCameraRig.ViewMode.BATTLE_2_5D)
	assert_eq(
		camera_rig.pitch_degrees,
		MapCameraRig.DEFAULT_BATTLE_PITCH_DEGREES,
		"战争 2.5D 模式必须使用 45° 默认俯仰"
	)
	var battle_yaw := camera_rig.yaw_radians
	var battle_pitch := camera_rig.pitch_degrees
	camera_rig.orbit_by_screen_delta(Vector2(120.0, 50.0))
	assert_eq(camera_rig.yaw_radians, battle_yaw, "战争 2.5D 模式必须锁定旋转")
	assert_eq(camera_rig.pitch_degrees, battle_pitch, "战争 2.5D 模式必须锁定俯仰")
	camera_rig.zoom_by_factor(100.0, Vector2(960.0, 540.0))
	assert_eq(camera_rig.ortho_size, 18.0, "战争模式正交缩放必须保持安全下限")


func test_mouse_and_touch_input_can_orbit_camera() -> void:
	var camera_rig := track(MapCameraRig.new()) as MapCameraRig
	var map_world := track(MapWorld.new()) as MapWorld
	var input_controller := track(MapInputController.new()) as MapInputController
	input_controller.setup(camera_rig, map_world)

	var mouse_press := InputEventMouseButton.new()
	mouse_press.button_index = MOUSE_BUTTON_RIGHT
	mouse_press.pressed = true
	input_controller.handle_input(mouse_press, Vector2(960.0, 540.0), Vector2(960.0, 540.0))
	var mouse_motion := InputEventMouseMotion.new()
	mouse_motion.relative = Vector2(100.0, 40.0)
	input_controller.handle_input(mouse_motion, Vector2(960.0, 540.0), Vector2(960.0, 540.0))
	assert_ne(camera_rig.yaw_radians, 0.0, "右键水平拖动必须旋转相机")
	assert_gt(camera_rig.pitch_degrees, MapCameraRig.DEFAULT_PITCH_DEGREES, "右键向下拖动必须提高俯仰角")

	camera_rig.yaw_radians = 0.0
	camera_rig.pitch_degrees = MapCameraRig.DEFAULT_PITCH_DEGREES
	var first_touch := InputEventScreenTouch.new()
	first_touch.index = 0
	first_touch.position = Vector2(400.0, 300.0)
	first_touch.pressed = true
	input_controller.handle_input(first_touch, Vector2(960.0, 540.0), Vector2(960.0, 540.0))
	var second_touch := InputEventScreenTouch.new()
	second_touch.index = 1
	second_touch.position = Vector2(600.0, 300.0)
	second_touch.pressed = true
	input_controller.handle_input(second_touch, Vector2(960.0, 540.0), Vector2(960.0, 540.0))
	var first_drag := InputEventScreenDrag.new()
	first_drag.index = 0
	first_drag.position = Vector2(420.0, 320.0)
	first_drag.relative = Vector2(20.0, 20.0)
	input_controller.handle_input(first_drag, Vector2(960.0, 540.0), Vector2(960.0, 540.0))
	var second_drag := InputEventScreenDrag.new()
	second_drag.index = 1
	second_drag.position = Vector2(620.0, 320.0)
	second_drag.relative = Vector2(20.0, 20.0)
	input_controller.handle_input(second_drag, Vector2(960.0, 540.0), Vector2(960.0, 540.0))
	assert_ne(camera_rig.yaw_radians, 0.0, "双指整体水平拖动必须旋转相机")
	assert_gt(camera_rig.pitch_degrees, MapCameraRig.DEFAULT_PITCH_DEGREES, "双指向下拖动必须提高俯仰角")

	camera_rig.set_view_mode(MapCameraRig.ViewMode.BATTLE_2_5D)
	var locked_yaw := camera_rig.yaw_radians
	var locked_pitch := camera_rig.pitch_degrees
	input_controller.handle_input(mouse_press, Vector2(960.0, 540.0), Vector2(960.0, 540.0))
	input_controller.handle_input(mouse_motion, Vector2(960.0, 540.0), Vector2(960.0, 540.0))
	assert_eq(camera_rig.yaw_radians, locked_yaw, "战争模式鼠标输入不能绕过旋转锁定")
	assert_eq(camera_rig.pitch_degrees, locked_pitch, "战争模式鼠标输入不能绕过俯仰锁定")


func test_terrain_texture_materials_are_available() -> void:
	var grass_material_path := "res://map/materials/grass_ground_material.tres"
	var river_material_path := "res://map/materials/river_water_material.tres"
	assert_true(
		ResourceLoader.exists(grass_material_path, "Material"),
		"草地共享材质必须可用"
	)
	assert_true(
		ResourceLoader.exists(river_material_path, "Material"),
		"河流共享材质必须可用"
	)

	var grass_material := load(grass_material_path) as ShaderMaterial
	var river_material := load(river_material_path) as ShaderMaterial
	assert_true(grass_material != null, "草地材质必须能加载为 ShaderMaterial")
	assert_true(river_material != null, "河流材质必须能加载为 ShaderMaterial")
	if grass_material != null:
		assert_true(
			grass_material.get_shader_parameter("ground_texture") is Texture2D,
			"草地材质必须绑定纹理"
		)
	if river_material != null:
		assert_true(
			river_material.get_shader_parameter("water_texture") is Texture2D,
			"河流材质必须绑定纹理"
		)
