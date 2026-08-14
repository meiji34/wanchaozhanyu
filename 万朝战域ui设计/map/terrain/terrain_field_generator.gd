class_name TerrainFieldGenerator
extends RefCounted

const BOUNDARY_WARP_X_SALT := 401
const BOUNDARY_WARP_Y_SALT := 503


static func generate_height_samples(data: DemoMapData, config: MapGenerationConfig) -> void:
	var min_vertex := data.get_min_vertex_grid()
	var max_vertex := data.get_max_vertex_grid()
	var sample_size := data.map_size + Vector2i.ONE
	# 使用 Noise.get_image() 在原生层批量生成，避免 GDScript 对 40 多万次噪声查询。
	var macro_image := _create_noise_image(
		config.seed + 101,
		0.008,
		sample_size,
		min_vertex
	)
	var detail_image := _create_noise_image(
		config.seed + 307,
		0.045,
		sample_size,
		min_vertex
	)
	var ridge_image := _create_noise_image(
		config.seed + 911,
		0.022,
		sample_size,
		min_vertex
	)
	for vertex_y in range(min_vertex.y, max_vertex.y + 1):
		for vertex_x in range(min_vertex.x, max_vertex.x + 1):
			var vertex_grid := Vector2i(vertex_x, vertex_y)
			var image_position := vertex_grid - min_vertex
			var sample_position := Vector2(
				float(vertex_x) - 0.5,
				float(vertex_y) - 0.5
			)
			var warped_zone_position := _warp_zone_point(sample_position, config.seed)
			var height := _sample_land_height(
				sample_position,
				macro_image.get_pixelv(image_position).r * 2.0 - 1.0,
				detail_image.get_pixelv(image_position).r * 2.0 - 1.0,
				ridge_image.get_pixelv(image_position).r * 2.0 - 1.0,
				config.seed,
				warped_zone_position
			)
			var river_mask := _get_river_mask_with_warped_point(
				sample_position,
				warped_zone_position,
				config.seed
			)
			var water_height := get_river_water_height(sample_position, config.seed)
			if river_mask > 0.0:
				var depth := lerpf(
					MapGenerationConfig.RIVER_DEPTH_MIN,
					MapGenerationConfig.RIVER_DEPTH_MAX,
					river_mask
				)
				var riverbed_height := minf(height, water_height - depth)
				height = lerpf(height, riverbed_height, river_mask)
			data.set_height_sample(vertex_grid, height)
			data.set_water_height_sample(vertex_grid, water_height)
	data.recalculate_height_range()


static func populate_tiles(data: DemoMapData, config: MapGenerationConfig) -> void:
	var min_grid := data.get_min_grid()
	var max_grid := data.get_max_grid()
	for grid_y in range(min_grid.y, max_grid.y + 1):
		for grid_x in range(min_grid.x, max_grid.x + 1):
			var grid_position := Vector2i(grid_x, grid_y)
			var sample_position := Vector2(grid_position)
			var warped_zone_position := _warp_zone_point(sample_position, config.seed)
			var zone_type := _get_zone_type_from_points(
				sample_position,
				warped_zone_position,
				config.seed
			)
			var river_mask := _get_river_mask_with_warped_point(
				sample_position,
				warped_zone_position,
				config.seed
			)
			var terrain_type := MapTileTypes.Terrain.PLAIN
			if river_mask >= 0.58:
				terrain_type = MapTileTypes.Terrain.RIVER
			elif (
				zone_type == MapTileTypes.Zone.MOUNTAIN
				and _get_mountain_mask_with_warped_point(
					sample_position,
					warped_zone_position,
					config.seed
				) >= 0.42
			):
				terrain_type = MapTileTypes.Terrain.MOUNTAIN
			var forest_density := 0.0
			if zone_type == MapTileTypes.Zone.FOREST:
				var density_noise := (
					sin(float(grid_x) * 0.71 + float(config.seed % 101)) * 0.55
					+ sin(float(grid_y) * 1.13 - float(config.seed % 67)) * 0.45
				)
				forest_density = clampf(0.62 + density_noise * 0.28, 0.28, 0.9)
			data.set_tile_base_data(
				grid_position,
				terrain_type,
				zone_type,
				river_mask,
				get_river_water_height(sample_position, config.seed),
				forest_density
			)
	refresh_tile_surface_data(data)


static func terrace_city_site(
	data: DemoMapData,
	center: Vector2i,
	footprint_size: Vector2i,
	blend_radius: int
) -> void:
	# 计算占地内所有格的平均高度作为平台目标高度
	var half_footprint := Vector2i(
		floori(float(footprint_size.x) * 0.5),
		floori(float(footprint_size.y) * 0.5)
	)
	var height_sum := 0.0
	var sample_count := 0
	for gy in range(center.y - half_footprint.y, center.y + half_footprint.y + 1):
		for gx in range(center.x - half_footprint.x, center.x + half_footprint.x + 1):
			if not data.is_valid_grid(Vector2i(gx, gy)):
				continue
			height_sum += data.get_height_at_grid(Vector2i(gx, gy))
			sample_count += 1
	var target_height := height_sum / maxf(1.0, float(sample_count))

	var half_extent := Vector2(footprint_size) * 0.5
	var radius := int(ceil(maxf(half_extent.x, half_extent.y))) + blend_radius + 1
	for vertex_y in range(center.y - radius, center.y + radius + 1):
		for vertex_x in range(center.x - radius, center.x + radius + 1):
			var vertex_grid := Vector2i(vertex_x, vertex_y)
			var sample_position := Vector2(vertex_grid) - Vector2(0.5, 0.5)
			var distance_from_platform := maxf(
				absf(sample_position.x - float(center.x)) - half_extent.x,
				absf(sample_position.y - float(center.y)) - half_extent.y
			)
			var influence := 1.0 - smoothstep(
				0.0,
				float(blend_radius),
				maxf(0.0, distance_from_platform)
			)
			if influence <= 0.0:
				continue
			var original := data.get_height_sample(vertex_grid)
			data.set_height_sample(vertex_grid, lerpf(original, target_height, influence))


static func smooth_road_corridor(
	data: DemoMapData,
	from_grid: Vector2i,
	to_grid: Vector2i,
	width: int
) -> void:
	var from_position := Vector2(from_grid)
	var to_position := Vector2(to_grid)
	var segment := to_position - from_position
	var length_squared := maxf(segment.length_squared(), 0.001)
	var half_width := float(width) * 0.5
	var margin := MapGenerationConfig.ROAD_HEIGHT_BLEND_MARGIN
	var min_x := floori(minf(from_position.x, to_position.x) - half_width - margin - 1.0)
	var max_x := ceili(maxf(from_position.x, to_position.x) + half_width + margin + 1.0)
	var min_y := floori(minf(from_position.y, to_position.y) - half_width - margin - 1.0)
	var max_y := ceili(maxf(from_position.y, to_position.y) + half_width + margin + 1.0)
	# 城池整平直接修改高度场；道路端点必须读取最新高度样本，不能依赖稍后才刷新的 Tile 缓存。
	var from_world := data.grid_to_world(from_grid)
	var to_world := data.grid_to_world(to_grid)
	var from_height := data.get_height_at_world(from_world.x, from_world.z)
	var to_height := data.get_height_at_world(to_world.x, to_world.z)
	for vertex_y in range(min_y, max_y + 1):
		for vertex_x in range(min_x, max_x + 1):
			var vertex_grid := Vector2i(vertex_x, vertex_y)
			var sample_position := Vector2(vertex_grid) - Vector2(0.5, 0.5)
			var t := clampf(
				(sample_position - from_position).dot(segment) / length_squared,
				0.0,
				1.0
			)
			var closest := from_position + segment * t
			var distance_to_road := sample_position.distance_to(closest)
			var influence := 1.0 - smoothstep(
				half_width,
				half_width + margin,
				distance_to_road
			)
			# 道路可以削平山坡，但不能把桥下河床抬到河面；河岸处渐隐可避免新的断层。
			var river_mask := get_river_mask(sample_position, data.seed)
			influence *= 1.0 - smoothstep(0.15, 0.58, river_mask)
			if influence <= 0.0:
				continue
			var road_height := lerpf(from_height, to_height, t)
			var original := data.get_height_sample(vertex_grid)
			data.set_height_sample(
				vertex_grid,
				lerpf(original, road_height, influence * 0.88)
			)


static func refresh_tile_surface_data(data: DemoMapData) -> void:
	data.recalculate_height_range()
	var vertex_width := data.map_size.x + 1
	# 格子中心位于四个高度顶点之间，直接取均值可替代 16 万次双线性查询。
	for local_y in range(data.map_size.y):
		var tile_row := local_y * data.map_size.x
		var vertex_row := local_y * vertex_width
		for local_x in range(data.map_size.x):
			var tile_index := tile_row + local_x
			var vertex_index := vertex_row + local_x
			data.tile_heights[tile_index] = (
				data.height_samples[vertex_index]
				+ data.height_samples[vertex_index + 1]
				+ data.height_samples[vertex_index + vertex_width]
				+ data.height_samples[vertex_index + vertex_width + 1]
			) * 0.25

	# 第二阶段在紧凑格子高度数组上计算中心差分，边界使用就近格子。
	for local_y in range(data.map_size.y):
		var tile_row := local_y * data.map_size.x
		var back_row := maxi(local_y - 1, 0) * data.map_size.x
		var front_row := mini(local_y + 1, data.map_size.y - 1) * data.map_size.x
		for local_x in range(data.map_size.x):
			var index := tile_row + local_x
			var left_index := tile_row + maxi(local_x - 1, 0)
			var right_index := tile_row + mini(local_x + 1, data.map_size.x - 1)
			var back_index := back_row + local_x
			var front_index := front_row + local_x
			var slope_x := (
				data.tile_heights[right_index] - data.tile_heights[left_index]
			) / (data.cell_size * 2.0)
			var slope_z := (
				data.tile_heights[front_index] - data.tile_heights[back_index]
			) / (data.cell_size * 2.0)
			data.tile_slopes[index] = Vector2(slope_x, slope_z).length()
			if data.road_types[index] != MapTileTypes.RoadType.NONE:
				data.forest_densities[index] = 0.0
				if data.terrain_types[index] == MapTileTypes.Terrain.MOUNTAIN:
					data.terrain_types[index] = MapTileTypes.Terrain.PLAIN
			# 可建造标记使用与局部刷新（refresh_tile_surface_at）完全一致的规则：
			# 只排除水面；山地不再作为施工限制，由建造校验按真实高度动态判定
			data.buildable_flags[index] = 1 if DemoMapData.is_buildable_tile_state(
				int(data.terrain_types[index])
			) else 0


static func get_zone_type(
	grid_position: Vector2i,
	generation_seed: int = MapGenerationConfig.DEFAULT_SEED
) -> int:
	var original_point := Vector2(grid_position)
	return _get_zone_type_from_points(
		original_point,
		_warp_zone_point(original_point, generation_seed),
		generation_seed
	)


static func _get_zone_type_from_points(
	original_point: Vector2,
	warped_point: Vector2,
	generation_seed: int
) -> int:
	if _central_inner_weight(original_point, generation_seed, 0.0) > 0.0:
		return MapTileTypes.Zone.CENTRAL
	if _rect_inner_weight_at_warped_point(
		warped_point,
		MapGenerationConfig.FOREST_ZONE_RECT,
		0.0
	) > 0.0:
		return MapTileTypes.Zone.FOREST
	if _rect_inner_weight_at_warped_point(
		warped_point,
		MapGenerationConfig.MOUNTAIN_ZONE_RECT,
		0.0
	) > 0.0:
		return MapTileTypes.Zone.MOUNTAIN
	if _rect_inner_weight_at_warped_point(
		warped_point,
		MapGenerationConfig.WETLAND_ZONE_RECT,
		0.0
	) > 0.0:
		return MapTileTypes.Zone.WETLAND
	return MapTileTypes.Zone.NEUTRAL


static func get_mountain_mask(sample_position: Vector2, generation_seed: int) -> float:
	return _get_mountain_mask_with_warped_point(
		sample_position,
		_warp_zone_point(sample_position, generation_seed),
		generation_seed
	)


static func _get_mountain_mask_with_warped_point(
	sample_position: Vector2,
	warped_zone_position: Vector2,
	generation_seed: int
) -> float:
	var zone_weight := _rect_inner_weight_at_warped_point(
		warped_zone_position,
		MapGenerationConfig.MOUNTAIN_ZONE_RECT,
		8.0
	)
	if zone_weight <= 0.0:
		return 0.0
	var phase := float(generation_seed % 97) * 0.013
	var ridge_center := (
		88.0
		+ sin((sample_position.x + 116.0) * 0.04 + phase) * 18.0
		+ sin(sample_position.x * 0.013 - phase) * 8.0
	)
	var ridge_distance := absf(sample_position.y - ridge_center)
	var ridge_band := 1.0 - smoothstep(10.0, 36.0, ridge_distance)
	return clampf(zone_weight * ridge_band, 0.0, 1.0)


static func get_river_mask(sample_position: Vector2, generation_seed: int) -> float:
	return _get_river_mask_with_warped_point(
		sample_position,
		_warp_zone_point(sample_position, generation_seed),
		generation_seed
	)


static func _get_river_mask_with_warped_point(
	sample_position: Vector2,
	warped_zone_position: Vector2,
	generation_seed: int
) -> float:
	if _rect_inner_weight_at_warped_point(
		warped_zone_position,
		MapGenerationConfig.WETLAND_ZONE_RECT,
		0.0
	) <= 0.0:
		return 0.0
	var main_x := _get_main_river_x(sample_position.y, generation_seed)
	var main_distance := absf(sample_position.x - main_x)
	var main_mask := 1.0 - smoothstep(
		MapGenerationConfig.RIVER_HALF_WIDTH,
		MapGenerationConfig.RIVER_HALF_WIDTH + MapGenerationConfig.RIVER_BANK_WIDTH,
		main_distance
	)
	# 四条有限长度支流从湿地边缘汇入主河道。它们避开 y=0 主干道走廊，
	# 但可以切过普通道路、环路或隐藏小径，形成有意义的次级通行阻隔。
	var tributary_distance := minf(
		_get_tributary_distance(sample_position, Vector2(44.0, -142.0), -92.0, 8.0, generation_seed),
		_get_tributary_distance(sample_position, Vector2(190.0, -118.0), -54.0, -7.0, generation_seed)
	)
	tributary_distance = minf(
		tributary_distance,
		_get_tributary_distance(sample_position, Vector2(44.0, -34.0), 18.0, 6.0, generation_seed)
	)
	tributary_distance = minf(
		tributary_distance,
		_get_tributary_distance(sample_position, Vector2(190.0, 24.0), 80.0, -6.0, generation_seed)
	)
	var tributary_mask := 1.0 - smoothstep(
		MapGenerationConfig.TRIBUTARY_HALF_WIDTH,
		MapGenerationConfig.TRIBUTARY_HALF_WIDTH + MapGenerationConfig.TRIBUTARY_BANK_WIDTH,
		tributary_distance
	)
	return maxf(main_mask, tributary_mask)


static func get_river_water_height(sample_position: Vector2, _generation_seed: int) -> float:
	var downstream_t := clampf((sample_position.y + 156.0) / 312.0, 0.0, 1.0)
	return lerpf(0.32, -0.04, downstream_t)


static func _get_tributary_distance(
	sample_position: Vector2,
	source: Vector2,
	join_y: float,
	curve_amplitude: float,
	generation_seed: int
) -> float:
	var join_x := _get_main_river_x(join_y, generation_seed)
	var min_x := minf(source.x, join_x)
	var max_x := maxf(source.x, join_x)
	if sample_position.x < min_x or sample_position.x > max_x:
		return INF
	var span := maxf(absf(join_x - source.x), 0.001)
	var progress := clampf(absf(sample_position.x - source.x) / span, 0.0, 1.0)
	var phase := float(generation_seed % 41) * 0.031
	var center_y := (
		lerpf(source.y, join_y, progress)
		+ sin(progress * PI) * curve_amplitude
		+ sin(sample_position.x * 0.055 + phase) * 1.8 * sin(progress * PI)
	)
	return absf(sample_position.y - center_y)


static func _get_main_river_x(sample_y: float, generation_seed: int) -> float:
	var phase := float(generation_seed % 53) * 0.02
	return 108.0 + sin(sample_y * 0.035 + phase) * 12.0


static func _sample_land_height(
	sample_position: Vector2,
	macro_value: float,
	detail_value: float,
	ridge_value: float,
	generation_seed: int,
	warped_zone_position: Vector2
) -> float:
	var plain_height := (
		(macro_value + 1.0) * 0.5 * MapGenerationConfig.PLAIN_HEIGHT_AMPLITUDE
		+ detail_value * 0.04
	)
	var forest_height := (
		(macro_value + 1.0) * 0.5 * MapGenerationConfig.FOREST_HEIGHT_AMPLITUDE
		+ detail_value * 0.12
	)
	var forest_weight := _rect_inner_weight_at_warped_point(
		warped_zone_position,
		MapGenerationConfig.FOREST_ZONE_RECT,
		12.0
	)
	var height := lerpf(plain_height, forest_height, forest_weight)
	var wetland_weight := _rect_inner_weight_at_warped_point(
		warped_zone_position,
		MapGenerationConfig.WETLAND_ZONE_RECT,
		10.0
	)
	var wetland_height := (macro_value + 1.0) * 0.16 + detail_value * 0.035
	height = lerpf(height, wetland_height, wetland_weight)
	var mountain_mask := _get_mountain_mask_with_warped_point(
		sample_position,
		warped_zone_position,
		generation_seed
	)
	if mountain_mask > 0.0:
		var ridged := pow(maxf(0.0, 1.0 - absf(ridge_value)), 2.2)
		var mountain_height := lerpf(
			MapGenerationConfig.MOUNTAIN_MIN_HEIGHT,
			MapGenerationConfig.MOUNTAIN_MAX_HEIGHT,
			clampf(ridged * 0.82 + (macro_value + 1.0) * 0.09, 0.0, 1.0)
		)
		height = lerpf(height, mountain_height, mountain_mask)
	var central_weight := _central_inner_weight(
		sample_position,
		generation_seed,
		float(MapGenerationConfig.CENTRAL_ZONE_RADIUS) * 0.55
	)
	return lerpf(height, 0.16, central_weight)


static func _create_noise_image(
	noise_seed: int,
	frequency: float,
	image_size: Vector2i,
	min_vertex: Vector2i
) -> Image:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = frequency
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5
	noise.offset = Vector3(float(min_vertex.x) - 0.5, float(min_vertex.y) - 0.5, 0.0)
	return noise.get_image(image_size.x, image_size.y, false, false, true)


static func _rect_inner_weight_at_warped_point(
	warped_point: Vector2,
	rect: Rect2i,
	blend_width: float
) -> float:
	var max_point := Vector2(rect.end - Vector2i.ONE)
	var edge_distance := minf(
		minf(
			warped_point.x - float(rect.position.x),
			max_point.x - warped_point.x
		),
		minf(
			warped_point.y - float(rect.position.y),
			max_point.y - warped_point.y
		)
	)
	if edge_distance < 0.0:
		return 0.0
	if blend_width <= 0.0:
		return 1.0
	return smoothstep(0.0, blend_width, edge_distance)


static func _warp_zone_point(point: Vector2, generation_seed: int) -> Vector2:
	var amplitude := MapGenerationConfig.ZONE_BOUNDARY_VARIATION
	return point + Vector2(
		_boundary_noise_1d(point.y, generation_seed, BOUNDARY_WARP_X_SALT) * amplitude,
		_boundary_noise_1d(point.x, generation_seed, BOUNDARY_WARP_Y_SALT) * amplitude
	)


static func _central_inner_weight(
	point: Vector2,
	generation_seed: int,
	blend_width: float
) -> float:
	var angle := atan2(point.y, point.x)
	var phase := float(generation_seed % 97) * 0.031
	var radius := (
		float(MapGenerationConfig.CENTRAL_ZONE_RADIUS)
		+ sin(angle * 3.0 + phase) * MapGenerationConfig.CENTRAL_BOUNDARY_VARIATION * 0.65
		+ sin(angle * 7.0 - phase) * MapGenerationConfig.CENTRAL_BOUNDARY_VARIATION * 0.35
	)
	var edge_distance := radius - point.length()
	if edge_distance < 0.0:
		return 0.0
	if blend_width <= 0.0:
		return 1.0
	return smoothstep(0.0, blend_width, edge_distance)


static func _boundary_noise_1d(value: float, generation_seed: int, salt: int) -> float:
	var scaled := value / MapGenerationConfig.ZONE_BOUNDARY_CELL_SIZE
	var lower_cell := floori(scaled)
	var fraction := smoothstep(0.0, 1.0, scaled - float(lower_cell))
	return lerpf(
		_boundary_hash(lower_cell, generation_seed, salt),
		_boundary_hash(lower_cell + 1, generation_seed, salt),
		fraction
	)


static func _boundary_hash(coordinate: int, generation_seed: int, salt: int) -> float:
	var value := (
		coordinate * 73856093
		^ generation_seed * 19349663
		^ salt * 83492791
	)
	return float(absi(value) % 10000) / 4999.5 - 1.0
