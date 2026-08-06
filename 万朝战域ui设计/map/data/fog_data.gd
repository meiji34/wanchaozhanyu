class_name FogData
extends RefCounted

## 探索状态：紧凑 PackedByteArray，不为全图格子创建常驻对象。
## 支持按阵营独立存储探索数据（每个阵营一份 PackedByteArray）。
enum FogState {
	UNKNOWN  = 0,  ## 未探索，完全遮蔽
	EXPLORED = 1,  ## 已探索但不在当前视野，降低亮度/饱和度显示
	VISIBLE  = 2,  ## 当前帧可见（瞬时状态，每帧重置）
}

var map_size: Vector2i
var min_grid: Vector2i
## 按阵营 ID 存储的迷雾数据字典（int → PackedByteArray，懒加载）
var _fog_bytes_by_faction: Dictionary = {}
var _tile_count: int

## 开局揭示的配置化半径（直接输入格子范围或通过玩法层配置覆盖）
var initial_reveal_radius: int = 32

## 当前视野半径（编辑器中可调，需移动端实测确定）
var vision_radius: int = 28


func _init(p_map_size: Vector2i) -> void:
	map_size = p_map_size
	min_grid = Vector2i(
		-floori(float(map_size.x) / 2.0),
		-floori(float(map_size.y) / 2.0)
	)
	_tile_count = map_size.x * map_size.y


## 获取（或懒创建）指定阵营的迷雾字节数组
func _get_faction_bytes(faction_id: int) -> PackedByteArray:
	if not _fog_bytes_by_faction.has(faction_id):
		var new_bytes: PackedByteArray = PackedByteArray()
		new_bytes.resize(_tile_count)
		new_bytes.fill(FogState.UNKNOWN)
		_fog_bytes_by_faction[faction_id] = new_bytes
	return _fog_bytes_by_faction[faction_id] as PackedByteArray


## ——— 紧凑数组读写 ———

func _index(grid_position: Vector2i) -> int:
	var local := grid_position - min_grid
	if local.x < 0 or local.y < 0 or local.x >= map_size.x or local.y >= map_size.y:
		return -1
	return local.y * map_size.x + local.x


func is_unknown(grid_position: Vector2i, faction_id: int = DemoPlayerContext.FactionId.FOREST) -> bool:
	var bytes: PackedByteArray = _get_faction_bytes(faction_id)
	var idx := _index(grid_position)
	return idx >= 0 and bytes[idx] == FogState.UNKNOWN


func is_explored(grid_position: Vector2i, faction_id: int = DemoPlayerContext.FactionId.FOREST) -> bool:
	var bytes: PackedByteArray = _get_faction_bytes(faction_id)
	var idx := _index(grid_position)
	return idx >= 0 and bytes[idx] == FogState.EXPLORED


func is_visible(grid_position: Vector2i, faction_id: int = DemoPlayerContext.FactionId.FOREST) -> bool:
	var bytes: PackedByteArray = _get_faction_bytes(faction_id)
	var idx := _index(grid_position)
	return idx >= 0 and bytes[idx] == FogState.VISIBLE


func is_revealed(grid_position: Vector2i, faction_id: int = DemoPlayerContext.FactionId.FOREST) -> bool:
	## 曾经被揭示（永久状态，UNKNOWN 的反面）
	var bytes: PackedByteArray = _get_faction_bytes(faction_id)
	var idx := _index(grid_position)
	return idx >= 0 and bytes[idx] != FogState.UNKNOWN


func get_state(grid_position: Vector2i, faction_id: int = DemoPlayerContext.FactionId.FOREST) -> int:
	var bytes: PackedByteArray = _get_faction_bytes(faction_id)
	var idx := _index(grid_position)
	return int(bytes[idx]) if idx >= 0 else int(FogState.UNKNOWN)


## ——— 揭示操作 ———

func reveal_circle(center_grid: Vector2i, radius: int, faction_id: int = DemoPlayerContext.FactionId.FOREST) -> void:
	## 将圆形区域标记为 EXPLORED（持久），仅影响指定阵营
	var bytes: PackedByteArray = _get_faction_bytes(faction_id)
	var max_grid_val := min_grid + map_size - Vector2i.ONE
	var r2 := radius * radius
	for dy in range(-radius, radius + 1):
		var dx_limit := int(sqrt(maxf(0.0, float(r2 - dy * dy))))
		for dx in range(-dx_limit, dx_limit + 1):
			var pos := center_grid + Vector2i(dx, dy)
			if (
				pos.x >= min_grid.x and pos.x <= max_grid_val.x
				and pos.y >= min_grid.y and pos.y <= max_grid_val.y
			):
				var idx := _index(pos)
				if idx >= 0 and bytes[idx] == FogState.UNKNOWN:
					bytes[idx] = FogState.EXPLORED
	# PackedByteArray 使用 COW 语义，必须写回字典才能持久化
	_fog_bytes_by_faction[faction_id] = bytes
	_mark_faction_stats_dirty(faction_id)


func reveal_all(faction_id: int = DemoPlayerContext.FactionId.FOREST) -> void:
	## 调试用：揭示全图（仅指定阵营）
	var bytes: PackedByteArray = _get_faction_bytes(faction_id)
	bytes.fill(FogState.EXPLORED)
	# PackedByteArray 使用 COW 语义，必须写回字典才能持久化
	_fog_bytes_by_faction[faction_id] = bytes
	_mark_faction_stats_dirty(faction_id)


func reset_all(faction_id: int = DemoPlayerContext.FactionId.FOREST) -> void:
	var bytes: PackedByteArray = _get_faction_bytes(faction_id)
	bytes.fill(FogState.UNKNOWN)
	# PackedByteArray 使用 COW 语义，必须写回字典才能持久化
	_fog_bytes_by_faction[faction_id] = bytes
	_mark_faction_stats_dirty(faction_id)


func reset_visibility(faction_id: int = DemoPlayerContext.FactionId.FOREST) -> void:
	## 将所有 VISIBLE 回退为 EXPLORED（每帧开始时调用）
	var bytes: PackedByteArray = _get_faction_bytes(faction_id)
	for i in range(_tile_count):
		if bytes[i] == FogState.VISIBLE:
			bytes[i] = FogState.EXPLORED
	# PackedByteArray 使用 COW 语义，必须写回字典才能持久化
	_fog_bytes_by_faction[faction_id] = bytes


func update_visibility(center_grid: Vector2i, radius: int, faction_id: int = DemoPlayerContext.FactionId.FOREST) -> void:
	## 将视野范围内的格子临时设为 VISIBLE（仅指定阵营）
	var bytes: PackedByteArray = _get_faction_bytes(faction_id)
	var max_grid_val := min_grid + map_size - Vector2i.ONE
	var r2 := radius * radius
	for dy in range(-radius, radius + 1):
		var dx_limit := int(sqrt(maxf(0.0, float(r2 - dy * dy))))
		for dx in range(-dx_limit, dx_limit + 1):
			var pos := center_grid + Vector2i(dx, dy)
			if (
				pos.x >= min_grid.x and pos.x <= max_grid_val.x
				and pos.y >= min_grid.y and pos.y <= max_grid_val.y
			):
				var idx := _index(pos)
				if idx >= 0 and bytes[idx] != FogState.VISIBLE:
					bytes[idx] = FogState.VISIBLE
	# PackedByteArray 使用 COW 语义，必须写回字典才能持久化
	_fog_bytes_by_faction[faction_id] = bytes
	_mark_faction_stats_dirty(faction_id)


## ——— 统计（带缓存，按阵营分别统计） ———

var _cached_stats: Dictionary = {}  ## {int: {"explored": int, "visible": int, "dirty": bool}}


func _get_faction_stats(faction_id: int) -> Dictionary:
	if not _cached_stats.has(faction_id):
		_cached_stats[faction_id] = {"explored": 0, "visible": 0, "dirty": true}
	var raw_stats: Variant = _cached_stats.get(faction_id, {})
	if not raw_stats is Dictionary:
		return {"explored": 0, "visible": 0, "dirty": true}
	return raw_stats as Dictionary


func get_explored_count(faction_id: int = DemoPlayerContext.FactionId.FOREST) -> int:
	var stats: Dictionary = _get_faction_stats(faction_id)
	if bool(stats.get("dirty", true)):
		_refresh_faction_stats(faction_id)
	return int(stats.get("explored", 0))


func get_visible_count(faction_id: int = DemoPlayerContext.FactionId.FOREST) -> int:
	var stats: Dictionary = _get_faction_stats(faction_id)
	if bool(stats.get("dirty", true)):
		_refresh_faction_stats(faction_id)
	return int(stats.get("visible", 0))


func get_unknown_count(faction_id: int = DemoPlayerContext.FactionId.FOREST) -> int:
	return _tile_count - get_explored_count(faction_id)


func get_explored_ratio(faction_id: int = DemoPlayerContext.FactionId.FOREST) -> float:
	return float(get_explored_count(faction_id)) / maxf(1.0, float(_tile_count))


func _refresh_faction_stats(faction_id: int) -> void:
	var bytes: PackedByteArray = _get_faction_bytes(faction_id)
	var explored: int = 0
	var visible: int = 0
	for i in range(_tile_count):
		match bytes[i]:
			FogState.VISIBLE:
				visible += 1
				explored += 1
			FogState.EXPLORED:
				explored += 1
	var stats: Dictionary = _get_faction_stats(faction_id)
	stats["explored"] = explored
	stats["visible"] = visible
	stats["dirty"] = false


func set_all_visible_temporary(faction_id: int = DemoPlayerContext.FactionId.FOREST) -> void:
	## 调试用：将全图临时设为 VISIBLE（不改变 EXPLORED 持久状态）
	reset_visibility(faction_id)
	var bytes: PackedByteArray = _get_faction_bytes(faction_id)
	bytes.fill(FogState.VISIBLE)
	# PackedByteArray 使用 COW 语义，必须写回字典才能持久化
	_fog_bytes_by_faction[faction_id] = bytes
	_mark_faction_stats_dirty(faction_id)


func _mark_faction_stats_dirty(faction_id: int) -> void:
	var stats: Dictionary = _get_faction_stats(faction_id)
	stats["dirty"] = true
	# 同时标记所有阵营为 dirty（简便实现）
	for key: Variant in _cached_stats.keys():
		var other_stats: Dictionary = _cached_stats[key] as Dictionary
		other_stats["dirty"] = true


func _mark_stats_dirty() -> void:
	## 保留向后兼容的批量 dirty 标记
	for key: Variant in _cached_stats.keys():
		var stats: Dictionary = _cached_stats[key] as Dictionary
		stats["dirty"] = true
