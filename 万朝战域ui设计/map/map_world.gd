class_name MapWorld
extends Node3D

enum MapInitState {
	NOT_STARTED,   ## 尚未开始初始化
	GENERATING,    ## 正在生成地图数据
	INITIALIZING,  ## 正在初始化 Chunk / 相机 / 实体
	READY,         ## 初始化完成，可处理输入
	FAILED,        ## 初始化失败
}

const SELECTION_HIGHLIGHT_Y_OFFSET := 0.08
const SELECTION_HIGHLIGHT_CELL_SCALE := 0.91
const SELECTION_HIGHLIGHT_THICKNESS := 0.04

signal map_ready
signal tile_selected(tile_id: Vector2i)
signal city_selected(city_id: String, tile_id: Vector2i)
signal resource_selected(resource_id: String, tile_id: Vector2i)
## 建造系统生成的占位建筑被点击
signal building_selected(building_id: String, tile_id: Vector2i)
signal selection_cleared
signal view_mode_changed(mode: int, display_name: String)
## 中立侦察请求信号，由玩法层接收后决定是否发起正式侦察
signal scout_requested(tile_id: Vector2i)
## 迷雾状态变更，供 UI 更新探索统计
signal fog_state_changed(explored_ratio: float, visible_count: int, unknown_count: int)

@onready var map_controller: MapController = $MapController
@onready var camera_rig: MapCameraRig = $CameraRig
@onready var map_input_controller: MapInputController = $MapInputController
@onready var chunk_root: Node3D = $ChunkRoot
@onready var entity_root: Node3D = $EntityRoot
@onready var selection_root: Node3D = $SelectionRoot
@onready var debug_overlay: MapDebugOverlay = $DebugOverlay

var init_state: int = MapInitState.NOT_STARTED
# WorldEnvironment 由 _ensure_environment 动态创建，不使用 @onready

var _selection_marker: MultiMeshInstance3D
var _selection_marker_mesh: BoxMesh
var _selection_highlight_cells: Array[Vector2i] = []
var _route_highlight: MultiMeshInstance3D
var _route_target_marker: MeshInstance3D  ## 路线预览目标格子标记
var _selected_city_id := ""
var _selected_resource_id := ""
var _selected_building_id := ""

# 建造系统（_ready 中创建，管理器负责数据与校验，控制器负责建造模式状态）
var building_manager: MapBuildingManager
var construction: MapConstructionController
# 土地平整模式控制器（建造系统的扩展模式，与建造模式互斥）
var terrain_flatten: MapTerrainFlattenController
var _player_context: DemoPlayerContext


func _ready() -> void:
	init_state = MapInitState.INITIALIZING
	_ensure_environment()
	_ensure_lighting()
	_build_selection_marker()
	_build_route_highlight()
	_build_route_target_marker()
	map_input_controller.setup(camera_rig, self)
	camera_rig.view_mode_changed.connect(_on_view_mode_changed)
	map_controller.map_ready.connect(_on_map_ready)
	map_controller.fog_changed.connect(_emit_fog_state)
	map_controller.initialize(camera_rig, chunk_root, entity_root)
	_setup_construction_system()
	debug_overlay.setup(map_controller, camera_rig)
	# 初始化经营模式距离薄雾
	_apply_view_mode_environment()
	init_state = MapInitState.READY


## 公开 API：获取最近一次选中的格子坐标（供调试面板使用）
var last_hit_grid: Vector2i = Vector2i(999999, 999999)


func handle_map_input(
	event: InputEvent,
	source_size: Vector2,
	viewport_size: Vector2
) -> bool:
	return map_input_controller.handle_input(event, source_size, viewport_size)


func get_city_snapshot(city_id: String) -> Dictionary:
	var city := map_controller.get_city_by_id(city_id)
	if city == null:
		return {}
	return {
		"kind": "city",
		"id": city.city_id,
		"tile_id": city.grid_position,
		"name": city.display_name,
		"level": city.level,
		"faction": city.faction_placeholder,
		"faction_id": city.faction_id,
		"city_role": city.city_role,
	}


func get_tile_snapshot(tile_id: Vector2i) -> Dictionary:
	if map_controller.map_data == null:
		return {}
	var tile := map_controller.map_data.get_tile(tile_id)
	if tile == null:
		return {}
	var snapshot := {
		"kind": "tile",
		"tile_id": tile.grid_position,
		"terrain": MapTileTypes.get_display_name(tile.terrain_type),
		"height": tile.height,
		# 逻辑高度等级（阶梯等级 = 原始高度 / HEIGHT_STEP），供格子信息 UI 显示
		"height_level": map_controller.map_data.get_height_level_at_grid(tile_id),
		"slope": tile.slope,
		"forest_density": tile.forest_density,
		"river_mask": tile.river_mask,
		"has_road": tile.has_road,
		"road_type": tile.road_type,
		"road_name": MapTileTypes.get_road_display_name(tile.road_type),
		"zone_type": tile.zone_type,
		"zone_name": MapTileTypes.get_zone_display_name(tile.zone_type),
		"can_build_city": tile.can_build_city,
		"faction_id": tile.faction_id,
	}
	var crossing := map_controller.map_data.get_crossing_at_grid(tile_id)
	if not crossing.is_empty():
		snapshot["crossing_name"] = crossing.get("display_name", "过河点")
		snapshot["crossing_type"] = crossing.get("crossing_type", "bridge")
	return snapshot


func get_resource_snapshot(resource_id: String) -> Dictionary:
	var resource_point := map_controller.get_resource_by_id(resource_id)
	if resource_point == null:
		return {}
	return {
		"kind": "resource",
		"id": resource_point.resource_id,
		"tile_id": resource_point.grid_position,
		"name": resource_point.display_name,
		"resource_type": resource_point.resource_type,
		"resource_name": MapResourcePointData.get_type_display_name(resource_point.resource_type),
		"zone_type": resource_point.zone_type,
		"zone_name": MapTileTypes.get_zone_display_name(resource_point.zone_type),
		"neutral": resource_point.is_neutral,
		"interactable": resource_point.is_interactable,
	}


func zoom_by_factor(factor: float, viewport_size: Vector2) -> void:
	camera_rig.zoom_by_factor(factor, viewport_size)


func reset_view(viewport_size: Vector2) -> void:
	camera_rig.reset_view(viewport_size)
	clear_selection()


func set_view_mode(mode: int, viewport_size: Vector2) -> void:
	map_input_controller.cancel_active_gestures()
	camera_rig.set_view_mode(mode, viewport_size)
	_apply_view_mode_environment()


func toggle_view_mode(viewport_size: Vector2) -> void:
	map_input_controller.cancel_active_gestures()
	camera_rig.toggle_view_mode(viewport_size)
	_apply_view_mode_environment()


func get_view_mode() -> int:
	return camera_rig.view_mode


func get_view_mode_display_name() -> String:
	return camera_rig.get_view_mode_display_name()


func select_at_viewport_position(viewport_position: Vector2) -> void:
	if init_state != MapInitState.READY or map_controller.map_data == null:
		return
	var hit_variant: Variant = camera_rig.screen_to_ground(
		viewport_position,
		map_controller.map_data
	)
	if hit_variant == null:
		clear_selection()
		return
	var world_position := hit_variant as Vector3
	var grid_position := map_controller.map_data.world_to_grid(world_position)
	if not map_controller.map_data.is_valid_grid(grid_position):
		clear_selection()
		return
	# 建造模式下点击优先用于选择建造位置，不触发原有选择与信息 UI
	if is_build_mode_active():
		construction.handle_map_click(grid_position)
		return
	# 土地平整模式下点击用于移动平整锚点，不触发原有选择与信息 UI
	if is_flatten_mode_active():
		terrain_flatten.handle_map_click(grid_position)
		return
	var city := map_controller.get_city_at_grid(grid_position)
	if city != null:
		_select_city(city)
		return
	var resource_point := map_controller.get_resource_at_grid(grid_position)
	if resource_point != null:
		_select_resource(resource_point)
		return
	var building := building_manager.get_building_at_grid(grid_position) if building_manager != null else null
	if building != null:
		_select_building(building)
	else:
		_select_tile(grid_position)


## 创建建造系统：建筑管理器 + 建造模式控制器（节点仅创建一次）
func _setup_construction_system() -> void:
	building_manager = MapBuildingManager.new()
	building_manager.name = "BuildingManager"
	add_child(building_manager)
	building_manager.setup(map_controller)
	construction = MapConstructionController.new()
	construction.name = "ConstructionController"
	add_child(construction)
	construction.setup(self, building_manager)
	terrain_flatten = MapTerrainFlattenController.new()
	terrain_flatten.name = "TerrainFlattenController"
	add_child(terrain_flatten)
	terrain_flatten.setup(map_controller, building_manager)
	terrain_flatten.terrain_flattened.connect(_on_terrain_flattened)
	if _player_context != null:
		construction.set_player_context(_player_context)
		terrain_flatten.set_player_context(_player_context)


## 注入玩家上下文（由 MapArea 转发），供建造归属阵营判断
func set_player_context(ctx: DemoPlayerContext) -> void:
	_player_context = ctx
	if construction != null:
		construction.set_player_context(ctx)
	if terrain_flatten != null:
		terrain_flatten.set_player_context(ctx)


## ——— 建造模式公开 API（供 HUD 调用） ———

## 进入建造模式。definition 为空时使用默认测试建筑；rotation_index 继承选择栏方向。
func enter_build_mode(definition: MapBuildingDefinition = null, rotation_index: int = 0) -> void:
	# 与土地平整模式互斥：进入建造前先退出平整
	if terrain_flatten != null and terrain_flatten.is_flatten_mode:
		terrain_flatten.exit_flatten_mode()
	if construction != null:
		if definition == null:
			definition = MapBuildingDefinition.create_test_building()
		construction.enter_build_mode(definition, rotation_index)


## 地图建造阶段旋转（PREVIEW / LOCKED 均允许，锚点格不变）
func rotate_building() -> void:
	if construction != null:
		construction.rotate_building()


func exit_build_mode() -> void:
	if construction != null:
		construction.exit_build_mode()


func is_build_mode_active() -> bool:
	return construction != null and construction.is_build_mode


func confirm_build_mode() -> Dictionary:
	if construction == null:
		return {"success": false, "reason": "建造系统不可用"}
	return construction.confirm()


func get_construction_controller() -> MapConstructionController:
	return construction


## ——— 土地平整模式公开 API（供 HUD 经 MapArea 调用） ———

## 进入土地平整模式。默认目标高度取当前视角中心格子的高度等级，
## 使默认行为是“把周围土地平整到当前中心格子的高度”。
func enter_flatten_mode() -> void:
	if terrain_flatten == null or map_controller.map_data == null:
		return
	# 与建造模式互斥：进入平整前先退出建造，建筑选择状态由 HUD 的选择栏保留
	if construction != null and construction.is_build_mode:
		construction.exit_build_mode()
	map_input_controller.cancel_active_gestures()
	var camera_grid := camera_rig.get_target_grid(map_controller.map_data)
	var default_level := map_controller.map_data.get_height_level_at_grid(camera_grid)
	terrain_flatten.enter_flatten_mode(default_level)


func exit_flatten_mode() -> void:
	if terrain_flatten != null:
		terrain_flatten.exit_flatten_mode()


func is_flatten_mode_active() -> bool:
	return terrain_flatten != null and terrain_flatten.is_flatten_mode


func get_terrain_flatten_controller() -> MapTerrainFlattenController:
	return terrain_flatten


## 平整模式悬停拾取：与建造预览复用同一条射线求交路径
func hover_flatten_position(viewport_position: Vector2) -> void:
	if not is_flatten_mode_active():
		return
	if init_state != MapInitState.READY or map_controller.map_data == null:
		return
	var hit_variant: Variant = camera_rig.screen_to_ground(
		viewport_position,
		map_controller.map_data
	)
	if hit_variant == null:
		return
	var grid_position := map_controller.map_data.world_to_grid(hit_variant as Vector3)
	if not map_controller.map_data.is_valid_grid(grid_position):
		return
	terrain_flatten.hover_at_grid(grid_position)


## 平整完成后刷新选中高亮贴地高度（选中数据不变，仅视觉贴合新地形）
func _on_terrain_flattened(_result: Dictionary) -> void:
	if not _selection_highlight_cells.is_empty():
		show_selection_highlight(_selection_highlight_cells)


## 删除建筑统一入口（UI 经 MapArea 转发到此，最终由 MapBuildingManager 完成业务校验与执行）。
## 请求阵营在调用时实时读取，避免阵营切换后的过期缓存导致越权或误判。
func request_delete_building(building_id: String) -> Dictionary:
	if building_manager == null:
		return {"success": false, "reason": "建造系统不可用", "message": "建造系统不可用"}
	var faction := (
		_player_context.current_faction_id
		if _player_context != null
		else map_controller.current_fog_faction_id
	)
	var result := building_manager.request_delete_building(building_id, faction)
	# 若被删除的正是当前选中建筑，同步清除选中状态并通知 UI 关闭面板
	if bool(result.get("success", false)) and _selected_building_id == building_id:
		clear_selection()
	return result


func get_building_snapshot(building_id: String) -> Dictionary:
	if building_manager == null:
		return {}
	var building := building_manager.get_building_by_id(building_id)
	return building.get_snapshot() if building != null else {}


## 建造模式悬停拾取：将屏幕坐标射线求交为格子后交给建造系统。
## 复用与点击完全相同的拾取路径，未命中或越界时保持当前预览不变。
func hover_build_position(viewport_position: Vector2) -> void:
	if not is_build_mode_active():
		return
	if init_state != MapInitState.READY or map_controller.map_data == null:
		return
	var hit_variant: Variant = camera_rig.screen_to_ground(
		viewport_position,
		map_controller.map_data
	)
	if hit_variant == null:
		return
	var grid_position := map_controller.map_data.world_to_grid(hit_variant as Vector3)
	if not map_controller.map_data.is_valid_grid(grid_position):
		return
	construction.hover_at_grid(grid_position)


func request_scout_at_viewport_position(viewport_position: Vector2) -> void:
	## 发出中立侦察请求。地图只做格子拾取，不实现正式侦察逻辑。
	if init_state != MapInitState.READY or map_controller.map_data == null:
		return
	# 建造/平整模式下点击用于选择目标位置，不触发侦察
	if is_build_mode_active() or is_flatten_mode_active():
		return
	var hit_variant: Variant = camera_rig.screen_to_ground(
		viewport_position,
		map_controller.map_data
	)
	if hit_variant == null:
		return
	var grid_position := map_controller.map_data.world_to_grid(hit_variant as Vector3)
	if not map_controller.map_data.is_valid_grid(grid_position):
		return
	scout_requested.emit(grid_position)


func _select_building(building: MapBuildingData) -> void:
	if building == null or not _is_grid_object_visible(building.origin_cell):
		clear_selection()
		return
	_selected_city_id = ""
	_selected_resource_id = ""
	_selected_building_id = building.building_id
	map_controller.set_selected_city("")
	clear_route_preview()
	# 正式保存的 occupied_cells 是唯一范围真值，不根据模型或 footprint 重新猜测。
	show_selection_highlight(building.occupied_cells)
	last_hit_grid = building.origin_cell
	building_selected.emit(building.building_id, building.origin_cell)


func clear_selection() -> void:
	_selected_city_id = ""
	_selected_resource_id = ""
	_selected_building_id = ""
	map_controller.set_selected_city("")
	_selection_highlight_cells.clear()
	if _selection_marker != null:
		_selection_marker.visible = false
		if _selection_marker.multimesh != null:
			_selection_marker.multimesh.instance_count = 0
	clear_route_preview()
	selection_cleared.emit()


func set_debug_enabled(enabled: bool) -> void:
	debug_overlay.set_debug_enabled(enabled)


## ——— 格子视觉控制 ———

## 切换格子视觉线显示。无需重建 Chunk，立即更新所有已缓存地面材质。
func set_grid_visual_enabled(enabled: bool) -> void:
	MapChunk.set_grid_visual_enabled(enabled)


## 获取格子视觉线当前开关状态
func is_grid_visual_enabled() -> bool:
	return MapChunk.grid_visual_enabled


func get_debug_snapshot() -> Dictionary:
	var snapshot := map_controller.get_debug_snapshot()
	snapshot["camera"] = camera_rig.get_debug_data()
	snapshot["selected_city_id"] = _selected_city_id
	snapshot["selected_resource_id"] = _selected_resource_id
	snapshot["selected_building_id"] = _selected_building_id
	snapshot["building_count"] = building_manager.get_building_count() if building_manager != null else 0
	snapshot["build_mode"] = is_build_mode_active()
	snapshot["selection_visible"] = _selection_marker.visible
	return snapshot


func _select_city(city: MapCityData) -> void:
	if city == null or not _is_grid_object_visible(city.grid_position):
		clear_selection()
		return
	_selected_city_id = city.city_id
	_selected_resource_id = ""
	_selected_building_id = ""
	clear_route_preview()
	map_controller.set_selected_city(city.city_id)
	_place_selection_marker(city.grid_position, true)
	last_hit_grid = city.grid_position
	city_selected.emit(city.city_id, city.grid_position)


func _select_resource(resource_point: MapResourcePointData) -> void:
	if resource_point == null or not _is_grid_object_visible(resource_point.grid_position):
		clear_selection()
		return
	_selected_city_id = ""
	_selected_resource_id = resource_point.resource_id
	_selected_building_id = ""
	clear_route_preview()
	map_controller.set_selected_city("")
	_place_selection_marker(resource_point.grid_position, false, Vector2i(3, 3))
	last_hit_grid = resource_point.grid_position
	resource_selected.emit(resource_point.resource_id, resource_point.grid_position)


func _select_tile(grid_position: Vector2i) -> void:
	_selected_city_id = ""
	_selected_resource_id = ""
	_selected_building_id = ""
	clear_route_preview()
	map_controller.set_selected_city("")
	_place_selection_marker(grid_position, false)
	last_hit_grid = grid_position
	tile_selected.emit(grid_position)


func _place_selection_marker(
	grid_position: Vector2i,
	is_city: bool,
	requested_footprint: Vector2i = Vector2i.ONE
) -> void:
	if is_city:
		var city := map_controller.get_city_at_grid(grid_position)
		if city != null:
			show_selection_highlight(city.get_occupied_cells())
			return
	var cells: Array[Vector2i] = []
	var safe_size := Vector2i(maxi(1, requested_footprint.x), maxi(1, requested_footprint.y))
	var half_size := Vector2i(
		floori(float(safe_size.x) * 0.5),
		floori(float(safe_size.y) * 0.5)
	)
	var rect := Rect2i(grid_position - half_size, safe_size)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			cells.append(Vector2i(x, y))
	show_selection_highlight(cells)


## 现有选中高亮的统一入口。每个格子独立贴合阶梯表面，不产生碰撞。
func show_selection_highlight(cells: Array[Vector2i]) -> void:
	if _selection_marker == null or map_controller == null or map_controller.map_data == null:
		return
	var map_data := map_controller.map_data
	var unique_cells: Dictionary = {}
	_selection_highlight_cells.clear()
	for cell in cells:
		if map_data.is_valid_grid(cell) and not unique_cells.has(cell):
			unique_cells[cell] = true
			_selection_highlight_cells.append(cell)
	if _selection_highlight_cells.is_empty():
		_selection_marker.multimesh.instance_count = 0
		_selection_marker.visible = false
		return
	_selection_marker_mesh.size = Vector3(
		map_data.cell_size * SELECTION_HIGHLIGHT_CELL_SCALE,
		SELECTION_HIGHLIGHT_THICKNESS,
		map_data.cell_size * SELECTION_HIGHLIGHT_CELL_SCALE
	)
	_selection_marker.multimesh.instance_count = _selection_highlight_cells.size()
	for index in range(_selection_highlight_cells.size()):
		var cell := _selection_highlight_cells[index]
		var world_position := map_data.grid_to_world(
			cell,
			map_data.get_surface_height_at_grid(cell) + SELECTION_HIGHLIGHT_Y_OFFSET
		)
		_selection_marker.multimesh.set_instance_transform(
			index,
			Transform3D(Basis.IDENTITY, world_position)
		)
	_selection_marker.visible = true


func get_selection_highlight_cells() -> Array[Vector2i]:
	return _selection_highlight_cells.duplicate()


## 与现有地图实体显示规则保持一致：迷雾关闭时可见，开启时 UNKNOWN 不可选中。
func _is_grid_object_visible(grid_position: Vector2i) -> bool:
	if map_controller == null or map_controller.map_data == null or not map_controller.fog_enabled:
		return true
	var fog := map_controller.map_data.fog_data
	return (
		fog == null
		or not fog.is_unknown(grid_position, map_controller.current_fog_faction_id)
	)


## ——— 路线预览 ———

## 路线预览统一入口（UI 经 MapArea 转发到此）。
## 从当前阵营主城出发做 A* 寻路，命中后把路线格高亮渲染到 SelectionRoot。
func request_route_preview(target_grid: Vector2i) -> Dictionary:
	if init_state != MapInitState.READY or map_controller.map_data == null:
		return {"success": false, "message": "地图尚未就绪，无法预览路线"}
	if not map_controller.map_data.is_valid_grid(target_grid):
		return {"success": false, "message": "目标格子超出地图范围"}
	var faction := (
		_player_context.current_faction_id
		if _player_context != null
		else map_controller.current_fog_faction_id
	)
	var capital_id := String(map_controller.get_capital_id_for_faction(faction))
	if capital_id.is_empty():
		return {"success": false, "message": "当前阵营没有主城，无法预览路线"}
	var city := map_controller.map_data.get_city_by_id(capital_id)
	if city == null:
		return {"success": false, "message": "未找到主城数据"}
	var path := RoutePathfinder.find_path(map_controller.map_data, city.grid_position, target_grid)
	if path.is_empty():
		clear_route_preview()
		return {
			"success": false,
			"message": "无法找到从「%s」到 (%d, %d) 的可达路线" % [
				city.display_name, target_grid.x, target_grid.y
			]
		}
	_show_route_highlight(path)
	return {
		"success": true,
		"message": "已展示从「%s」到 (%d, %d) 的路线，途经 %d 格（青色高亮）" % [
			city.display_name, target_grid.x, target_grid.y, path.size()
		]
	}


## 清除路线高亮（选择变化 / 清除选择时自动调用）
func clear_route_preview() -> void:
	if _route_highlight == null:
		return
	_route_highlight.visible = false
	_route_highlight.multimesh.instance_count = 0
	if _route_target_marker != null:
		_route_target_marker.visible = false


## 用 MultiMesh 一次性渲染整段路线的格子高亮（青色半透明方块，区别于琥珀色选中标记）
func _show_route_highlight(path: Array[Vector2i]) -> void:
	var multimesh := _route_highlight.multimesh
	multimesh.instance_count = path.size()
	for i in path.size():
		var grid := path[i]
		var world_pos := map_controller.map_data.grid_to_world(
			grid,
			map_controller.map_data.get_surface_height_at_grid(grid) + 0.1
		)
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, world_pos))
	_route_highlight.visible = true
	# 在目标格子显示标记（路径最后一个点）
	if _route_target_marker != null and not path.is_empty():
		var target_grid := path[path.size() - 1]
		var target_pos := map_controller.map_data.grid_to_world(
			target_grid,
			map_controller.map_data.get_surface_height_at_grid(target_grid) + 0.15
		)
		_route_target_marker.position = target_pos
		_route_target_marker.visible = true


func _build_route_highlight() -> void:
	_route_highlight = MultiMeshInstance3D.new()
	_route_highlight.name = "RouteHighlight"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.6, 0.05, 1.6)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.85, 0.95, 0.55)
	material.emission_enabled = true
	material.emission = Color(0.25, 0.75, 0.9)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	_route_highlight.multimesh = multimesh
	_route_highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_route_highlight.visible = false
	selection_root.add_child(_route_highlight)


## 创建路线预览目标格子标记（红色圆环，区别于路线高亮和选中标记）
func _build_route_target_marker() -> void:
	_route_target_marker = MeshInstance3D.new()
	_route_target_marker.name = "RouteTargetMarker"
	# 用扁圆柱模拟圆环（高度很小，形成圆盘状）
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.7
	mesh.bottom_radius = 0.7
	mesh.height = 0.04
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.25, 0.15, 0.85)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.2, 0.1)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	_route_target_marker.mesh = mesh
	_route_target_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_route_target_marker.visible = false
	selection_root.add_child(_route_target_marker)


func _build_selection_marker() -> void:
	_selection_marker = MultiMeshInstance3D.new()
	_selection_marker.name = "SelectionMarker"
	_selection_marker_mesh = BoxMesh.new()
	_selection_marker_mesh.size = Vector3(1.82, SELECTION_HIGHLIGHT_THICKNESS, 1.82)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.72, 0.25, 0.58)
	material.emission_enabled = true
	material.emission = Color(0.95, 0.62, 0.18)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_selection_marker_mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _selection_marker_mesh
	multimesh.instance_count = 0
	_selection_marker.multimesh = multimesh
	_selection_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_selection_marker.visible = false
	selection_root.add_child(_selection_marker)


func _ensure_environment() -> void:
	if get_node_or_null("WorldEnvironment") != null:
		return
	var environment_node := WorldEnvironment.new()
	environment_node.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("161a16")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d8c6a4")
	environment.ambient_light_energy = 0.55
	environment_node.environment = environment
	add_child(environment_node)
	move_child(environment_node, 0)


func _ensure_lighting() -> void:
	if get_node_or_null("MapKeyLight") != null:
		return
	var key_light := DirectionalLight3D.new()
	key_light.name = "MapKeyLight"
	key_light.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	key_light.light_color = Color("f1d8ad")
	key_light.light_energy = 1.15
	key_light.shadow_enabled = false
	add_child(key_light)
	move_child(key_light, 1)


func _on_map_ready() -> void:
	map_ready.emit()


func _on_view_mode_changed(mode: int) -> void:
	_apply_view_mode_environment()
	view_mode_changed.emit(mode, camera_rig.get_view_mode_display_name())


## ——— 视角模式环境控制 ———
## 经营 3D：启用距离薄雾；战争 2.5D：关闭薄雾但保留 UNKNOWN 迷雾

func _apply_view_mode_environment() -> void:
	var we_node := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we_node == null or we_node.environment == null:
		return
	if camera_rig.view_mode == MapCameraRig.ViewMode.BATTLE_2_5D:
		# 战争模式：关闭距离雾，只保留迷雾遮蔽
		we_node.environment.fog_enabled = false
		# 降低树木密度（通过控制器参数，由 Chunk 后续重建时生效）
		map_controller.set_battle_tree_density_scale(0.3)
	else:
		# 经营模式：开启距离雾
		we_node.environment.fog_enabled = true
		we_node.environment.fog_mode = Environment.FOG_MODE_DEPTH
		we_node.environment.fog_density = 0.0008
		we_node.environment.fog_light_color = Color("c8b894")
		we_node.environment.fog_sun_scatter = 0.1
		map_controller.set_battle_tree_density_scale(1.0)


## ——— 第三版公开 API（供调试面板 / HUD 调用） ———

func set_fog_enabled(p_enabled: bool) -> void:
	map_controller.set_fog_enabled(p_enabled)


func set_lod_enabled(p_enabled: bool) -> void:
	map_controller.set_lod_enabled(p_enabled)


func set_preload_enabled(p_enabled: bool) -> void:
	map_controller.set_preload_enabled(p_enabled)


func reveal_area(center_grid: Vector2i, radius: int) -> void:
	map_controller.reveal_area(center_grid, radius)


func reveal_all() -> void:
	if map_controller.map_data != null and map_controller.map_data.fog_data != null:
		map_controller.map_data.fog_data.reveal_all(map_controller.current_fog_faction_id)
		map_controller.mark_fog_dirty()


func reset_fog() -> void:
	if map_controller.map_data != null and map_controller.map_data.fog_data != null:
		map_controller.map_data.fog_data.reset_all(map_controller.current_fog_faction_id)
	map_controller.mark_fog_dirty()


func get_map_controller() -> MapController:
	return map_controller


func get_camera_rig() -> MapCameraRig:
	return camera_rig


func get_selected_city_id() -> String:
	return _selected_city_id


func set_fog_all_unknown() -> void:
	## 调试用：全图设为 UNKNOWN（当前阵营）
	if map_controller.map_data != null and map_controller.map_data.fog_data != null:
		map_controller.map_data.fog_data.reset_all(map_controller.current_fog_faction_id)
		map_controller.mark_fog_dirty()
	print("[Fog] Set all UNKNOWN for faction %d" % map_controller.current_fog_faction_id)


func set_fog_all_explored() -> void:
	## 调试用：全图设为 EXPLORED（当前阵营）
	if map_controller.map_data != null and map_controller.map_data.fog_data != null:
		map_controller.map_data.fog_data.reveal_all(map_controller.current_fog_faction_id)
		map_controller.mark_fog_dirty()
	print("[Fog] Set all EXPLORED for faction %d" % map_controller.current_fog_faction_id)


func set_fog_all_visible() -> void:
	## 调试用：全图临时设为 VISIBLE（当前阵营）
	var fog := map_controller.map_data.fog_data if map_controller.map_data != null else null
	if fog != null:
		fog.set_all_visible_temporary(map_controller.current_fog_faction_id)
	print("[Fog] Set all VISIBLE for faction %d" % map_controller.current_fog_faction_id)
	map_controller.mark_fog_dirty()


func reset_exploration() -> void:
	## 重置全部探索 → 清空 → 重新揭示主城周围
	print("[Fog] Reset exploration")
	if map_controller.map_data != null and map_controller.map_data.fog_data != null:
		map_controller.map_data.fog_data.reset_all(map_controller.current_fog_faction_id)
	map_controller.reveal_initial_vision()


func reveal_at_cursor(grid_position: Vector2i, radius: int) -> void:
	## 以命中格子为中心揭示指定半径
	map_controller.reveal_area(grid_position, radius)


func set_visible_at_cursor(grid_position: Vector2i, radius: int) -> void:
	## 以命中格子为中心设置当前 VISIBLE 区域
	map_controller.set_visible_area(grid_position, radius)


func _emit_fog_state() -> void:
	var fog := map_controller.map_data.fog_data if map_controller.map_data != null else null
	if fog == null:
		return
	_clear_selection_if_hidden_by_fog()
	fog_state_changed.emit(
		fog.get_explored_ratio(),
		fog.get_visible_count(),
		fog.get_unknown_count()
	)


## 只复核表现层选中状态，不修改迷雾数据；对象回到 UNKNOWN 后立即移除高亮。
func _clear_selection_if_hidden_by_fog() -> void:
	var selected_grid: Variant = null
	if not _selected_building_id.is_empty() and building_manager != null:
		var building := building_manager.get_building_by_id(_selected_building_id)
		if building != null:
			selected_grid = building.origin_cell
	elif not _selected_city_id.is_empty():
		var city := map_controller.get_city_by_id(_selected_city_id)
		if city != null:
			selected_grid = city.grid_position
	elif not _selected_resource_id.is_empty():
		var resource_point := map_controller.get_resource_by_id(_selected_resource_id)
		if resource_point != null:
			selected_grid = resource_point.grid_position
	elif _selection_marker != null and _selection_marker.visible:
		selected_grid = last_hit_grid
	if selected_grid != null and not _is_grid_object_visible(selected_grid as Vector2i):
		clear_selection()
