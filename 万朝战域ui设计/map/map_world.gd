class_name MapWorld
extends Node3D

enum MapInitState {
	NOT_STARTED,   ## 尚未开始初始化
	GENERATING,    ## 正在生成地图数据
	INITIALIZING,  ## 正在初始化 Chunk / 相机 / 实体
	READY,         ## 初始化完成，可处理输入
	FAILED,        ## 初始化失败
}

signal map_ready
signal tile_selected(tile_id: Vector2i)
signal city_selected(city_id: String, tile_id: Vector2i)
signal resource_selected(resource_id: String, tile_id: Vector2i)
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

var _selection_marker: MeshInstance3D
var _selected_city_id := ""
var _selected_resource_id := ""


func _ready() -> void:
	init_state = MapInitState.INITIALIZING
	_ensure_environment()
	_ensure_lighting()
	_build_selection_marker()
	map_input_controller.setup(camera_rig, self)
	camera_rig.view_mode_changed.connect(_on_view_mode_changed)
	map_controller.map_ready.connect(_on_map_ready)
	map_controller.fog_changed.connect(_emit_fog_state)
	map_controller.initialize(camera_rig, chunk_root, entity_root)
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
	var city := map_controller.get_city_at_grid(grid_position)
	if city != null:
		_select_city(city)
		return
	var resource_point := map_controller.get_resource_at_grid(grid_position)
	if resource_point != null:
		_select_resource(resource_point)
	else:
		_select_tile(grid_position)


func request_scout_at_viewport_position(viewport_position: Vector2) -> void:
	## 发出中立侦察请求。地图只做格子拾取，不实现正式侦察逻辑。
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
	scout_requested.emit(grid_position)


func clear_selection() -> void:
	_selected_city_id = ""
	_selected_resource_id = ""
	map_controller.set_selected_city("")
	_selection_marker.visible = false
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
	snapshot["selection_visible"] = _selection_marker.visible
	return snapshot


func _select_city(city: MapCityData) -> void:
	_selected_city_id = city.city_id
	_selected_resource_id = ""
	map_controller.set_selected_city(city.city_id)
	_place_selection_marker(city.grid_position, true)
	last_hit_grid = city.grid_position
	city_selected.emit(city.city_id, city.grid_position)


func _select_resource(resource_point: MapResourcePointData) -> void:
	_selected_city_id = ""
	_selected_resource_id = resource_point.resource_id
	map_controller.set_selected_city("")
	_place_selection_marker(resource_point.grid_position, false, Vector2i(3, 3))
	last_hit_grid = resource_point.grid_position
	resource_selected.emit(resource_point.resource_id, resource_point.grid_position)


func _select_tile(grid_position: Vector2i) -> void:
	_selected_city_id = ""
	_selected_resource_id = ""
	map_controller.set_selected_city("")
	_place_selection_marker(grid_position, false)
	last_hit_grid = grid_position
	tile_selected.emit(grid_position)


func _place_selection_marker(
	grid_position: Vector2i,
	is_city: bool,
	requested_footprint: Vector2i = Vector2i.ONE
) -> void:
	var marker_grid_position := grid_position
	var footprint_size := requested_footprint
	if is_city:
		var city := map_controller.get_city_at_grid(grid_position)
		if city != null:
			marker_grid_position = city.grid_position
			footprint_size = city.footprint_size
	_selection_marker.position = map_controller.map_data.grid_to_world(
		marker_grid_position,
		map_controller.map_data.get_surface_height_at_grid(marker_grid_position) + 0.08
	)
	_selection_marker.scale = Vector3(
		float(footprint_size.x),
		1.0,
		float(footprint_size.y)
	)
	_selection_marker.visible = true


func _build_selection_marker() -> void:
	_selection_marker = MeshInstance3D.new()
	_selection_marker.name = "SelectionMarker"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.82, 0.04, 1.82)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.72, 0.25, 0.58)
	material.emission_enabled = true
	material.emission = Color(0.95, 0.62, 0.18)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	_selection_marker.mesh = mesh
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
	fog_state_changed.emit(
		fog.get_explored_ratio(),
		fog.get_visible_count(),
		fog.get_unknown_count()
	)
