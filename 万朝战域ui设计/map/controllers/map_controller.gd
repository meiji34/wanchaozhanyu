class_name MapController
extends Node

signal map_ready
signal chunk_stats_changed(active_count: int, cached_count: int, camera_chunk: Vector2i)

const CHUNK_SCENE := preload("res://map/chunks/map_chunk.tscn")
const CITY_SCENE := preload("res://map/entities/city_entity.tscn")
const PASS_SCENE := preload("res://map/entities/pass_entity.tscn")
const CHUNK_LOAD_RADIUS := 2
const CHUNKS_PER_FRAME := 3
const MAX_CACHED_CHUNKS := 36

var map_data: DemoMapData
var active_chunks: Dictionary = {}
var _cached_chunks: Array[MapChunk] = []
var _load_queue: Array[Vector2i] = []
var _target_chunks: Dictionary = {}
var _city_entities: Dictionary = {}
var _pass_entities: Array[MapPassEntity] = []
var _camera_rig: MapCameraRig
var _chunk_root: Node3D
var _entity_root: Node3D
var _current_camera_chunk := Vector2i(999999, 999999)
var _initial_load_completed := false


func initialize(
	camera_rig: MapCameraRig,
	chunk_root: Node3D,
	entity_root: Node3D
) -> void:
	_camera_rig = camera_rig
	_chunk_root = chunk_root
	_entity_root = entity_root
	var config := MapGenerationConfig.new()
	map_data = DemoMapGenerator.generate(config)
	_camera_rig.configure_bounds(map_data.get_world_half_extent())
	if map_data.cities.size() > 5:
		var opening_city := map_data.cities[5] as MapCityData
		_camera_rig.focus_world_position(map_data.grid_to_world(opening_city.grid_position))
	_spawn_entities()
	_refresh_target_chunks(true)
	set_process(true)


func _process(_delta: float) -> void:
	if map_data == null or _camera_rig == null:
		return
	var camera_grid := _camera_rig.get_target_grid(map_data)
	var camera_chunk := map_data.grid_to_chunk(camera_grid)
	if camera_chunk != _current_camera_chunk:
		_refresh_target_chunks(false)
	for index in range(mini(CHUNKS_PER_FRAME, _load_queue.size())):
		_load_next_chunk()
	if not _initial_load_completed and _load_queue.is_empty():
		_initial_load_completed = true
		map_ready.emit()


func get_city_at_grid(grid_position: Vector2i) -> MapCityData:
	return map_data.get_city_at_grid(grid_position) if map_data != null else null


func set_selected_city(city_id: String) -> void:
	for key in _city_entities:
		var entity := _city_entities[key] as MapCityEntity
		if entity != null:
			entity.set_selected(str(key) == city_id)


func get_debug_snapshot() -> Dictionary:
	return {
		"seed": map_data.seed if map_data != null else 0,
		"map_size": map_data.map_size if map_data != null else Vector2i.ZERO,
		"city_count": map_data.cities.size() if map_data != null else 0,
		"pass_count": map_data.passes.size() if map_data != null else 0,
		"active_chunk_count": active_chunks.size(),
		"cached_chunk_count": _cached_chunks.size(),
		"queued_chunk_count": _load_queue.size(),
		"camera_chunk": _current_camera_chunk,
	}


func _refresh_target_chunks(force: bool) -> void:
	var camera_grid := _camera_rig.get_target_grid(map_data)
	var camera_chunk := map_data.grid_to_chunk(camera_grid)
	if not force and camera_chunk == _current_camera_chunk:
		return
	_current_camera_chunk = camera_chunk
	_target_chunks.clear()
	var min_chunk := map_data.grid_to_chunk(map_data.get_min_grid())
	var max_chunk := map_data.grid_to_chunk(map_data.get_max_grid())
	for offset_y in range(-CHUNK_LOAD_RADIUS, CHUNK_LOAD_RADIUS + 1):
		for offset_x in range(-CHUNK_LOAD_RADIUS, CHUNK_LOAD_RADIUS + 1):
			var coordinate := camera_chunk + Vector2i(offset_x, offset_y)
			if (
				coordinate.x < min_chunk.x
				or coordinate.x > max_chunk.x
				or coordinate.y < min_chunk.y
				or coordinate.y > max_chunk.y
			):
				continue
			_target_chunks[coordinate] = true

	for coordinate_variant in active_chunks.keys():
		var coordinate := coordinate_variant as Vector2i
		if not _target_chunks.has(coordinate):
			_cache_chunk(coordinate)

	_load_queue.clear()
	for coordinate_variant in _target_chunks.keys():
		var coordinate := coordinate_variant as Vector2i
		if not active_chunks.has(coordinate):
			_load_queue.append(coordinate)
	_load_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(camera_chunk) < b.distance_squared_to(camera_chunk)
	)
	_update_entity_visibility()
	_emit_chunk_stats()


func _load_next_chunk() -> void:
	if _load_queue.is_empty():
		return
	var coordinate: Vector2i = _load_queue.pop_front()
	if active_chunks.has(coordinate):
		return
	var chunk: MapChunk
	if _cached_chunks.is_empty():
		chunk = CHUNK_SCENE.instantiate() as MapChunk
	else:
		chunk = _cached_chunks.pop_back()
	chunk.visible = true
	chunk.configure(map_data, coordinate)
	if chunk.get_parent() != _chunk_root:
		_chunk_root.add_child(chunk)
	active_chunks[coordinate] = chunk
	_emit_chunk_stats()


func _cache_chunk(coordinate: Vector2i) -> void:
	var chunk := active_chunks.get(coordinate) as MapChunk
	active_chunks.erase(coordinate)
	if chunk == null:
		return
	chunk.visible = false
	_cached_chunks.append(chunk)
	while _cached_chunks.size() > MAX_CACHED_CHUNKS:
		var expired: MapChunk = _cached_chunks.pop_front()
		if expired != null:
			expired.queue_free()


func _spawn_entities() -> void:
	for city in map_data.cities:
		var entity := CITY_SCENE.instantiate() as MapCityEntity
		entity.configure(city, map_data)
		_entity_root.add_child(entity)
		_city_entities[city.city_id] = entity
	for pass_data in map_data.passes:
		var pass_entity := PASS_SCENE.instantiate() as MapPassEntity
		_entity_root.add_child(pass_entity)
		pass_entity.configure(pass_data, map_data)
		_pass_entities.append(pass_entity)
	_update_entity_visibility()


func _update_entity_visibility() -> void:
	if map_data == null:
		return
	for city_id in _city_entities:
		var city := map_data.cities.filter(
			func(candidate: MapCityData) -> bool:
				return candidate.city_id == str(city_id)
		).front() as MapCityData
		var entity := _city_entities[city_id] as MapCityEntity
		if city != null and entity != null:
			entity.visible = _target_chunks.has(map_data.grid_to_chunk(city.grid_position))
	for pass_entity in _pass_entities:
		if pass_entity != null:
			pass_entity.visible = _target_chunks.has(
				map_data.grid_to_chunk(pass_entity.grid_position)
			)


func _emit_chunk_stats() -> void:
	chunk_stats_changed.emit(
		active_chunks.size(),
		_cached_chunks.size(),
		_current_camera_chunk
	)
