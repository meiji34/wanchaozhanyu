class_name MapConstructionController
extends Node3D

## ——— 建造模式控制器 ———
## 建造状态的唯一权威来源（is_build_mode 只在本类内写入）。
## 职责：进入/退出建造模式、维护建筑预览 Ghost、响应建造选点、确认/取消。
## Preview 只更新位置/高度/材质，不修改任何业务数据，也不加入正式建筑列表。

signal build_mode_changed(active: bool)
signal placement_state_changed(result: Dictionary)
signal building_placed(snapshot: Dictionary)

## 预览配色（半透明，风格与选中标记一致）
const PREVIEW_VALID_COLOR := Color(0.35, 0.9, 0.45, 0.45)
const PREVIEW_INVALID_COLOR := Color(0.95, 0.3, 0.25, 0.45)

## 选址状态：PREVIEW=预览跟随鼠标；LOCKED=左键已锁定位置，Preview 固定
enum PlacementState { PREVIEW, LOCKED }

## 建造模式状态（外部只读）
var is_build_mode := false

## 当前选址状态（统一由本控制器维护，HUD/地图不各自保存副本）
var _placement_state := PlacementState.PREVIEW

var _map_world: MapWorld
var _building_manager: MapBuildingManager
var _player_context: DemoPlayerContext
var _definition: MapBuildingDefinition
var _preview: MeshInstance3D
var _preview_valid_material: StandardMaterial3D
var _preview_invalid_material: StandardMaterial3D
var _last_origin := Vector2i.ZERO
var _last_result: Dictionary = {}


func setup(map_world: MapWorld, building_manager: MapBuildingManager) -> void:
	_map_world = map_world
	_building_manager = building_manager


func set_player_context(ctx: DemoPlayerContext) -> void:
	_player_context = ctx


## 进入建造模式。重复进入直接忽略，避免重复状态与重复 Preview。
func enter_build_mode(definition: MapBuildingDefinition) -> void:
	if is_build_mode or definition == null:
		return
	_definition = definition
	_last_result = {}
	_placement_state = PlacementState.PREVIEW
	is_build_mode = true
	if _map_world != null and _map_world.map_input_controller != null:
		_map_world.map_input_controller.cancel_active_gestures()
	# Preview 创建一次，后续只更新位置/高度/材质；首次选点前保持隐藏
	_ensure_preview()
	_preview.visible = false
	print("[Build] 进入建造模式：%s" % definition.display_name)
	build_mode_changed.emit(true)


## 退出建造模式并释放 Preview，不残留临时节点
func exit_build_mode() -> void:
	if not is_build_mode:
		return
	is_build_mode = false
	_definition = null
	_last_result = {}
	_placement_state = PlacementState.PREVIEW
	# 立即释放而非 queue_free：保证退出建造模式后无残留节点，快速反复进出也不会并存两个 Preview
	if _preview != null:
		_preview.free()
		_preview = null
	if _map_world != null and _map_world.map_input_controller != null:
		_map_world.map_input_controller.cancel_active_gestures()
	print("[Build] 退出建造模式")
	build_mode_changed.emit(false)


## 建造模式下的地图左键点击：锁定/重新锁定建造位置（不直接生成建筑）。
## 保存的是二维格子坐标，视觉位置仍由格子换算得出。
func handle_map_click(origin_cell: Vector2i) -> void:
	if not is_build_mode:
		return
	# 先切换为锁定状态再更新目标，保证发出的校验结果携带 locked 标记
	_placement_state = PlacementState.LOCKED
	_update_target(origin_cell)


## 建造模式悬停：预览跟随鼠标指向的格子（桌面鼠标；触屏通过点按选点）。
## 位置锁定后鼠标移动不再带走 Preview；同一格子重复悬停直接跳过。
func hover_at_grid(origin_cell: Vector2i) -> void:
	if not is_build_mode:
		return
	if _placement_state != PlacementState.PREVIEW:
		return
	if origin_cell == _last_origin and not _last_result.is_empty():
		return
	_update_target(origin_cell)


## 当前是否已锁定建造位置
func is_position_locked() -> bool:
	return is_build_mode and _placement_state == PlacementState.LOCKED


## 统一更新建造目标格：校验合法性、刷新预览、通知 UI
func _update_target(origin_cell: Vector2i) -> void:
	if _definition == null or _building_manager == null:
		return
	_last_origin = origin_cell
	_last_result = _building_manager.validate_placement(
		_definition, origin_cell, _get_current_faction_id()
	)
	# 轻量调试日志：仅在目标格变化时输出一行（悬停去重保证不刷屏）
	print("[BuildCheck] faction=%d cell=%s locked=%s valid=%s reason=%s" % [
		_get_current_faction_id(),
		origin_cell,
		_placement_state == PlacementState.LOCKED,
		_last_result.get("valid", false),
		_last_result.get("reason", ""),
	])
	# 附带锁定标记，供 UI 决定确认按钮可用性（不改变校验结果本身）
	_last_result["locked"] = _placement_state == PlacementState.LOCKED
	_update_preview(origin_cell, _last_result)
	placement_state_changed.emit(_last_result)


## 确认建造：必须使用左键锁定的格子（而非当前鼠标位置），
## 生成前由管理器重新校验一次，非法则返回失败原因
func confirm() -> Dictionary:
	if not is_build_mode or _definition == null:
		return {"success": false, "reason": "当前不在建造模式"}
	if _placement_state != PlacementState.LOCKED or _last_result.is_empty():
		return {"success": false, "reason": "尚未锁定建造位置"}
	if not bool(_last_result.get("valid", false)):
		return {"success": false, "reason": str(_last_result.get("reason", "当前位置不可建造"))}
	var result := _building_manager.place_building(
		_definition, _last_origin, _get_current_faction_id()
	)
	if bool(result.get("success", false)):
		var snapshot: Dictionary = result.get("snapshot", {})
		building_placed.emit(snapshot)
		exit_build_mode()
	return result


## 取消建造：丢弃预览与临时状态，不产生任何占用数据
func cancel() -> void:
	exit_build_mode()


func get_last_result() -> Dictionary:
	return _last_result


## ——— 内部 ———

func _get_current_faction_id() -> int:
	if _player_context != null:
		return _player_context.current_faction_id
	if _map_world != null and _map_world.map_controller != null:
		return _map_world.map_controller.current_fog_faction_id
	return DemoPlayerContext.FactionId.NONE


func _ensure_preview() -> void:
	if _preview != null:
		return
	if _preview_valid_material == null:
		_preview_valid_material = _make_preview_material(PREVIEW_VALID_COLOR)
		_preview_invalid_material = _make_preview_material(PREVIEW_INVALID_COLOR)
	_preview = MeshInstance3D.new()
	_preview.name = "ConstructionPreview"
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_preview.visible = false
	add_child(_preview)


## 更新预览位置、高度和材质状态。BoxMesh 原点位于几何中心，
## 因此中心 Y = 地基高度 + 预览高度 / 2，底面贴合阶梯地形表面。
func _update_preview(origin_cell: Vector2i, result: Dictionary) -> void:
	_ensure_preview()
	var map_data := _building_manager.get_map_data()
	if map_data == null or _definition == null:
		return
	var world_size := _definition.get_world_size(map_data.cell_size)
	var mesh := _preview.mesh as BoxMesh
	if mesh == null:
		mesh = BoxMesh.new()
		_preview.mesh = mesh
	if mesh.size != world_size:
		mesh.size = world_size
	var foundation := float(result.get("foundation_height", 0.0))
	_preview.position = map_data.grid_to_world_continuous(
		_definition.get_footprint_center(origin_cell),
		foundation + world_size.y * 0.5
	)
	mesh.material = _preview_valid_material if bool(result.get("valid", false)) else _preview_invalid_material
	_preview.visible = true


func _make_preview_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	return material
