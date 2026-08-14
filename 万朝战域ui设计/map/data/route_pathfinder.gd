class_name RoutePathfinder
extends RefCounted

## ——— 路线寻路器 ———
## 基于 DemoMapData 的 8 向 A* 寻路，供路线预览等玩法层使用。
## 通行规则（Demo 简化版，正式行军系统接入前有效）：
## - 山地不可通行；河流仅可经过河点（桥梁/浅滩）穿越
## - 城池占地格不可穿行（起点与终点除外）
## - 相邻格表面高度差超过 MAX_CLIMB_HEIGHT 视为悬崖，不可通行
## - 道路格移动成本更低，寻路会优先沿道路行进
## - 支持8方向移动（含对角线），路线更接近直线

const MAX_CLIMB_HEIGHT := 1.0
const ROAD_COST_MAIN := 0.4
const ROAD_COST_NORMAL := 0.6
const ROAD_COST_HIDDEN := 0.8
const PLAIN_COST := 1.0
## 对角线移动的额外系数（√2 ≈ 1.414）
const DIAGONAL_FACTOR := 1.414
## 搜索节点数上限（400×400 全图 16 万格），防止异常情况下卡死
const MAX_EXPAND_NODES := 160000

## 8方向：4正交 + 4对角线
const _DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
]
## 正交方向索引（前4个）
const _ORTHOGONAL_DIRS: Array[int] = [0, 1, 2, 3]
## 对角线方向对应的两个相邻正交方向索引（防穿角检查用）
## _DIRS[4]=(1,1)右下 → 检查右(0)+下(2); _DIRS[5]=(1,-1)右上 → 检查右(0)+上(3)
## _DIRS[6]=(-1,1)左下 → 检查左(1)+下(2); _DIRS[7]=(-1,-1)左上 → 检查左(1)+上(3)
const _DIAGONAL_NEIGHBORS: Array[Array] = [
	[0, 2],  # dir_idx=4: 右下 → 右 + 下
	[0, 3],  # dir_idx=5: 右上 → 右 + 上
	[1, 2],  # dir_idx=6: 左下 → 左 + 下
	[1, 3],  # dir_idx=7: 左上 → 左 + 上
]


## 主入口：返回从 start 到 goal 的格子路径（含起点与终点）；不可达时返回空数组
static func find_path(map_data: DemoMapData, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if map_data == null:
		return result
	if not map_data.is_valid_grid(start) or not map_data.is_valid_grid(goal):
		return result
	if not _is_passable(map_data, goal, start, goal):
		return result
	if start == goal:
		result.append(start)
		return result

	# 二叉最小堆，元素为 [f_score, grid]
	var open_heap: Array = []
	var g_score: Dictionary = {start: 0.0}
	var came_from: Dictionary = {}
	var closed: Dictionary = {}
	_heap_push(open_heap, [_heuristic(start, goal), start])

	var expanded := 0
	while not open_heap.is_empty():
		expanded += 1
		if expanded > MAX_EXPAND_NODES:
			push_warning("[RoutePathfinder] 搜索节点数超过上限，提前终止")
			return []
		var entry: Array = _heap_pop(open_heap)
		var current: Vector2i = entry[1]
		if current == goal:
			return _reconstruct_path(came_from, goal)
		if closed.has(current):
			continue
		closed[current] = true
		var current_g: float = float(g_score.get(current, INF))
		for dir_idx in range(_DIRS.size()):
			var dir: Vector2i = _DIRS[dir_idx]
			var next := current + dir
			if closed.has(next):
				continue
			if not _is_passable(map_data, next, start, goal):
				continue
			if not _can_traverse(map_data, current, next, dir_idx):
				continue
			var is_diagonal := dir_idx >= 4
			var tentative_g: float = current_g + _move_cost(map_data, next, is_diagonal)
			if tentative_g < float(g_score.get(next, INF)):
				g_score[next] = tentative_g
				came_from[next] = current
				_heap_push(open_heap, [tentative_g + _heuristic(next, goal), next])
	return []


## 对角线距离启发式（适合8方向移动，可采纳）
static func _heuristic(a: Vector2i, b: Vector2i) -> float:
	var dx := absi(a.x - b.x)
	var dy := absi(a.y - b.y)
	# 对角线部分成本 + 剩余直线部分成本
	var diagonal := mini(dx, dy)
	var straight := absi(dx - dy)
	return (diagonal * DIAGONAL_FACTOR + straight) * ROAD_COST_MAIN


static func _is_passable(
	map_data: DemoMapData,
	grid: Vector2i,
	start: Vector2i,
	goal: Vector2i
) -> bool:
	if not map_data.is_valid_grid(grid):
		return false
	if grid == start or grid == goal:
		return true
	# 有道路的格子（主干道、普通道路、环路）始终可通行
	var road_type := map_data.get_road_type_at(grid)
	if road_type in [MapTileTypes.RoadType.MAIN, MapTileTypes.RoadType.NORMAL, MapTileTypes.RoadType.RING]:
		return true
	var terrain := map_data.get_terrain_type_at(grid)
	if terrain == MapTileTypes.Terrain.MOUNTAIN:
		return false
	if terrain == MapTileTypes.Terrain.RIVER and map_data.get_crossing_at_grid(grid).is_empty():
		return false
	if map_data.get_city_at_grid(grid) != null:
		return false
	return true


## 阶梯地形通行约束：相邻格高度差过大视为悬崖
## dir_idx: 方向索引，>=4 为对角线，需额外检查相邻正交格子（防止穿角）
static func _can_traverse(map_data: DemoMapData, from_grid: Vector2i, to_grid: Vector2i, dir_idx: int = 0) -> bool:
	var from_height := map_data.get_surface_height_at_grid(from_grid)
	var to_height := map_data.get_surface_height_at_grid(to_grid)
	if absf(from_height - to_height) > MAX_CLIMB_HEIGHT:
		return false
	# 对角线移动时检查两个相邻正交格子是否可通行（防穿角）
	if dir_idx >= 4:
		var neighbors: Array = _DIAGONAL_NEIGHBORS[dir_idx - 4]
		var ortho1 := from_grid + _DIRS[neighbors[0]]
		var ortho2 := from_grid + _DIRS[neighbors[1]]
		if not _is_passable(map_data, ortho1, from_grid, to_grid):
			return false
		if not _is_passable(map_data, ortho2, from_grid, to_grid):
			return false
	return true


## 进入目标格的移动成本：道路越高级成本越低，对角线移动额外乘以 √2
static func _move_cost(map_data: DemoMapData, grid: Vector2i, is_diagonal: bool = false) -> float:
	var base_cost: float
	match map_data.get_road_type_at(grid):
		MapTileTypes.RoadType.MAIN:
			base_cost = ROAD_COST_MAIN
		MapTileTypes.RoadType.NORMAL, MapTileTypes.RoadType.RING:
			base_cost = ROAD_COST_NORMAL
		MapTileTypes.RoadType.HIDDEN:
			base_cost = ROAD_COST_HIDDEN
		_:
			base_cost = PLAIN_COST
	return base_cost if not is_diagonal else base_cost * DIAGONAL_FACTOR


static func _reconstruct_path(came_from: Dictionary, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [goal]
	var current := goal
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	return path


## ——— 二叉最小堆（按 f_score 排序） ———

static func _heap_push(heap: Array, entry: Array) -> void:
	heap.append(entry)
	var idx := heap.size() - 1
	while idx > 0:
		var parent := (idx - 1) / 2
		if float(heap[parent][0]) <= float(entry[0]):
			break
		heap[idx] = heap[parent]
		idx = parent
	heap[idx] = entry


static func _heap_pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if not heap.is_empty():
		var idx := 0
		var size := heap.size()
		var last_f := float(last[0])
		while true:
			var left := idx * 2 + 1
			var right := left + 1
			var candidate := -1
			var min_f := last_f
			if left < size and float(heap[left][0]) < min_f:
				candidate = left
				min_f = float(heap[left][0])
			if right < size and float(heap[right][0]) < min_f:
				candidate = right
			if candidate == -1:
				break
			heap[idx] = heap[candidate]
			idx = candidate
		heap[idx] = last
	return top
