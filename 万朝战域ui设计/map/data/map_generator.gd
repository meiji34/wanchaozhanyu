class_name DemoMapGenerator
extends RefCounted

const CITY_NAMES: PackedStringArray = [
	"洛阳", "长安", "许昌", "邺城",
	"成都", "汉中", "建业", "襄阳",
	"荆州", "寿春", "下邳", "北平",
]

const CITY_TEMPLATES: Array[Vector2i] = [
	Vector2i(-72, -58),
	Vector2i(-25, -72),
	Vector2i(32, -62),
	Vector2i(72, -45),
	Vector2i(-76, -2),
	Vector2i(-24, -16),
	Vector2i(30, -4),
	Vector2i(75, 8),
	Vector2i(-66, 55),
	Vector2i(-16, 66),
	Vector2i(38, 58),
	Vector2i(78, 70),
]

const ROAD_CONNECTIONS: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3),
	Vector2i(4, 5), Vector2i(5, 6), Vector2i(6, 7),
	Vector2i(8, 9), Vector2i(9, 10), Vector2i(10, 11),
	Vector2i(1, 5), Vector2i(5, 9),
	Vector2i(2, 6), Vector2i(6, 10),
]


static func generate(config: MapGenerationConfig) -> DemoMapData:
	var data := DemoMapData.new(
		config.map_size,
		config.chunk_size,
		config.cell_size,
		config.seed
	)
	var terrain_noise := FastNoiseLite.new()
	terrain_noise.seed = config.seed
	terrain_noise.frequency = 0.018
	var detail_noise := FastNoiseLite.new()
	detail_noise.seed = config.seed + 731
	detail_noise.frequency = 0.047

	var min_grid := data.get_min_grid()
	var max_grid := data.get_max_grid()
	for grid_y in range(min_grid.y, max_grid.y + 1):
		for grid_x in range(min_grid.x, max_grid.x + 1):
			var grid_position := Vector2i(grid_x, grid_y)
			var terrain := _choose_terrain(
				grid_position,
				terrain_noise.get_noise_2d(grid_x, grid_y),
				detail_noise.get_noise_2d(grid_x, grid_y),
				config.seed
			)
			var height := 0.0
			if terrain == MapTileTypes.Terrain.MOUNTAIN:
				height = 0.12 + absf(detail_noise.get_noise_2d(grid_x, grid_y)) * 0.18
			elif terrain == MapTileTypes.Terrain.RIVER:
				height = -0.04
			data.set_tile(MapTileData.new(grid_position, terrain, height))

	_generate_cities(data, config.city_count)
	_generate_roads(data)
	_generate_passes(data, config.pass_count)
	return data


static func _choose_terrain(
	grid_position: Vector2i,
	terrain_noise: float,
	detail_noise: float,
	seed: int
) -> int:
	var phase := float(seed % 97) * 0.01
	var river_center := roundi(
		sin(float(grid_position.x) * 0.046 + phase) * 13.0
		+ sin(float(grid_position.x) * 0.109 - phase) * 4.0
	)
	if absi(grid_position.y - river_center) <= 1:
		return MapTileTypes.Terrain.RIVER

	var north_ridge := roundi(-52.0 + float(grid_position.x) * 0.34 + terrain_noise * 8.0)
	var south_ridge := roundi(54.0 - float(grid_position.x) * 0.27 + detail_noise * 7.0)
	var on_ridge := (
		absi(grid_position.y - north_ridge) <= 3
		or absi(grid_position.y - south_ridge) <= 3
	)
	if on_ridge or (terrain_noise > 0.68 and detail_noise > 0.1):
		return MapTileTypes.Terrain.MOUNTAIN
	return MapTileTypes.Terrain.PLAIN


static func _generate_cities(data: DemoMapData, city_count: int) -> void:
	var count := mini(city_count, mini(CITY_NAMES.size(), CITY_TEMPLATES.size()))
	for index in range(count):
		var target := CITY_TEMPLATES[index]
		var position := _find_nearest_plain(data, target, 10)
		var city := MapCityData.new(
			"city_%02d" % (index + 1),
			CITY_NAMES[index],
			position,
			1 + index % 4
		)
		_flatten_city_site(data, city.get_occupied_grid_rect())
		data.add_city(city)


static func _find_nearest_plain(
	data: DemoMapData,
	target: Vector2i,
	max_radius: int
) -> Vector2i:
	for radius in range(max_radius + 1):
		for y_offset in range(-radius, radius + 1):
			for x_offset in range(-radius, radius + 1):
				if radius > 0 and absi(x_offset) != radius and absi(y_offset) != radius:
					continue
				var candidate := target + Vector2i(x_offset, y_offset)
				var tile := data.get_tile(candidate)
				if tile != null and tile.can_build_city:
					return candidate
	push_warning("城市落点未找到平原，使用模板坐标：%s" % target)
	return target


static func _flatten_city_site(data: DemoMapData, occupied_rect: Rect2i) -> void:
	for grid_y in range(occupied_rect.position.y, occupied_rect.end.y):
		for grid_x in range(occupied_rect.position.x, occupied_rect.end.x):
			var tile := data.get_tile(Vector2i(grid_x, grid_y))
			if tile == null:
				continue
			tile.terrain_type = MapTileTypes.Terrain.PLAIN
			tile.height = 0.0
			tile.can_build_city = true


static func _generate_roads(data: DemoMapData) -> void:
	for connection in ROAD_CONNECTIONS:
		if connection.x >= data.cities.size() or connection.y >= data.cities.size():
			continue
		var from_city := data.cities[connection.x] as MapCityData
		var to_city := data.cities[connection.y] as MapCityData
		_mark_road_line(data, from_city.grid_position, to_city.grid_position)


static func _mark_road_line(data: DemoMapData, from_grid: Vector2i, to_grid: Vector2i) -> void:
	var current := from_grid
	var delta := Vector2i(
		absi(to_grid.x - from_grid.x),
		-absi(to_grid.y - from_grid.y)
	)
	var step := Vector2i(
		1 if from_grid.x < to_grid.x else -1,
		1 if from_grid.y < to_grid.y else -1
	)
	var error := delta.x + delta.y
	while true:
		var tile := data.get_tile(current)
		if tile != null:
			tile.has_road = true
		if current == to_grid:
			break
		var doubled_error := error * 2
		if doubled_error >= delta.y:
			error += delta.y
			current.x += step.x
		if doubled_error <= delta.x:
			error += delta.x
			current.y += step.y


static func _generate_passes(data: DemoMapData, pass_count: int) -> void:
	var candidates: Array[Vector2i] = []
	for tile_variant in data.tiles.values():
		var tile := tile_variant as MapTileData
		if (
			tile != null
			and tile.has_road
			and tile.terrain_type == MapTileTypes.Terrain.MOUNTAIN
		):
			candidates.append(tile.grid_position)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(Vector2i.ZERO) < b.distance_squared_to(Vector2i.ZERO)
	)

	var chosen: Array[Vector2i] = []
	for candidate in candidates:
		var is_far_enough := true
		for previous in chosen:
			if candidate.distance_to(previous) < 12.0:
				is_far_enough = false
				break
		if not is_far_enough:
			continue
		chosen.append(candidate)
		if chosen.size() >= pass_count:
			break

	for index in range(chosen.size()):
		data.passes.append({
			"pass_id": "pass_%02d" % (index + 1),
			"display_name": "关隘 %d" % (index + 1),
			"grid_position": chosen[index],
		})
