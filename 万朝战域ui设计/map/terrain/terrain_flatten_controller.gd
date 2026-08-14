class_name MapTerrainFlattenController
extends Node3D

## ——— 土地平整模式控制器 ———
## 建造系统的扩展模式：选择矩形范围与目标高度等级，预览确认后由 MapController 修改权威地形数据。
## 平整模式状态的唯一权威来源（is_flatten_mode 只在本类内写入）。
## 预览只读地图数据、只更新视觉节点，确认前绝不修改 tile_heights / height_samples。

signal flatten_mode_changed(active: bool)
## 平整状态变更（供 UI 刷新高度/范围/合法性显示），字段见 _refresh() 输出
signal flatten_state_changed(state: Dictionary)
## 平整真正执行完成（供 UI 提示与地图表现层联动）
signal terrain_flattened(result: Dictionary)

## 预览配色：绿=可平整且已在目标高度，橙=可平整但需要改变高度，红=不可平整
const PREVIEW_SAME_COLOR := Color(0.35, 0.9, 0.45, 0.40)
const PREVIEW_CHANGE_COLOR := Color(0.95, 0.72, 0.25, 0.45)
const PREVIEW_INVALID_COLOR := Color(0.95, 0.3, 0.25, 0.50)
const PREVIEW_THICKNESS := 0.10
const PREVIEW_Y_OFFSET := 0.06
const PREVIEW_CELL_SCALE := 0.92

const DEFAULT_REGION_SIZE := Vector2i(3, 3)
const MIN_REGION_SIZE := 1
const MAX_REGION_SIZE := 8
## 平整允许的最大高度等级差：每个目标格子与目标高度等级的差值必须 <= 2
const MAX_FLATTEN_HEIGHT_DELTA := 2

## 平整格子状态（预览着色与合法性共用）
enum CellState {
	SAME = 0,    ## 可平整，已处于目标高度
	CHANGE = 1,  ## 可平整，需要改变高度
	INVALID = 2, ## 不可平整
}

## 平整模式状态（外部只读）
var is_flatten_mode := false

var _map_controller: MapController
var _building_manager: MapBuildingManager
var _player_context: DemoPlayerContext

## 以下为临时预览状态，不是地图权威数据；确认后才会写入真实地形
## _anchor_cell 同时承担“悬停候选锚点”和“已锁定锚点”（保存格子坐标，非世界坐标）：
## 未锁定时跟随鼠标，鼠标左键点击后锁定，之后悬停不再移动预览。
var _anchor_cell := Vector2i.ZERO
var _has_anchor := false
var _is_position_locked := false
var _target_height_level := 0
var _region_size := DEFAULT_REGION_SIZE
var _min_height_level := 0
var _max_height_level := 0
var _preview_cells: Array[Vector2i] = []
var _last_state: Dictionary = {}
## 最近一次预览的实例变换（与 MultiMesh 同步更新；无窗口 DummyRS 下 MultiMesh
## 变换无法回读，保留此数组供测试与调试核对预览位置）
var _preview_transforms: Array[Transform3D] = []

var _preview: MultiMeshInstance3D
var _preview_mesh: BoxMesh


func setup(map_controller: MapController, building_manager: MapBuildingManager) -> void:
	_map_controller = map_controller
	_building_manager = building_manager


func set_player_context(ctx: DemoPlayerContext) -> void:
	_player_context = ctx


## 进入平整模式。default_height_level 由调用方按当前视角中心格子高度计算，
## 使默认行为是“把周围土地平整到当前中心格子的高度”，而不是归零。
func enter_flatten_mode(default_height_level: int = 0) -> void:
	if is_flatten_mode:
		return
	var map_data := _get_map_data()
	if map_data == null:
		return
	is_flatten_mode = true
	# 目标高度可选范围取自当前地图真实高度范围，避免无意义等级
	_min_height_level = maxi(
		0, floori(map_data.min_terrain_height / MapGenerationConfig.HEIGHT_STEP)
	)
	_max_height_level = maxi(
		_min_height_level,
		roundi(map_data.max_terrain_height / MapGenerationConfig.HEIGHT_STEP),
	)
	_target_height_level = clampi(
		default_height_level, _min_height_level, _max_height_level
	)
	_region_size = DEFAULT_REGION_SIZE
	_has_anchor = false
	_is_position_locked = false
	_preview_cells.clear()
	_last_state = {}
	_ensure_preview()
	_preview.visible = false
	print("[Flatten] 进入土地平整模式：默认目标高度等级=%d（范围 %d~%d）" % [
		_target_height_level, _min_height_level, _max_height_level
	])
	flatten_mode_changed.emit(true)
	_refresh()


## 退出平整模式：清除预览与全部临时状态，不修改任何真实地形数据
func exit_flatten_mode() -> void:
	if not is_flatten_mode:
		return
	is_flatten_mode = false
	_has_anchor = false
	_is_position_locked = false
	_preview_cells.clear()
	_preview_transforms.clear()
	_last_state = {}
	# 立即释放而非 queue_free：保证退出后无残留预览，快速反复进出也不会并存两个预览
	if _preview != null:
		_preview.free()
		_preview = null
	print("[Flatten] 退出土地平整模式")
	flatten_mode_changed.emit(false)


## 悬停：未锁定时平整范围跟随鼠标指向格子（自动吸附格子中心）；
## 位置锁定后悬停不再移动预览，预览固定呈现最终准备平整的范围
func hover_at_grid(grid_position: Vector2i) -> void:
	if not is_flatten_mode or _is_position_locked:
		return
	if _has_anchor and grid_position == _anchor_cell:
		return
	_anchor_cell = grid_position
	_has_anchor = true
	_refresh()


## 鼠标左键点击地图：将当前指向格子锁定为平整锚点（保存格子坐标）。
## 锁定后预览不再跟随鼠标；已锁定时再次点击可改锁到新格子。
func handle_map_click(grid_position: Vector2i) -> void:
	if not is_flatten_mode:
		return
	_anchor_cell = grid_position
	_has_anchor = true
	_is_position_locked = true
	_refresh()


## 解除位置锁定（UI“重新选择”按钮）：预览恢复跟随鼠标，重新进入选点阶段
func unlock_position() -> void:
	if not is_flatten_mode or not _is_position_locked:
		return
	_is_position_locked = false
	_refresh()


func is_position_locked() -> bool:
	return _is_position_locked


func adjust_target_height(delta: int) -> void:
	if not is_flatten_mode:
		return
	_target_height_level = clampi(
		_target_height_level + delta, _min_height_level, _max_height_level
	)
	_refresh()


func adjust_region_width(delta: int) -> void:
	if not is_flatten_mode:
		return
	_region_size.x = clampi(_region_size.x + delta, MIN_REGION_SIZE, MAX_REGION_SIZE)
	_refresh()


func adjust_region_length(delta: int) -> void:
	if not is_flatten_mode:
		return
	_region_size.y = clampi(_region_size.y + delta, MIN_REGION_SIZE, MAX_REGION_SIZE)
	_refresh()


func get_target_height_level() -> int:
	return _target_height_level


func get_region_size() -> Vector2i:
	return _region_size


func get_last_state() -> Dictionary:
	return _last_state


## ——— 确认执行 ———

## 确认平整：重新实时校验（不使用缓存结果），通过后走请求入口（含施工时间钩子）
func confirm() -> Dictionary:
	if not is_flatten_mode:
		return {"success": false, "reason": "当前不在土地平整模式"}
	# 未用左键锁定位置时禁止施工：不能直接使用当前悬停格子
	if not _is_position_locked:
		return {"success": false, "reason": "请先点击地图锁定平整位置"}
	var cells := _compute_region_cells()
	var validation := validate_flatten_cells(
		_get_map_data(), _building_manager, cells, _target_height_level, _get_current_faction_id(),
		_is_fog_enabled()
	)
	if not bool(validation.get("valid", false)):
		return {"success": false, "reason": str(validation.get("reason", "该区域不可平整"))}
	var result := request_flatten_terrain(cells, _target_height_level)
	if bool(result.get("success", false)):
		result["cell_count"] = cells.size()
		result["changed_count"] = (result.get("changed_cells", []) as Array).size()
		terrain_flattened.emit(result)
		exit_flatten_mode()
	return result


## 取消：丢弃预览与临时状态，不修改任何真实地形数据
func cancel() -> void:
	exit_flatten_mode()


## ——— 施工时间接口（本阶段立即完成） ———
## 正式流程预留：玩家确认 → 计算施工时间 → 进入施工队列 → 倒计时 → 执行。
## 当前测试阶段 duration 恒为 0，立即执行；后续 duration > 0 时在此处接入施工队列，
## 无需改动 UI 与地形修改链路。
func request_flatten_terrain(cells: Array[Vector2i], target_height_level: int) -> Dictionary:
	var duration := calculate_flatten_duration(cells, target_height_level)
	if duration <= 0.0:
		return _execute_flatten_terrain(cells, target_height_level)
	# TODO: 接入施工队列：生成 TerrainFlattenRequest（cells + 目标高度 + 结束时间），
	# 倒计时完成后调用 _execute_flatten_terrain，并向 UI 汇报施工进度。
	return {"success": false, "reason": "施工队列尚未实现"}


## 计算土地平整施工时间（秒）。本阶段测试立即完成，恒返回 0。
## 后续可按“基础时间 + 格子数量 × 单格时间 + 总高度差 × 高度调整时间”计算，
## 可用参数：cells.size()（受影响格数）、各格与目标的高度差总和、阵营施工效率等。
func calculate_flatten_duration(cells: Array[Vector2i], target_height_level: int) -> float:
	var affected_cell_count := cells.size()
	var total_height_delta := 0
	var map_data := _get_map_data()
	if map_data != null:
		for cell in cells:
			if map_data.is_valid_grid(cell):
				total_height_delta += absi(
					map_data.get_height_level_at_grid(cell) - target_height_level
				)
	# 测试阶段：无论面积与高度差均立即完成（参数保留供正式时间公式使用）
	return 0.0 * float(affected_cell_count + total_height_delta)


## 真正执行地形修改：委托地图数据层入口，UI 与本控制器均不直接改 Mesh/数据
func _execute_flatten_terrain(cells: Array[Vector2i], target_height_level: int) -> Dictionary:
	if _map_controller == null:
		return {"success": false, "reason": "地图系统尚未就绪"}
	return _map_controller.flatten_terrain(cells, target_height_level)


## ——— 合法性校验（静态，供预览与确认共用，可直接单元测试） ———
## 禁止平整：地图边界外、河流、道路/桥梁、城池、资源点、已有建筑、未探索迷雾格子，
## 以及与目标高度等级差超过 MAX_FLATTEN_HEIGHT_DELTA 的格子。
## 阵营权限沿用现有建造规则（当前建造只校验迷雾视野，不额外限制领土归属）。
static func validate_flatten_cells(
	map_data: DemoMapData,
	building_manager: MapBuildingManager,
	cells: Array[Vector2i],
	target_height_level: int,
	faction_id: int,
	fog_enabled: bool
) -> Dictionary:
	var result := {
		"valid": true,
		"reason": "",
		"cell_states": {},
		"changed_count": 0,
	}
	if map_data == null:
		result["valid"] = false
		result["reason"] = "地图数据尚未就绪"
		return result
	var cell_states: Dictionary = {}
	var changed_count := 0
	var first_reason := ""
	var fog := map_data.fog_data if fog_enabled else null
	for cell in cells:
		var state := int(CellState.SAME)
		var reason := ""
		if not map_data.is_valid_grid(cell):
			reason = "平整范围超出地图边界"
		elif map_data.get_terrain_type_at(cell) == MapTileTypes.Terrain.RIVER:
			reason = "该区域包含不可平整地形（河流）"
		elif map_data.has_road_at(cell):
			reason = "该区域包含不可平整地形（道路/桥梁）"
		elif map_data.get_city_at_grid(cell) != null:
			reason = "平整范围与城池重叠"
		elif map_data.get_resource_at_grid(cell) != null:
			reason = "平整范围与资源点重叠"
		elif building_manager != null and building_manager.is_cell_occupied_by_building(cell):
			reason = "平整范围已被建筑占用"
		elif fog != null and fog.is_unknown(cell, faction_id):
			reason = "平整范围尚未探索"
		if reason.is_empty():
			# 高度差规则：每个目标格子与目标高度等级的差值必须 <= MAX_FLATTEN_HEIGHT_DELTA
			#（逐格比较，而非范围内最高最低差）
			var height_delta: int = absi(
				map_data.get_height_level_at_grid(cell) - target_height_level
			)
			if height_delta > MAX_FLATTEN_HEIGHT_DELTA:
				reason = "目标区域存在与目标高度等级相差超过 %d 级的地块" % MAX_FLATTEN_HEIGHT_DELTA
				state = int(CellState.INVALID)
				if first_reason.is_empty():
					first_reason = reason
			elif height_delta > 0:
				state = int(CellState.CHANGE)
				changed_count += 1
		else:
			state = int(CellState.INVALID)
			if first_reason.is_empty():
				first_reason = reason
		cell_states[cell] = state
	result["cell_states"] = cell_states
	result["changed_count"] = changed_count
	if not first_reason.is_empty():
		result["valid"] = false
		result["reason"] = first_reason
	elif changed_count == 0:
		result["valid"] = false
		result["reason"] = "范围内土地已处于目标高度"
	return result


## ——— 内部 ———

## 平整范围复用建筑占地系统的通用矩形格子算法，与建筑 footprint 同一中心约定
func _compute_region_cells() -> Array[Vector2i]:
	return MapBuildingDefinition.compute_footprint_cells(_anchor_cell, _region_size)


## 统一刷新：重新计算范围、校验、更新预览、通知 UI（悬停/改高度/改范围均走这里）
func _refresh() -> void:
	var map_data := _get_map_data()
	if not is_flatten_mode or map_data == null:
		return
	if _has_anchor:
		_preview_cells = _compute_region_cells()
	else:
		_preview_cells.clear()
	var validation := validate_flatten_cells(
		map_data, _building_manager, _preview_cells, _target_height_level,
		_get_current_faction_id(), _is_fog_enabled()
	)
	_last_state = {
		"has_anchor": _has_anchor,
		"anchor_cell": _anchor_cell,
		"locked": _is_position_locked,
		"target_height_level": _target_height_level,
		"min_height_level": _min_height_level,
		"max_height_level": _max_height_level,
		"region_width": _region_size.x,
		"region_length": _region_size.y,
		"cell_count": _preview_cells.size(),
		"valid": bool(validation.get("valid", false)),
		"reason": str(validation.get("reason", "")),
		"changed_count": int(validation.get("changed_count", 0)),
		"duration": calculate_flatten_duration(_preview_cells, _target_height_level),
	}
	_update_preview(_preview_cells, validation.get("cell_states", {}))
	flatten_state_changed.emit(_last_state)


## 更新预览：每个格子一块半透明薄板，统一放置在目标高度位置，
## 直观呈现“平整完成后的地形高度”；颜色区分可平整/需改变/不可平整。
## 预览只读取地图数据，绝不写入。
func _update_preview(cells: Array[Vector2i], cell_states: Dictionary) -> void:
	_ensure_preview()
	var map_data := _get_map_data()
	if map_data == null or cells.is_empty():
		_preview.visible = false
		_preview.multimesh.instance_count = 0
		_preview_transforms.clear()
		return
	var target_world_height := (
		float(_target_height_level) * MapGenerationConfig.HEIGHT_STEP
	)
	var multimesh := _preview.multimesh
	multimesh.instance_count = cells.size()
	_preview_transforms.clear()
	for index in range(cells.size()):
		var cell := cells[index]
		var state := int(cell_states.get(cell, int(CellState.INVALID)))
		var color := PREVIEW_SAME_COLOR
		match state:
			CellState.CHANGE:
				color = PREVIEW_CHANGE_COLOR
			CellState.INVALID:
				color = PREVIEW_INVALID_COLOR
		var scale := Basis.from_scale(Vector3(
			map_data.cell_size * PREVIEW_CELL_SCALE,
			PREVIEW_THICKNESS,
			map_data.cell_size * PREVIEW_CELL_SCALE
		))
		var origin := map_data.grid_to_world(
			cell, target_world_height + PREVIEW_Y_OFFSET
		)
		var instance_transform := Transform3D(scale, origin)
		_preview_transforms.append(instance_transform)
		multimesh.set_instance_transform(index, instance_transform)
		multimesh.set_instance_color(index, color)
	_preview.visible = true


## 预览实例变换（测试/调试用途；与 MultiMesh 内容一一对应）
func get_preview_transforms() -> Array[Transform3D]:
	return _preview_transforms


func _ensure_preview() -> void:
	if _preview != null:
		return
	_preview_mesh = BoxMesh.new()
	_preview_mesh.size = Vector3.ONE
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_preview_mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = _preview_mesh
	multimesh.instance_count = 0
	_preview = MultiMeshInstance3D.new()
	_preview.name = "FlattenPreview"
	_preview.multimesh = multimesh
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_preview.visible = false
	add_child(_preview)


func _get_map_data() -> DemoMapData:
	return _map_controller.map_data if _map_controller != null else null


func _is_fog_enabled() -> bool:
	return _map_controller != null and _map_controller.fog_enabled


func _get_current_faction_id() -> int:
	if _player_context != null:
		return _player_context.current_faction_id
	if _map_controller != null:
		return _map_controller.current_fog_faction_id
	return DemoPlayerContext.FactionId.NONE
