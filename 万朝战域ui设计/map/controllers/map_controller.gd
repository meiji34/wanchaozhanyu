class_name MapController
extends Node

signal map_ready
signal chunk_stats_changed(active_count: int, cached_count: int, camera_chunk: Vector2i)
signal fog_changed  ## 迷雾数据变更，通知 UI 刷新统计

const CHUNK_SCENE := preload("res://map/chunks/map_chunk.tscn")
const CITY_SCENE := preload("res://map/entities/city_entity.tscn")
const PASS_SCENE := preload("res://map/entities/pass_entity.tscn")
const RESOURCE_POINT_SCENE := preload("res://map/entities/resource_point_entity.tscn")
const CHUNK_LOAD_RADIUS := 3        ## 最外层 LOD2 半径（预加载/隐藏）
const CHUNK_LOD0_RADIUS := 2        ## 近圈 LOD0（完整）半径
const CHUNK_LOD1_RADIUS := 3        ## 中圈 LOD1（精简，可见）半径
const CHUNKS_PER_FRAME := 3
const FOG_REBUILDS_PER_FRAME := 3   ## 每帧重建迷雾网格的 Chunk 数量
const MAX_CACHED_CHUNKS := 36
## 四座战略主城 ID，开局视野共享且始终显示模型（不受 Chunk 加载范围限制）
const STRATEGIC_CITY_IDS: PackedStringArray = [
	"forest_capital", "wetland_capital", "mountain_capital", "central_capital"
]

## 第三版 LOD/预加载开关（可通过调试面板控制）
var lod_enabled := true
var preload_enabled := true
var fog_enabled := true
var fog_mode_battle_clear := true   ## 战争阶段保持 UNKNOWN 遮蔽但去薄雾

var map_data: DemoMapData
var active_chunks: Dictionary = {}  ## {Vector2i: MapChunk}
var _cached_chunks: Array[MapChunk] = []
var _load_queue: Array[Dictionary] = []  ## [{coordinate, lod_level}]
var _fog_rebuild_queue: Array[Vector2i] = []  ## 分批重建迷雾的 Chunk 坐标队列
var _target_chunks: Dictionary = {}  ## {Vector2i: int(lod_level)}
var _city_entities: Dictionary = {}
var _pass_entities: Array[MapPassEntity] = []
var _resource_entities: Array[MapResourcePointEntity] = []
var _camera_rig: MapCameraRig
var _chunk_root: Node3D
var _entity_root: Node3D
var _current_camera_chunk := Vector2i(999999, 999999)
var _initial_load_completed := false
var _fog_dirty := false
var _fog_rebuild_pending := false       ## 是否还有待重建的迷雾网格


## ——— 调试面板可控参数 ———
## 开局揭示半径（格数），负数表示使用 FogData 默认值
var debug_initial_reveal_radius: int = -1

## 当前视野半径（格数），负数表示使用 FogData 默认值
var debug_vision_radius: int = -1

## 揭示格子按钮使用的视野半径（格数），独立于开局揭示半径，默认值为 10 格
var debug_reveal_at_cursor_radius: int = 10

## 战争模式下树木密度缩放系数（0=全隐藏，1=正常）
var battle_tree_density_scale: float = 0.3

## 当前迷雾渲染使用的阵营 ID（默认森林，可由调试面板/HUD 动态切换）
var current_fog_faction_id: int = DemoPlayerContext.FactionId.FOREST


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
	_init_fog_data()
	_camera_rig.configure_bounds(map_data.get_world_half_extent())
	var opening_city := map_data.get_city_by_id("forest_capital")
	if opening_city != null:
		_camera_rig.focus_world_position(map_data.grid_to_world(opening_city.grid_position))
	_spawn_entities()
	_refresh_target_chunks(true)
	set_process(true)


func _init_fog_data() -> void:
	print("[Fog] === _init_fog_data START ===")
	map_data.fog_data = FogData.new(map_data.map_size)
	print("[Fog] FogData created, tile_count=%d" % map_data.fog_data._tile_count)
	# 所有四座战略主城的开局视野对三个阵营共享
	_reveal_all_capitals_for_all_factions()
	# 为当前阵营设置初始可见区域
	var fog := map_data.fog_data
	var camera_grid := _camera_rig.get_target_grid(map_data)
	fog.update_visibility(camera_grid, fog.vision_radius, current_fog_faction_id)
	print("[Fog] city_count=%d fog_data=%s faction_id=%d" % [map_data.cities.size(), str(map_data.fog_data != null), current_fog_faction_id])
	# 标记迷雾已变更，确保后续 Chunk 加载和渲染能读取到正确的探索数据
	mark_fog_dirty()
	print("[Fog] Fog marked dirty after shared starting vision init. _fog_dirty=%s" % str(_fog_dirty))
	print("[Fog] === _init_fog_data END ===")
	print("[Fog] Initialized with shared starting vision for %d factions" % 3)


func reveal_initial_vision() -> void:
	## 公开接口：重新揭示所有阵营主城的开局视野（四座主城共享给三阵营）
	_reveal_all_capitals_for_all_factions()
	mark_fog_dirty()


## 将四座战略主城（森林、湿地、山地、中央）的开局视野写入全部三个阵营
func _reveal_all_capitals_for_all_factions() -> void:
	if map_data.fog_data == null:
		push_error("[Fog] _reveal_all_capitals_for_all_factions: fog_data 为空!")
		return
	var fog : FogData = map_data.fog_data
	var radius := fog.initial_reveal_radius
	if debug_initial_reveal_radius >= 0:
		radius = debug_initial_reveal_radius
	radius = clampi(radius, 1, 200)
	print("[START_VISION_RADIUS] value=%d (default=%d debug=%d)" % [radius, fog.initial_reveal_radius, debug_initial_reveal_radius])
	print("[START_VISION] radius=%d cities=%d factions=3" % [radius, STRATEGIC_CITY_IDS.size()])
	var city_found_count := 0
	for city_id: String in STRATEGIC_CITY_IDS:
		var city := map_data.get_city_by_id(city_id)
		if city == null:
			push_error("[START_VISION_CITY] 主城数据缺失: %s" % city_id)
			continue
		city_found_count += 1
		var cell_valid := map_data.is_valid_grid(city.grid_position)
		print("[START_VISION_CITY] city_id=%s cell=%s faction_id=%d cell_valid=%s map_cities_count=%d" % [city_id, city.grid_position, city.faction_id, "true" if cell_valid else "false", map_data.cities.size()])
	print("[START_VISION_CITIES] expected=%d actual=%d" % [STRATEGIC_CITY_IDS.size(), city_found_count])
	var faction_ids: Array[int] = [
		int(DemoPlayerContext.FactionId.FOREST),
		int(DemoPlayerContext.FactionId.WETLAND),
		int(DemoPlayerContext.FactionId.MOUNTAIN),
	]
	for faction_id: int in faction_ids:
		var before_total: int = fog.get_explored_count(faction_id)
		for city_id: String in STRATEGIC_CITY_IDS:
			var city := map_data.get_city_by_id(city_id)
			if city == null:
				continue
			fog.reveal_circle(city.grid_position, radius, faction_id)
			# 开局共享视野的语义是“当前可见”：必须同时写入 VISIBLE。
			# 此前只写 EXPLORED，导致画面可见但可见性查询为假（VISIBLE 本身即视为已探索）。
			# 三个阵营各自拥有独立 PackedByteArray（COW 写时复制），此处不存在视野串联。
			fog.update_visibility(city.grid_position, radius, faction_id)
		var after_total: int = fog.get_explored_count(faction_id)
		print("[START_VISION_RESULT] faction=%d before=%d after=%d (diff=%d)" % [faction_id, before_total, after_total, after_total - before_total])
		# COW 修复验证：直接检查四座主城周围关键格子是否已持久化
		if fog._fog_bytes_by_faction.has(faction_id):
			var persisted_bytes: PackedByteArray = fog._fog_bytes_by_faction[faction_id] as PackedByteArray
			var city_verified := 0
			var city_total := 0
			for city_id: String in STRATEGIC_CITY_IDS:
				var city := map_data.get_city_by_id(city_id)
				if city == null:
					continue
				city_total += 1
				var idx := fog._index(city.grid_position)
				if idx >= 0 and persisted_bytes[idx] != FogData.FogState.UNKNOWN:
					city_verified += 1
				else:
					push_error("[START_VISION_PERSIST] faction=%d city=%s at %s is STILL UNKNOWN in persisted bytes! idx=%d" % [faction_id, city_id, city.grid_position, idx])
			print("[START_VISION_PERSIST] faction=%d persisted_verified_cities=%d/%d (vs reported=%d)" % [faction_id, city_verified, city_total, after_total])
		else:
			push_error("[START_VISION_PERSIST] faction=%d 在 _fog_bytes_by_faction 中不存在!" % faction_id)
	print("[START_VISION] END")


func _reveal_around_cities() -> void:
	## 仅揭示当前阵营开局视野（保留向后兼容）
	_reveal_around_cities_for_faction(current_fog_faction_id)


func _reveal_around_cities_for_faction(faction_id: int) -> void:
	var fog := map_data.fog_data
	if fog == null:
		return
	var radius := fog.initial_reveal_radius
	if debug_initial_reveal_radius >= 0:
		radius = debug_initial_reveal_radius
	# 开局揭示该阵营对应主城周围
	var capital_id: StringName = _get_capital_id_for_faction(faction_id)
	if not capital_id.is_empty():
		var city := map_data.get_city_by_id(String(capital_id))
		if city != null:
			fog.reveal_circle(city.grid_position, radius, faction_id)
			print("[Fog] Revealed around city %s for faction %d" % [city.display_name, faction_id])


## 根据阵营 ID 获取主城 ID
func _get_capital_id_for_faction(faction_id: int) -> StringName:
	match faction_id:
		DemoPlayerContext.FactionId.FOREST:
			return &"forest_capital"
		DemoPlayerContext.FactionId.WETLAND:
			return &"wetland_capital"
		DemoPlayerContext.FactionId.MOUNTAIN:
			return &"mountain_capital"
		_:
			return &""


func _update_fog_visibility() -> void:
	var fog := map_data.fog_data
	if fog == null:
		return
	fog.reset_visibility(current_fog_faction_id)
	var radius := fog.vision_radius
	if debug_vision_radius >= 0:
		radius = debug_vision_radius
	var camera_grid := _camera_rig.get_target_grid(map_data)
	fog.update_visibility(camera_grid, radius, current_fog_faction_id)


func _process(_delta: float) -> void:
	if map_data == null or _camera_rig == null:
		return
	var camera_grid := _camera_rig.get_target_grid(map_data)
	var camera_chunk := map_data.grid_to_chunk(camera_grid)
	if camera_chunk != _current_camera_chunk:
		_refresh_target_chunks(false)
	for _index in range(mini(CHUNKS_PER_FRAME, _load_queue.size())):
		_load_next_chunk()

	# 迷雾数据变更时：不再基于摄像机位置更新 VISIBLE 状态，仅重建迷雾网格
	# 摄像机移动不会改变任何格子的迷雾状态，迷雾揭示仅通过 reveal_area() 公开接口
	if fog_enabled and _fog_dirty:
		_fog_dirty = false
		# 同步阵营 ID 到所有活跃 Chunk
		for chunk_variant in active_chunks.values():
			var chunk := chunk_variant as MapChunk
			if chunk != null:
				chunk.fog_faction_id = current_fog_faction_id
		# 将所有活跃 Chunk 加入迷雾重建队列（去重）
		_fog_rebuild_queue.clear()
		for coord_variant in active_chunks.keys():
			var coord := coord_variant as Vector2i
			if not _fog_rebuild_queue.has(coord):
				_fog_rebuild_queue.append(coord)
		_fog_rebuild_pending = not _fog_rebuild_queue.is_empty()
		_update_entity_visibility()
		var fog_explored := 0
		if map_data.fog_data != null:
			fog_explored = map_data.fog_data.get_explored_count(current_fog_faction_id)
		print("[FOG_REFRESH] faction=%d explored_count=%d rebuild_queue=%d renderer=MapChunk._build_fog_overlay" % [current_fog_faction_id, fog_explored, _fog_rebuild_queue.size()])
		fog_changed.emit()

	# 分批重建迷雾网格（每帧处理有限数量）
	if _fog_rebuild_pending:
		for _rebuild_idx in range(mini(FOG_REBUILDS_PER_FRAME, _fog_rebuild_queue.size())):
			if _fog_rebuild_queue.is_empty():
				break
			var coord: Vector2i = _fog_rebuild_queue.pop_front()
			var chunk := active_chunks.get(coord) as MapChunk
			if chunk != null and is_instance_valid(chunk):
				chunk.rebuild_fog()
		if _fog_rebuild_queue.is_empty():
			_fog_rebuild_pending = false

	if not _initial_load_completed and _load_queue.is_empty():
		_initial_load_completed = true
		print("[Init] === All chunks loaded, active_chunks=%d ===" % active_chunks.size())
		# 初始 Chunk 全部加载完成，触发首次迷雾和实体同步
		_fog_dirty = true
		_update_entity_visibility()
		map_ready.emit()
		print("[Init] === map_ready emitted ===")


func get_city_at_grid(grid_position: Vector2i) -> MapCityData:
	return map_data.get_city_at_grid(grid_position) if map_data != null else null


func get_city_by_id(city_id: String) -> MapCityData:
	return map_data.get_city_by_id(city_id) if map_data != null else null


func get_resource_at_grid(grid_position: Vector2i) -> MapResourcePointData:
	return map_data.get_resource_at_grid(grid_position) if map_data != null else null


func get_resource_by_id(resource_id: String) -> MapResourcePointData:
	return map_data.get_resource_by_id(resource_id) if map_data != null else null


func set_selected_city(city_id: String) -> void:
	for key in _city_entities:
		var entity := _city_entities[key] as MapCityEntity
		if entity != null:
			entity.set_selected(str(key) == city_id)


func get_debug_snapshot() -> Dictionary:
	var snapshot := {
		"seed": map_data.seed if map_data != null else 0,
		"map_size": map_data.map_size if map_data != null else Vector2i.ZERO,
		"city_count": map_data.cities.size() if map_data != null else 0,
		"resource_count": map_data.resource_points.size() if map_data != null else 0,
		"iron_count": (
			map_data.get_resources_by_type(MapResourcePointData.ResourceType.IRON).size()
			if map_data != null else 0
		),
		"iron_positions": _get_iron_debug_positions(),
		"pass_count": map_data.passes.size() if map_data != null else 0,
		"crossing_count": map_data.crossings.size() if map_data != null else 0,
		"road_connection_count": map_data.road_connections.size() if map_data != null else 0,
		"min_terrain_height": map_data.min_terrain_height if map_data != null else 0.0,
		"max_terrain_height": map_data.max_terrain_height if map_data != null else 0.0,
		"compact_tile_storage_bytes": (
			map_data.get_compact_tile_storage_bytes() if map_data != null else 0
		),
		"active_chunk_count": active_chunks.size(),
		"cached_chunk_count": _cached_chunks.size(),
		"queued_chunk_count": _load_queue.size(),
		"camera_chunk": _current_camera_chunk,
	}
	_fill_fog_snapshot(snapshot)
	_fill_lod_snapshot(snapshot)
	return snapshot


func _fill_fog_snapshot(snapshot: Dictionary) -> void:
	var fog := map_data.fog_data if map_data != null else null
	snapshot["fog_enabled"] = fog_enabled
	snapshot["fog_explored"] = fog.get_explored_count() if fog != null else 0
	snapshot["fog_visible"] = fog.get_visible_count() if fog != null else 0
	snapshot["fog_unknown"] = fog.get_unknown_count() if fog != null else 0
	snapshot["fog_explored_ratio"] = (
		"%.1f%%" % (fog.get_explored_ratio() * 100.0) if fog != null else "0%"
	)
	snapshot["fog_mode_battle_clear"] = fog_mode_battle_clear


func _fill_lod_snapshot(snapshot: Dictionary) -> void:
	snapshot["lod_enabled"] = lod_enabled
	snapshot["preload_enabled"] = preload_enabled
	var lod0_count := 0
	var lod1_count := 0
	var lod2_count := 0
	for chunk_variant in active_chunks.values():
		var chunk := chunk_variant as MapChunk
		if chunk != null:
			match chunk.lod_level:
				MapChunk.LODLevel.LOD0:
					lod0_count += 1
				MapChunk.LODLevel.LOD1:
					lod1_count += 1
				MapChunk.LODLevel.LOD2:
					lod2_count += 1
	snapshot["lod0_chunks"] = lod0_count
	snapshot["lod1_chunks"] = lod1_count
	snapshot["lod2_chunks"] = lod2_count


## ——— 迷雾公开 API ———

func mark_fog_dirty() -> void:
	_fog_dirty = true


## 验证三阵营视野数据隔离：每个阵营的已探索格子数应独立统计
func verify_vision_isolation() -> void:
	if map_data == null or map_data.fog_data == null:
		print("[VISION_ISOLATION] fog_data is null, cannot verify")
		return
	var fog := map_data.fog_data
	var faction_ids: Array[int] = [
		int(DemoPlayerContext.FactionId.FOREST),
		int(DemoPlayerContext.FactionId.WETLAND),
		int(DemoPlayerContext.FactionId.MOUNTAIN),
	]
	print("[VISION_ISOLATION] === Verifying faction vision isolation ===")
	for faction_id: int in faction_ids:
		var count: int = fog.get_explored_count(faction_id)
		print("[VISION_ISOLATION] faction=%d (%s) explored_count=%d" % [
			faction_id, DemoPlayerContext.get_faction_name_by_id(faction_id), count
		])
	# 验证：每个阵营应有独立的 PackedByteArray 实例
	for i in range(faction_ids.size()):
		for j in range(i + 1, faction_ids.size()):
			var id_a: int = faction_ids[i]
			var id_b: int = faction_ids[j]
			var bytes_a: PackedByteArray = fog._get_faction_bytes(id_a)
			var bytes_b: PackedByteArray = fog._get_faction_bytes(id_b)
			# PackedByteArray 是值类型，不同 key 的实例不应共享同一引用
			if bytes_a == bytes_b and id_a != id_b:
				print("[VISION_ISOLATION] WARNING: faction %d and %d share the same data reference!" % [id_a, id_b])
	print("[VISION_ISOLATION] === Verification complete ===")


func reveal_area(center_grid: Vector2i, radius: int, p_faction_id: int = -2) -> void:
	## 揭示指定区域迷雾。-2 表示使用当前迷雾阵营 ID。
	## “揭示”的语义是把区域真正揭示给当前阵营（当前可见）：必须同时写入
	## EXPLORED 与 VISIBLE，仅写 EXPLORED 会导致画面可见但可见性查询为假。
	## 只写入指定阵营自己的数据（COW 独立数组），不影响其他阵营。
	var fog := map_data.fog_data if map_data != null else null
	if fog == null:
		return
	var faction_id: int = current_fog_faction_id if p_faction_id == -2 else p_faction_id
	var before_count: int = fog.get_explored_count(faction_id)
	var before_visible: int = fog.get_visible_count(faction_id)
	fog.reveal_circle(center_grid, radius, faction_id)
	fog.update_visibility(center_grid, radius, faction_id)
	var after_count: int = fog.get_explored_count(faction_id)
	print("[REVEAL_BUTTON] faction=%d cell=%s radius=%d explored=%d→%d visible=%d→%d" % [
		faction_id, center_grid, radius, before_count, after_count, before_visible, fog.get_visible_count(faction_id)
	])
	# 将所有活跃 Chunk 的 fog_faction_id 同步为当前值
	for chunk_variant in active_chunks.values():
		var chunk := chunk_variant as MapChunk
		if chunk != null:
			chunk.fog_faction_id = current_fog_faction_id
	# 将所有活跃 Chunk 排入迷雾重建队列（分批处理）
	_fog_rebuild_queue.clear()
	for coord_variant in active_chunks.keys():
		_fog_rebuild_queue.append(coord_variant as Vector2i)
	_fog_rebuild_pending = not _fog_rebuild_queue.is_empty()
	_update_entity_visibility()
	fog_changed.emit()


func set_fog_enabled(p_enabled: bool) -> void:
	if fog_enabled == p_enabled:
		return
	fog_enabled = p_enabled
	print("[Fog] Fog %s" % ("enabled" if p_enabled else "disabled"))
	if not fog_enabled:
		_hide_all_fog()
	else:
		# 将所有活跃 Chunk 排入迷雾重建队列
		_fog_rebuild_queue.clear()
		for coord_variant in active_chunks.keys():
			_fog_rebuild_queue.append(coord_variant as Vector2i)
		_fog_rebuild_pending = not _fog_rebuild_queue.is_empty()
		fog_changed.emit()
	_update_entity_visibility()


func set_lod_enabled(p_enabled: bool) -> void:
	lod_enabled = p_enabled


func set_preload_enabled(p_enabled: bool) -> void:
	preload_enabled = p_enabled


func set_battle_tree_density_scale(scale: float) -> void:
	battle_tree_density_scale = clampf(scale, 0.0, 1.0)


func get_fog_debug_snapshot() -> Dictionary:
	var fog := map_data.fog_data if map_data != null else null
	if fog == null:
		return {}
	return {
		"enabled": fog_enabled,
		"explored": fog.get_explored_count(),
		"visible": fog.get_visible_count(),
		"unknown": fog.get_unknown_count(),
		"ratio": fog.get_explored_ratio(),
		"vision_radius": fog.vision_radius if debug_vision_radius < 0 else debug_vision_radius,
		"initial_reveal_radius": (
			fog.initial_reveal_radius if debug_initial_reveal_radius < 0 else debug_initial_reveal_radius
		),
	}


func get_lod_debug_snapshot() -> Dictionary:
	return {
		"enabled": lod_enabled,
		"preload_enabled": preload_enabled,
		"lod0_chunks": _count_chunks_at_lod(MapChunk.LODLevel.LOD0),
		"lod1_chunks": _count_chunks_at_lod(MapChunk.LODLevel.LOD1),
		"lod2_chunks": _count_chunks_at_lod(MapChunk.LODLevel.LOD2),
	}


func _count_chunks_at_lod(level: MapChunk.LODLevel) -> int:
	var count := 0
	for chunk_variant in active_chunks.values():
		var chunk := chunk_variant as MapChunk
		if chunk != null and chunk.lod_level == level:
			count += 1
	return count


func set_visible_area(center_grid: Vector2i, radius: int) -> void:
	## 仅设置当前 VISIBLE 范围（不清除持久 EXPLORED 状态）
	var fog := map_data.fog_data if map_data != null else null
	if fog == null:
		return
	fog.reset_visibility(current_fog_faction_id)
	fog.update_visibility(center_grid, radius, current_fog_faction_id)
	_fog_rebuild_queue.clear()
	for coord_variant in active_chunks.keys():
		_fog_rebuild_queue.append(coord_variant as Vector2i)
	_fog_rebuild_pending = not _fog_rebuild_queue.is_empty()
	fog_changed.emit()


func _hide_all_fog() -> void:
	for chunk_variant in active_chunks.values():
		var chunk := chunk_variant as MapChunk
		if chunk != null:
			var fog_node := chunk.get_node_or_null("FogOverlay")
			if fog_node != null:
				fog_node.visible = false


func _get_iron_debug_positions() -> Array[String]:
	var positions: Array[String] = []
	if map_data == null:
		return positions
	for resource_point in map_data.get_resources_by_type(MapResourcePointData.ResourceType.IRON):
		positions.append("%s:%s" % [resource_point.resource_id, resource_point.grid_position])
	return positions


func _refresh_target_chunks(force: bool) -> void:
	var camera_grid := _camera_rig.get_target_grid(map_data)
	var camera_chunk := map_data.grid_to_chunk(camera_grid)
	if not force and camera_chunk == _current_camera_chunk:
		return
	_current_camera_chunk = camera_chunk
	# 摄像机移动不再自动触发迷雾更新；迷雾揭示仅通过 reveal_area() 公开接口调用
	_target_chunks.clear()
	var min_chunk := map_data.grid_to_chunk(map_data.get_min_grid())
	var max_chunk := map_data.grid_to_chunk(map_data.get_max_grid())
	var load_radius := CHUNK_LOAD_RADIUS if lod_enabled and preload_enabled else CHUNK_LOD1_RADIUS
	for offset_y in range(-load_radius, load_radius + 1):
		for offset_x in range(-load_radius, load_radius + 1):
			var coordinate := camera_chunk + Vector2i(offset_x, offset_y)
			if (
				coordinate.x < min_chunk.x
				or coordinate.x > max_chunk.x
				or coordinate.y < min_chunk.y
				or coordinate.y > max_chunk.y
			):
				continue
			var lod := _compute_lod_level(camera_chunk, coordinate)
			_target_chunks[coordinate] = lod

	# 缓存离开范围的 Chunk（无 LOD 升级可能的）
	for coordinate_variant in active_chunks.keys():
		var coordinate := coordinate_variant as Vector2i
		if not _target_chunks.has(coordinate):
			_cache_chunk(coordinate)

	# 对已活跃的 Chunk 检查是否需要 LOD 升级/降级
	for coordinate_variant in active_chunks.keys():
		var coordinate := coordinate_variant as Vector2i
		var target_lod: int = _target_chunks.get(coordinate, -1)
		var existing := active_chunks[coordinate] as MapChunk
		if existing == null or target_lod < 0:
			continue
		# LOD 数值降级（更精细）：缓存后重新加载
		if existing.lod_level > target_lod:
			_cache_chunk(coordinate)
		# 降级到 LOD2（隐藏）：取消显示
		elif target_lod == MapChunk.LODLevel.LOD2:
			existing.deactivate()
		# LOD2 升级为可见：缓存后重新加载（经 configure 设为 ACTIVE）
		elif existing.lod_level == MapChunk.LODLevel.LOD2 and target_lod <= MapChunk.LODLevel.LOD1:
			_cache_chunk(coordinate)

	var camera_dist := camera_chunk

	_load_queue.clear()
	for coordinate_variant in _target_chunks.keys():
		var coordinate := coordinate_variant as Vector2i
		if active_chunks.has(coordinate):
			continue
		_load_queue.append({
			"coordinate": coordinate,
			"lod_level": _target_chunks[coordinate],
			"dist": camera_dist.distance_squared_to(coordinate),
		})
	_load_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["dist"]) < float(b["dist"])
	)
	_update_entity_visibility()
	_emit_chunk_stats()


func _compute_lod_level(camera_chunk: Vector2i, coordinate: Vector2i) -> MapChunk.LODLevel:
	if not lod_enabled:
		return MapChunk.LODLevel.LOD0
	var dx := absi(coordinate.x - camera_chunk.x)
	var dy := absi(coordinate.y - camera_chunk.y)
	var ring := maxi(dx, dy)
	if ring <= CHUNK_LOD0_RADIUS:
		return MapChunk.LODLevel.LOD0
	if ring <= CHUNK_LOD1_RADIUS:
		return MapChunk.LODLevel.LOD1
	return MapChunk.LODLevel.LOD2


func _load_next_chunk() -> void:
	if _load_queue.is_empty():
		return
	var entry: Dictionary = _load_queue.pop_front()
	var coordinate: Vector2i = entry["coordinate"]
	var lod: int = entry.get("lod_level", int(MapChunk.LODLevel.LOD0))
	if active_chunks.has(coordinate):
		return
	var chunk: MapChunk
	if _cached_chunks.is_empty():
		chunk = CHUNK_SCENE.instantiate() as MapChunk
	else:
		chunk = _cached_chunks.pop_back()
	chunk.fog_faction_id = current_fog_faction_id  # 必须在 configure 之前设置，因为 _build_visuals 中会读取
	chunk.configure(map_data, coordinate, lod)  # configure 内部根据 LOD 设置 visible
	if chunk.get_parent() != _chunk_root:
		_chunk_root.add_child(chunk)
	active_chunks[coordinate] = chunk
	_emit_chunk_stats()


func _cache_chunk(coordinate: Vector2i) -> void:
	var chunk := active_chunks.get(coordinate) as MapChunk
	active_chunks.erase(coordinate)
	if chunk == null:
		return
	chunk.deactivate()
	chunk.lod_level = int(MapChunk.LODLevel.LOD0)  # 重置默认
	_cached_chunks.append(chunk)
	while _cached_chunks.size() > MAX_CACHED_CHUNKS:
		var expired: MapChunk = _cached_chunks.pop_front()
		if expired != null:
			expired.queue_free()


func _spawn_entities() -> void:
	print("[Spawn] Spawning %d cities..." % map_data.cities.size())
	for city in map_data.cities:
		var entity := CITY_SCENE.instantiate() as MapCityEntity
		entity.configure(city, map_data)
		_entity_root.add_child(entity)
		_city_entities[city.city_id] = entity
		print("[Spawn] City %s at grid=%s added to tree" % [city.city_id, city.grid_position])
		print("[CITY_MODEL] city_id=%s cell=%s world_position=%s inside_tree=%s visible=%s scale=%s faction_id=%d" % [
			city.city_id,
			city.grid_position,
			entity.global_position,
			entity.is_inside_tree(),
			entity.visible,
			entity.scale,
			city.faction_id,
		])
	print("[CITY_MODEL_RESULT] expected=%d spawned=%d" % [map_data.cities.size(), _city_entities.size()])
	for pass_data in map_data.passes:
		var pass_entity := PASS_SCENE.instantiate() as MapPassEntity
		_entity_root.add_child(pass_entity)
		pass_entity.configure(pass_data, map_data)
		_pass_entities.append(pass_entity)
	for resource_point in map_data.resource_points:
		var resource_entity := RESOURCE_POINT_SCENE.instantiate() as MapResourcePointEntity
		resource_entity.configure(resource_point, map_data)
		_entity_root.add_child(resource_entity)
		_resource_entities.append(resource_entity)
	_update_entity_visibility()


func _update_entity_visibility() -> void:
	if map_data == null:
		print("[EntityVis] map_data 为空，跳过")
		return
	var fog := map_data.fog_data if fog_enabled else null
	var spawned_count: int = _city_entities.size()
	var visible_count: int = 0
	for city_id in _city_entities:
		var city := map_data.get_city_by_id(str(city_id))
		var entity := _city_entities[city_id] as MapCityEntity
		if city != null and entity != null:
			var city_id_str: String = str(city_id)
			var is_strategic := city_id_str in STRATEGIC_CITY_IDS
			var in_chunk := _target_chunks.has(map_data.grid_to_chunk(city.grid_position)) or is_strategic
			var not_unknown := fog == null or not fog.is_unknown(city.grid_position, current_fog_faction_id)
			entity.visible = in_chunk and not_unknown
			if entity.visible:
				visible_count += 1
			if is_strategic and not entity.visible:
				print("[EntityVis] 【战略主城】%s 被隐藏！ in_chunk=%s explored=%s parent=%s pos=%s inside_tree=%s" % [
					city_id_str, _target_chunks.has(map_data.grid_to_chunk(city.grid_position)),
					not_unknown, entity.get_parent().name if entity.get_parent() != null else "null",
					entity.global_position, entity.is_inside_tree()
				])
			print("[EntityVis] %s grid=%s in_chunk=%s explored=%s visible=%s strategic=%s" % [
				city_id, city.grid_position, in_chunk, not_unknown, entity.visible, is_strategic
			])
	print("[EntityVis] cities=%d visible=%d fog_enabled=%s faction=%d target_chunks=%d" % [
		spawned_count, visible_count, fog_enabled, current_fog_faction_id, _target_chunks.size()
	])
	for pass_entity in _pass_entities:
		if pass_entity != null:
			var grid_pos := pass_entity.grid_position
			var in_chunk := _target_chunks.has(map_data.grid_to_chunk(grid_pos))
			var not_unknown := fog == null or not fog.is_unknown(grid_pos, current_fog_faction_id)
			pass_entity.visible = in_chunk and not_unknown
	for resource_entity in _resource_entities:
		if resource_entity != null:
			var grid_pos := resource_entity.grid_position
			var in_chunk := _target_chunks.has(map_data.grid_to_chunk(grid_pos))
			var not_unknown := fog == null or not fog.is_unknown(grid_pos, current_fog_faction_id)
			resource_entity.visible = in_chunk and not_unknown


func _emit_chunk_stats() -> void:
	chunk_stats_changed.emit(
		active_chunks.size(),
		_cached_chunks.size(),
		_current_camera_chunk
	)
