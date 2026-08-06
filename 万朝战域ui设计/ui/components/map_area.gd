class_name MapArea
extends Control

signal map_ready
signal map_load_failed(message: String)
signal selection_changed(selection: Dictionary)
signal selection_cleared
signal fog_state_changed(explored_ratio: float, visible_count: int, unknown_count: int)
signal scout_requested(tile_id: Vector2i)
signal view_mode_changed(mode: int, display_name: String)

@export_file("*.tscn") var map_scene_path := "res://map/map_world.tscn"

@onready var _placeholder_background: ColorRect = $PlaceholderBackground
@onready var _placeholder_label: Label = $PlaceholderLabel
@onready var _input_anchor: MapInputAnchor = $MapViewportContainer
@onready var _map_viewport: SubViewport = $MapViewportContainer/MapViewport
@onready var _zoom_in_button: Button = $MapUILayer/MapTools/ZoomIn
@onready var _zoom_out_button: Button = $MapUILayer/MapTools/ZoomOut
@onready var _view_mode_button: Button = $MapUILayer/MapTools/ToggleViewMode
@onready var _reset_button: Button = $MapUILayer/MapTools/ResetView
@onready var _scout_indicator: Label = $MapUILayer/ScoutIndicator

var _map_world: MapWorld
var _scout_indicator_timer: SceneTreeTimer
var _player_context: DemoPlayerContext = null


func _ready() -> void:
	_zoom_in_button.pressed.connect(zoom_in)
	_zoom_out_button.pressed.connect(zoom_out)
	_view_mode_button.pressed.connect(toggle_view_mode)
	_reset_button.pressed.connect(reset_view)
	call_deferred("_load_map_world")


func zoom_in() -> void:
	if _map_world != null:
		_map_world.zoom_by_factor(1.25, Vector2(_map_viewport.size))


func zoom_out() -> void:
	if _map_world != null:
		_map_world.zoom_by_factor(0.8, Vector2(_map_viewport.size))


func reset_view() -> void:
	if _map_world != null:
		_map_world.reset_view(Vector2(_map_viewport.size))


func toggle_view_mode() -> void:
	if _map_world != null:
		_map_world.toggle_view_mode(Vector2(_map_viewport.size))


func get_map_world() -> MapWorld:
	return _map_world


func set_player_context(ctx: DemoPlayerContext) -> void:
	_player_context = ctx


func _load_map_world() -> void:
	if not ResourceLoader.exists(map_scene_path, "PackedScene"):
		_fail_map_load("地图场景不存在：%s" % map_scene_path)
		return
	var packed_scene := load(map_scene_path) as PackedScene
	if packed_scene == null:
		_fail_map_load("地图场景无法读取：%s" % map_scene_path)
		return
	var instance := packed_scene.instantiate()
	if not instance is MapWorld:
		instance.queue_free()
		_fail_map_load("地图场景根节点必须是 MapWorld")
		return
	_map_world = instance as MapWorld
	_map_world.map_ready.connect(_on_map_ready)
	_map_world.city_selected.connect(_on_city_selected)
	_map_world.resource_selected.connect(_on_resource_selected)
	_map_world.tile_selected.connect(_on_tile_selected)
	_map_world.selection_cleared.connect(_on_selection_cleared)
	_map_world.view_mode_changed.connect(_on_view_mode_changed)
	_map_world.scout_requested.connect(_on_scout_requested)
	_map_world.fog_state_changed.connect(_on_fog_state_changed)
	_map_viewport.add_child(_map_world)
	_input_anchor.set_map_world(_map_world)
	_set_placeholder_visible(false)
	_update_view_mode_button(_map_world.get_view_mode_display_name())
	_scout_indicator.visible = false


func _fail_map_load(message: String) -> void:
	push_warning(message)
	_placeholder_label.text = "地图暂不可用"
	_set_placeholder_visible(true)
	map_load_failed.emit(message)


func _set_placeholder_visible(visible_state: bool) -> void:
	_placeholder_background.visible = visible_state
	_placeholder_label.visible = visible_state


func _on_map_ready() -> void:
	if debug_panel_enabled:
		_spawn_v3_debug_panel()
	map_ready.emit()


## 调试面板：开发期间开启，后期删除此行及 _spawn_v3_debug_panel()。
@export var debug_panel_enabled: bool = true


func _spawn_v3_debug_panel() -> void:
	var panel := V3DebugPanel.new()
	panel.name = "V3DebugPanel"
	$MapUILayer.add_child(panel)
	panel.configure(_map_world, _map_world.get_map_controller(), _player_context)
	# 各信号参数个数不同，用 bind 传入 panel 引用再调用 _refresh_hit_info
	_map_world.city_selected.connect(_on_debug_city.bind(panel))
	_map_world.tile_selected.connect(_on_debug_tile.bind(panel))
	_map_world.resource_selected.connect(_on_debug_resource.bind(panel))
	_map_world.view_mode_changed.connect(_on_debug_view_mode.bind(panel))


func _on_debug_city(_city_id: String, _tile_id: Vector2i, panel: V3DebugPanel) -> void:
	panel._refresh_hit_info()


func _on_debug_tile(_tile_id: Vector2i, panel: V3DebugPanel) -> void:
	panel._refresh_hit_info()


func _on_debug_resource(_resource_id: String, _tile_id: Vector2i, panel: V3DebugPanel) -> void:
	panel._refresh_hit_info()


func _on_debug_view_mode(_mode: int, _display_name: String, panel: V3DebugPanel) -> void:
	panel._refresh_hit_info()


func _on_city_selected(city_id: String, _tile_id: Vector2i) -> void:
	var snapshot := _map_world.get_city_snapshot(city_id)
	if not snapshot.is_empty():
		selection_changed.emit(snapshot)


func _on_tile_selected(tile_id: Vector2i) -> void:
	var snapshot := _map_world.get_tile_snapshot(tile_id)
	if not snapshot.is_empty():
		selection_changed.emit(snapshot)


func _on_resource_selected(resource_id: String, _tile_id: Vector2i) -> void:
	var snapshot := _map_world.get_resource_snapshot(resource_id)
	if not snapshot.is_empty():
		selection_changed.emit(snapshot)


func _on_selection_cleared() -> void:
	selection_cleared.emit()


func _on_view_mode_changed(mode: int, display_name: String) -> void:
	_update_view_mode_button(display_name)
	view_mode_changed.emit(mode, display_name)


func _on_scout_requested(tile_id: Vector2i) -> void:
	## 显示侦察请求反馈，不实现正式侦察逻辑
	scout_requested.emit(tile_id)
	if _scout_indicator != null:
		_scout_indicator.text = "侦察目标: %s" % tile_id
		_scout_indicator.visible = true
	if _scout_indicator_timer != null:
		_scout_indicator_timer.timeout.disconnect(_hide_scout_indicator)
	var tree := get_tree()
	if tree != null:
		_scout_indicator_timer = tree.create_timer(1.5)
		_scout_indicator_timer.timeout.connect(_hide_scout_indicator, CONNECT_ONE_SHOT)


func _on_fog_state_changed(explored_ratio: float, visible_count: int, unknown_count: int) -> void:
	fog_state_changed.emit(explored_ratio, visible_count, unknown_count)


func _hide_scout_indicator() -> void:
	if _scout_indicator != null:
		_scout_indicator.visible = false


func _update_view_mode_button(display_name: String) -> void:
	_view_mode_button.text = display_name
	_view_mode_button.tooltip_text = "临时调试按钮：切换经营 3D / 战争 2.5D"
