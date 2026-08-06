extends Control

const RESOURCE_BAR_SCENE := preload("res://ui/components/resource_bar.tscn")
const TASK_PANEL_SCENE := preload("res://ui/components/task_panel.tscn")
const MAP_AREA_SCENE := preload("res://ui/components/map_area.tscn")
const WIDE_LAYOUT_MIN_WIDTH := 1440.0

const PRIMARY_ROUTES: Array[Dictionary] = [
	{"label": "城池", "route": "city"},
	{"label": "武将", "route": "generals"},
	{"label": "联盟", "route": "alliance"},
	{"label": "路线", "route": "route"},
	{"label": "军令", "route": "battle"},
]
const MORE_ROUTES: Array[Dictionary] = [
	{"label": "全服事件", "route": "world_event"},
	{"label": "赛季结算", "route": "season"},
	{"label": "NPC 对话", "route": "npc"},
	{"label": "流亡", "route": "exile"},
	{"label": "复兴", "route": "revival"},
	{"label": "反攻", "route": "counterattack"},
	{"label": "UI 演示", "route": "ui_demo"},
	{"label": "设置", "route": "settings"},
]

var _map_area: MapArea
var _resource_bar: ResourceBar
var _task_panel: TaskPanel
var _task_toggle: Button
var _status_panel: PanelContainer
var _status_grid: GridContainer
var _more_panel: PanelContainer

# 旧选择抽屉（保留兼容）
var _selection_panel: PanelContainer
var _selection_title: Label
var _selection_details: Label

var _identity_label: Label
var _safe: SafeAreaContainer
var _current_selection: Dictionary = {}
var _task_drawer_requested := false

# 行动菜单系统
var _interaction_panel: MapInteractionPanel
var _action_resolver: MapActionResolver
var _interaction_service: DemoInteractionService
var _player_context: DemoPlayerContext

# 功能页面本地覆盖层（避免通过 NavigationManager 重新加载主场景）
var _feature_page_container: Control
var _feature_page: Control = null
var _is_showing_feature_page := false


func _ready() -> void:
	# 初始化阵营上下文
	_player_context = DemoPlayerContext.new()

	# 初始化行动系统（解析器 + Demo 桥接）
	_action_resolver = MapActionResolver.new()
	_action_resolver.set_player_context(_player_context)
	_action_resolver.set_demo_mode(true)
	_interaction_service = DemoInteractionService.new()

	# 阵营切换时刷新当前行动
	_player_context.faction_changed.connect(_on_player_faction_changed)
	_player_context.faction_id_changed.connect(_on_player_faction_id_changed)

	_build_ui()
	_connect_mock_signals()
	_refresh_all()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	call_deferred("_apply_responsive_layout")


func _exit_tree() -> void:
	if get_viewport() != null and get_viewport().size_changed.is_connected(_apply_responsive_layout):
		get_viewport().size_changed.disconnect(_apply_responsive_layout)
	if MockData.resources_changed.is_connected(_on_resources_changed):
		MockData.resources_changed.disconnect(_on_resources_changed)
	if MockData.tasks_changed.is_connected(_on_tasks_changed):
		MockData.tasks_changed.disconnect(_on_tasks_changed)
	if MockData.selected_server_changed.is_connected(_on_selected_server_changed):
		MockData.selected_server_changed.disconnect(_on_selected_server_changed)
	# 清理功能页面引用
	if _feature_page != null and is_instance_valid(_feature_page):
		_feature_page.queue_free()
	_feature_page = null
	_is_showing_feature_page = false


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("11130f")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_safe = SafeAreaContainer.new()
	_safe.minimum_safe_padding = 14
	add_child(_safe)
	_map_area = MAP_AREA_SCENE.instantiate() as MapArea
	_map_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_area.set_player_context(_player_context)
	_safe.add_child(_map_area)
	_map_area.selection_changed.connect(_on_map_selection_changed)
	_map_area.selection_cleared.connect(_on_map_selection_cleared)
	_map_area.map_load_failed.connect(_on_map_load_failed)

	var overlay := Control.new()
	overlay.name = "HUDOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe.add_child(overlay)

	_build_command_bar(overlay)
	_build_task_drawer(overlay)
	_build_bottom_navigation(overlay)
	_build_status_panel(overlay)
	_build_more_panel(overlay)
	_build_selection_panel(overlay)
	_build_interaction_panel(overlay)
	_build_feature_page_container(overlay)


func _build_command_bar(parent: Control) -> void:
	var command_bar := PanelContainer.new()
	command_bar.name = "CommandBar"
	command_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	command_bar.offset_bottom = 80
	parent.add_child(command_bar)
	var row := HBoxContainer.new()
	UIBuilder.set_box_spacing(row, 10)
	command_bar.add_child(row)
	_identity_label = UIBuilder.make_label("执棋者\n桃园结义 · 流畅", 16, UIBuilder.COLOR_TEXT)
	_identity_label.custom_minimum_size.x = 178
	_identity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_identity_label)
	var divider := VSeparator.new()
	row.add_child(divider)
	_resource_bar = RESOURCE_BAR_SCENE.instantiate() as ResourceBar
	_resource_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resource_bar.more_status_requested.connect(_toggle_status_panel)
	row.add_child(_resource_bar)


func _build_task_drawer(parent: Control) -> void:
	_task_toggle = UIBuilder.make_button("任务", 76)
	_task_toggle.name = "TaskToggle"
	_task_toggle.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_task_toggle.position = Vector2(10, 92)
	_task_toggle.custom_minimum_size = Vector2(76, 56)
	_task_toggle.pressed.connect(_toggle_task_drawer)
	parent.add_child(_task_toggle)

	_task_panel = TASK_PANEL_SCENE.instantiate() as TaskPanel
	_task_panel.name = "TaskDrawer"
	_task_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_task_panel.offset_left = 0
	_task_panel.offset_top = 92
	_task_panel.offset_right = 352
	_task_panel.offset_bottom = -78
	_task_panel.task_details_requested.connect(_show_task_details)
	_task_panel.tracking_toggled.connect(MockData.toggle_task_tracking)
	parent.add_child(_task_panel)


func _build_bottom_navigation(parent: Control) -> void:
	var nav_panel := PanelContainer.new()
	nav_panel.name = "BottomNavigation"
	nav_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	nav_panel.offset_top = -68
	parent.add_child(nav_panel)
	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	UIBuilder.set_box_spacing(nav, 8)
	nav_panel.add_child(nav)
	for route_data in PRIMARY_ROUTES:
		_add_route_button(nav, str(route_data.label), str(route_data.route), true)
	var more_button := UIBuilder.make_button("更多", 96)
	more_button.custom_minimum_size.y = 56
	more_button.pressed.connect(_toggle_more_panel)
	nav.add_child(more_button)


func _build_status_panel(parent: Control) -> void:
	_status_panel = UIBuilder.make_panel(18)
	_status_panel.name = "StatusPanel"
	_status_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_status_panel.offset_left = -438
	_status_panel.offset_top = 92
	_status_panel.offset_right = -88
	_status_panel.offset_bottom = 448
	_status_panel.visible = false
	parent.add_child(_status_panel)
	var content := VBoxContainer.new()
	UIBuilder.set_box_spacing(content, 10)
	_status_panel.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := UIBuilder.make_label("军府状态", 22, UIBuilder.COLOR_ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := UIBuilder.make_button("关闭", 82)
	close.text = "×"
	close.tooltip_text = "关闭状态面板"
	close.custom_minimum_size.x = 56
	close.custom_minimum_size.y = 56
	close.pressed.connect(_toggle_status_panel)
	header.add_child(close)
	_status_grid = GridContainer.new()
	_status_grid.columns = 2
	_status_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_status_grid.add_theme_constant_override("h_separation", 24)
	_status_grid.add_theme_constant_override("v_separation", 12)
	content.add_child(_status_grid)


func _build_more_panel(parent: Control) -> void:
	_more_panel = UIBuilder.make_panel(14)
	_more_panel.name = "MoreMenu"
	_more_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_more_panel.offset_left = -452
	_more_panel.offset_top = -330
	_more_panel.offset_right = -10
	_more_panel.offset_bottom = -78
	_more_panel.visible = false
	parent.add_child(_more_panel)
	var content := VBoxContainer.new()
	UIBuilder.set_box_spacing(content, 8)
	_more_panel.add_child(content)
	var title := UIBuilder.make_label("其他事务", 20, UIBuilder.COLOR_ACCENT)
	content.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	content.add_child(grid)
	for route_data in MORE_ROUTES:
		_add_route_button(grid, str(route_data.label), str(route_data.route), true)


func _build_selection_panel(parent: Control) -> void:
	_selection_panel = UIBuilder.make_panel(16)
	_selection_panel.name = "SelectionDrawer"
	_selection_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_selection_panel.offset_left = -390
	_selection_panel.offset_top = -124
	_selection_panel.offset_right = 390
	_selection_panel.offset_bottom = -78
	_selection_panel.visible = false
	parent.add_child(_selection_panel)
	var row := HBoxContainer.new()
	UIBuilder.set_box_spacing(row, 14)
	_selection_panel.add_child(row)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIBuilder.set_box_spacing(text_box, 4)
	row.add_child(text_box)
	_selection_title = UIBuilder.make_label("已选目标", 21, UIBuilder.COLOR_ACCENT)
	text_box.add_child(_selection_title)
	_selection_details = UIBuilder.make_label("", 16, UIBuilder.COLOR_MUTED, true)
	text_box.add_child(_selection_details)
	var close := UIBuilder.make_button("关闭", 82)
	close.text = "×"
	close.tooltip_text = "关闭选择详情"
	close.custom_minimum_size.x = 56
	close.pressed.connect(_clear_map_selection)
	row.add_child(close)


func _build_interaction_panel(parent: Control) -> void:
	_interaction_panel = MapInteractionPanel.new()
	_interaction_panel.name = "MapInteractionPanel"
	_interaction_panel.configure(_action_resolver, _interaction_service)
	_interaction_panel.panel_closed.connect(_on_interaction_panel_closed)
	parent.add_child(_interaction_panel)


func _build_feature_page_container(parent: Control) -> void:
	## 构建功能页面本地覆盖层容器（全屏，位于所有 UI 之上）
	_feature_page_container = Control.new()
	_feature_page_container.name = "FeaturePageContainer"
	_feature_page_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_feature_page_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_feature_page_container.visible = false
	parent.add_child(_feature_page_container)


## 关闭当前功能页面并恢复 HUD 显示
func _close_feature_page() -> void:
	if _feature_page != null and is_instance_valid(_feature_page):
		_feature_page.queue_free()
		_feature_page = null
	_feature_page_container.visible = false
	_is_showing_feature_page = false


## 查找并重连功能页面中的"返回主界面"按钮，避免调用 NavigationManager 导致主场景重载
func _patch_back_button(page: Control) -> void:
	var buttons: Array[Node] = page.find_children("", "Button", true, false)
	for child in buttons:
		if child is Button and child.text == "返回主界面":
			# 断开现有的所有连接
			for conn in child.pressed.get_connections():
				child.pressed.disconnect(conn["callable"])
			# 连接到本地的关闭方法
			child.pressed.connect(_close_feature_page)
			break


func _add_route_button(parent: Container, label: String, route: String, expand: bool = false) -> void:
	var button := UIBuilder.make_button(label, 0)
	button.custom_minimum_size.y = 56
	if expand:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_open_route.bind(route))
	parent.add_child(button)


func _open_route(route: String) -> void:
	## 在本地覆盖层中显示功能页面，不通过 NavigationManager 重新加载主场景
	_more_panel.visible = false
	# Dictionary.get() 返回 Variant，需要显式声明类型
	var path: String = str(NavigationManager.ROUTES.get(route, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		NavigationManager.show_message("功能暂不可用", "目标页面缺失。")
		return
	var packed_scene: PackedScene = load(path) as PackedScene
	if packed_scene == null:
		NavigationManager.show_error("页面加载失败", "无法读取功能页面：%s" % route)
		return
	# 移除旧页面（如果存在）
	if _feature_page != null and is_instance_valid(_feature_page):
		_feature_page.queue_free()
		_feature_page = null
	# 实例化新页面到本地覆盖层
	var page: Node = packed_scene.instantiate()
	_feature_page_container.add_child(page)
	_feature_page_container.visible = true
	_feature_page = page
	_is_showing_feature_page = true
	# 重连页面中的"返回主界面"按钮到本地关闭方法
	_patch_back_button(page)


func _apply_responsive_layout() -> void:
	if _task_panel == null:
		return
	var window_width := float(DisplayServer.window_get_size().x)
	var wide_layout := window_width >= WIDE_LAYOUT_MIN_WIDTH
	_task_panel.visible = wide_layout or _task_drawer_requested
	_task_toggle.visible = not wide_layout
	if _selection_panel != null:
		var available_width := maxf(320.0, get_viewport_rect().size.x - 72.0)
		var drawer_width := minf(780.0, available_width)
		_selection_panel.offset_left = -drawer_width * 0.5
		_selection_panel.offset_right = drawer_width * 0.5
	if _interaction_panel != null:
		_interaction_panel._apply_responsive_layout()


func _toggle_task_drawer() -> void:
	_task_drawer_requested = not _task_drawer_requested
	_task_panel.visible = _task_drawer_requested


func _toggle_status_panel() -> void:
	_status_panel.visible = not _status_panel.visible
	_more_panel.visible = false
	if _status_panel.visible:
		_refresh_status_panel()


func _toggle_more_panel() -> void:
	_more_panel.visible = not _more_panel.visible
	_status_panel.visible = false


func _refresh_all() -> void:
	_refresh_identity()
	_resource_bar.set_resources(MockData.get_resources())
	_task_panel.set_tasks(MockData.get_tasks())
	_refresh_status_panel()


func _refresh_identity() -> void:
	var server: Dictionary = MockData.get_selected_server()
	_identity_label.text = "%s\n%s · %s" % [
		MockData.get_identity(),
		server.get("name", "未选服务器"),
		server.get("status", "未知"),
	]


func _refresh_status_panel() -> void:
	for child in _status_grid.get_children():
		child.queue_free()
	var statuses: Dictionary = MockData.get_statuses()
	for status_name in statuses:
		_status_grid.add_child(UIBuilder.make_label(str(status_name), 16, UIBuilder.COLOR_MUTED))
		var value_label := UIBuilder.make_label(str(statuses[status_name]), 17, UIBuilder.COLOR_TEXT)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_status_grid.add_child(value_label)


func _connect_mock_signals() -> void:
	if not MockData.resources_changed.is_connected(_on_resources_changed):
		MockData.resources_changed.connect(_on_resources_changed)
	if not MockData.tasks_changed.is_connected(_on_tasks_changed):
		MockData.tasks_changed.connect(_on_tasks_changed)
	if not MockData.selected_server_changed.is_connected(_on_selected_server_changed):
		MockData.selected_server_changed.connect(_on_selected_server_changed)


func _on_resources_changed(resources: Dictionary, changes: Dictionary) -> void:
	_resource_bar.set_resources(resources, changes)
	_refresh_status_panel()


func _on_tasks_changed(tasks: Array[Dictionary]) -> void:
	_task_panel.set_tasks(tasks)


func _on_selected_server_changed(_server: Dictionary) -> void:
	_refresh_identity()


func _on_map_selection_changed(selection: Dictionary) -> void:
	_current_selection = selection.duplicate(true)
	# 不再显示底层 _selection_panel，统一由 MapInteractionPanel 显示所有信息
	# 构建统一交互上下文并显示行动菜单
	var ctx: MapInteractionContext = _build_interaction_context(selection)
	if ctx != null and _interaction_panel != null:
		_interaction_panel.show_for_context(ctx)


func _on_map_selection_cleared() -> void:
	_current_selection.clear()
	_selection_panel.visible = false
	if _interaction_panel != null:
		_interaction_panel.hide_panel()


func _on_interaction_panel_closed() -> void:
	pass  # 面板已关闭，其他无需联动


func _on_player_faction_changed(_previous: StringName, current: StringName) -> void:
	_identity_label.text = "%s\n桃园结义 · 流畅" % DemoPlayerContext.get_faction_display_name(current)
	if _interaction_panel != null and _interaction_panel.get_current_context() != null:
		_interaction_panel.refresh_actions()


func _on_player_faction_id_changed(_previous_faction_id: int, _current_faction_id: int) -> void:
	## 阵营 ID 变更时刷新交互面板（确保主城敌我判断等正确更新）
	if _interaction_panel != null and _interaction_panel.get_current_context() != null:
		_interaction_panel.refresh_actions()


func _build_interaction_context(selection: Dictionary) -> MapInteractionContext:
	if selection.is_empty():
		return null
	var map_world := _map_area.get_map_world()
	var map_data := map_world.get_map_controller().map_data if map_world != null else null
	var selection_kind := str(selection.get("kind", ""))
	match selection_kind:
		"city":
			return MapInteractionContext.from_city_snapshot(selection, map_data)
		"resource":
			return MapInteractionContext.from_resource_snapshot(selection, map_data)
		_:
			return MapInteractionContext.from_tile_snapshot(selection, map_data)


func _clear_map_selection() -> void:
	var map_world := _map_area.get_map_world()
	if map_world != null:
		map_world.clear_selection()
	else:
		_on_map_selection_cleared()


func _on_map_load_failed(message: String) -> void:
	NavigationManager.show_message("地图暂不可用", "%s\n\n其他军府功能仍可继续使用。" % message)


func _show_task_details(task: Dictionary) -> void:
	var tracked_text := "已追踪" if bool(task.get("tracked", false)) else "未追踪"
	NavigationManager.show_message(
		str(task.get("title", "任务详情")),
		"%s\n\n进度：%d / %d\n状态：%s · %s" % [
			task.get("description", "暂无描述"),
			int(task.get("current", 0)),
			int(task.get("target", 0)),
			task.get("status", "进行中"),
			tracked_text,
		]
	)
