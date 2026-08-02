class_name DemoMapData
extends RefCounted

var map_size: Vector2i
var chunk_size: Vector2i
var cell_size: float
@warning_ignore("shadowed_global_identifier")
var seed: int
var tiles: Dictionary = {}
var cities: Array[MapCityData] = []
var passes: Array[Dictionary] = []

var _cities_by_grid: Dictionary = {}


func _init(
	p_map_size: Vector2i = Vector2i(200, 200),
	p_chunk_size: Vector2i = Vector2i(10, 10),
	p_cell_size: float = 2.0,
	p_seed: int = 0
) -> void:
	map_size = p_map_size
	chunk_size = p_chunk_size
	cell_size = p_cell_size
	seed = p_seed


func get_min_grid() -> Vector2i:
	return Vector2i(
		-floori(float(map_size.x) / 2.0),
		-floori(float(map_size.y) / 2.0)
	)


func get_max_grid() -> Vector2i:
	var min_grid := get_min_grid()
	return min_grid + map_size - Vector2i.ONE


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
	if tile != null and is_valid_grid(tile.grid_position):
		tiles[tile.grid_position] = tile


func get_tile(grid_position: Vector2i) -> MapTileData:
	return tiles.get(grid_position) as MapTileData


func add_city(city: MapCityData) -> void:
	if city == null:
		return
	cities.append(city)
	var occupied_rect := city.get_occupied_grid_rect()
	for grid_y in range(occupied_rect.position.y, occupied_rect.end.y):
		for grid_x in range(occupied_rect.position.x, occupied_rect.end.x):
			var occupied_grid := Vector2i(grid_x, grid_y)
			if is_valid_grid(occupied_grid):
				_cities_by_grid[occupied_grid] = city


func get_city_at_grid(grid_position: Vector2i) -> MapCityData:
	return _cities_by_grid.get(grid_position) as MapCityData


func get_world_half_extent() -> Vector2:
	return Vector2(
		float(map_size.x) * cell_size * 0.5,
		float(map_size.y) * cell_size * 0.5
	)
