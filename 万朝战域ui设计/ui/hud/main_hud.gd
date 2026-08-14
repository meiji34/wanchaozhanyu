extends Control

const RESOURCE_BAR_SCENE := preload("res://ui/components/resource_bar.tscn")
const TASK_PANEL_SCENE := preload("res://ui/components/task_panel.tscn")
const MAP_AREA_SCENE := preload("res://ui/components/map_area.tscn")
const WIDE_LAYOUT_MIN_WIDTH := 1440.0
const DEFAULT_BUILD_ROTATION_INDEX := 0

@export_range(0.0, 1.0, 0.01) var selection_preview_rotation_speed := 0.22

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
var _deployment_panel: DeploymentPanel
var _deployment_service: DemoDeploymentService

# 功能页面本地覆盖层（避免通过 NavigationManager 重新加载主场景）
var _feature_page_container: Control
var _feature_page: Control = null
var _is_showing_feature_page := false

# 建造模式 UI（按钮 + 确认/取消面板，均复用 UIBuilder 现有样式）
var _build_button: Button
var _build_panel: PanelContainer
var _build_title_label: Label
var _build_reason_label: Label
var _build_confirm_button: Button
var _build_rotate_button: Button

# 建筑选择栏（建筑列表 + 纯展示 3D 预览 + 开始建造）
var _build_select_panel: PanelContainer
var _building_catalog: Array[MapBuildingDefinition] = []
var _building_option_buttons: Array[Button] = []
var _selected_building_index := 0
var _select_preview_root: Node3D
var _select_preview_mesh: MeshInstance3D

# 土地平整面板（目标高度 / 范围 / 确认取消，复用 UIBuilder 样式）
var _flatten_panel: PanelContainer
var _flatten_reason_label: Label
var _flatten_height_label: Label
var _flatten_width_label: Label
var _flatten_length_label: Label
var _flatten_duration_label: Label
var _flatten_confirm_button: Button
var _flatten_reselect_button: Button


func _ready() -> void:
	# 初始化阵营上下文
	_player_context = DemoPlayerContext.new()

	# 初始化行动系统（解析器 + Demo 桥接）
	_action_resolver = MapActionResolver.new()
	_action_resolver.set_player_context(_player_context)
	_action_resolver.set_demo_mode(true)
	_interaction_service = DemoInteractionService.new()
	_deployment_service = DemoDeploymentService.new()
	_deployment_service.configure(MockData.get_resources, MockData.submit_deployment, _get_current_faction_id)

	# 阵营切换时刷新当前行动
	_player_context.faction_changed.connect(_on_player_faction_changed)
	_player_context.faction_id_changed.connect(_on_player_faction_id_changed)

	_build_ui()
	_connect_mock_signals()
	_refresh_all()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	call_deferred("_apply_responsive_layout")


func _process(delta: float) -> void:
	# 选择栏旋转只作用于独立展示根节点，不读取或写入任何建造方向数据。
	if (
		_build_select_panel != null
		and _build_select_panel.visible
		and _select_preview_root != null
		and is_instance_valid(_select_preview_root)
	):
		_select_preview_root.rotate_y(selection_preview_rotation_speed * delta)


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
	_map_area.build_mode_changed.connect(_on_build_mode_changed)
	_map_area.placement_state_changed.connect(_on_build_placement_state_changed)
	_map_area.building_placed.connect(_on_building_placed)
	_map_area.flatten_mode_changed.connect(_on_flatten_mode_changed)
	_map_area.flatten_state_changed.connect(_on_flatten_state_changed)
	_map_area.terrain_flattened.connect(_on_terrain_flattened)

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
	_build_deployment_panel(overlay)
	_build_construction_panel(overlay)
	_build_building_select_panel(overlay)
	_build_flatten_panel(overlay)
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
	# 建造入口：与主导航按钮同一组件、同一尺寸规则
	_build_button = UIBuilder.make_button("建造", 96)
	_build_button.custom_minimum_size.y = 56
	_build_button.tooltip_text = "进入建造模式"
	_build_button.pressed.connect(_toggle_build_mode)
	nav.add_child(_build_button)
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
	_interaction_panel.action_executed.connect(_on_map_action_executed)
	# 删除建筑走真实业务链路：桥接层 → MapArea → MapWorld → MapBuildingManager
	_interaction_service.set_delete_building_handler(Callable(_map_area, "request_delete_building"))
	# 路线预览走真实业务链路：桥接层 → MapArea → MapWorld（寻路 + 格子高亮）
	_interaction_service.set_route_preview_handler(Callable(_map_area, "request_route_preview"))
	parent.add_child(_interaction_panel)


func _build_deployment_panel(parent: Control) -> void:
	_deployment_panel = DeploymentPanel.new()
	_deployment_panel.name = "DeploymentPanel"
	_deployment_panel.configure(_deployment_service)
	_deployment_panel.panel_closed.connect(_on_deployment_panel_closed)
	parent.add_child(_deployment_panel)


## 建造模式面板：标题 + 合法性提示 + 旋转/确认/取消，样式复用 UIBuilder 与现有弹层规范
func _build_construction_panel(parent: Control) -> void:
	_build_panel = UIBuilder.make_panel(16)
	_build_panel.name = "ConstructionPanel"
	_build_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_build_panel.offset_left = -390
	_build_panel.offset_top = -240
	_build_panel.offset_right = 390
	_build_panel.offset_bottom = -140
	_build_panel.visible = false
	parent.add_child(_build_panel)
	var content := VBoxContainer.new()
	UIBuilder.set_box_spacing(content, 8)
	_build_panel.add_child(content)
	_build_title_label = UIBuilder.make_label("建造", 20, UIBuilder.COLOR_ACCENT)
	content.add_child(_build_title_label)
	_build_reason_label = UIBuilder.make_label("点击地图格子选择建造位置", 15, UIBuilder.COLOR_MUTED, true)
	_build_reason_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_build_reason_label)
	var row := HBoxContainer.new()
	UIBuilder.set_box_spacing(row, 12)
	content.add_child(row)
	# 旋转按钮：移动端可触摸，与确认/取消同一样式；PREVIEW / LOCKED 状态均可用
	_build_rotate_button = UIBuilder.make_button("旋转", 140)
	_build_rotate_button.tooltip_text = "旋转建筑方向（0°→90°→180°→270°）"
	_build_rotate_button.pressed.connect(_on_build_rotate_pressed)
	row.add_child(_build_rotate_button)
	_build_confirm_button = UIBuilder.make_primary_button("确认", 140)
	_build_confirm_button.disabled = true
	_build_confirm_button.tooltip_text = "在当前预览位置放置建筑"
	_build_confirm_button.pressed.connect(_on_build_confirm_pressed)
	row.add_child(_build_confirm_button)
	var cancel := UIBuilder.make_button("取消", 140)
	cancel.tooltip_text = "退出建造模式"
	cancel.pressed.connect(_on_build_cancel_pressed)
	row.add_child(cancel)


## 建筑选择栏：建筑列表 + 自动旋转 3D 预览 + 开始建造。
## 仅做选择与展示，不参与地图占地、不注册 BuildingManager、不产生 building_id。
func _build_building_select_panel(parent: Control) -> void:
	_building_catalog = MapBuildingDefinition.get_building_catalog()
	_build_select_panel = UIBuilder.make_panel(16)
	_build_select_panel.name = "BuildingSelectPanel"
	_build_select_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_build_select_panel.offset_left = -360
	_build_select_panel.offset_top = -520
	_build_select_panel.offset_right = 360
	_build_select_panel.offset_bottom = -78
	_build_select_panel.visible = false
	parent.add_child(_build_select_panel)
	var content := VBoxContainer.new()
	UIBuilder.set_box_spacing(content, 10)
	_build_select_panel.add_child(content)
	var title := UIBuilder.make_label("选择建筑", 20, UIBuilder.COLOR_ACCENT)
	content.add_child(title)
	var body := HBoxContainer.new()
	UIBuilder.set_box_spacing(body, 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body)
	# 左列：建筑列表
	var left := VBoxContainer.new()
	UIBuilder.set_box_spacing(left, 8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	left.add_child(UIBuilder.make_label("建筑：", 16, UIBuilder.COLOR_MUTED))
	_building_option_buttons.clear()
	for i in range(_building_catalog.size()):
		var definition := _building_catalog[i]
		var button := UIBuilder.make_button(
			"%s（%d×%d×%d）" % [
				definition.display_name,
				definition.footprint_size.x,
				definition.footprint_size.y,
				definition.height_levels,
			],
			0
		)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_building_option_pressed.bind(i))
		left.add_child(button)
		_building_option_buttons.append(button)
	# 右列：3D 选择预览（纯展示，独立 SubViewport）
	var preview_container := SubViewportContainer.new()
	preview_container.name = "BuildingSelectPreview"
	preview_container.stretch = true
	preview_container.custom_minimum_size = Vector2(240, 180)
	preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(preview_container)
	var sub_viewport := SubViewport.new()
	sub_viewport.own_world_3d = true
	preview_container.add_child(sub_viewport)
	var camera := Camera3D.new()
	# look_at_from_position 在节点未入树时也可用（无窗口测试会直接构建 HUD）
	camera.look_at_from_position(Vector3(10.0, 9.0, 10.0), Vector3(0.0, 0.5, 0.0))
	sub_viewport.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sub_viewport.add_child(light)
	_select_preview_root = Node3D.new()
	_select_preview_root.name = "PreviewRoot"
	sub_viewport.add_child(_select_preview_root)
	_select_preview_mesh = MeshInstance3D.new()
	_select_preview_mesh.name = "SelectPreviewMesh"
	var preview_material := StandardMaterial3D.new()
	preview_material.albedo_color = MapBuildingManager.BUILDING_COLOR
	preview_material.roughness = 0.85
	var preview_box := BoxMesh.new()
	preview_box.material = preview_material
	_select_preview_mesh.mesh = preview_box
	_select_preview_root.add_child(_select_preview_mesh)
	# 底部：开始建造 / 平整土地 / 取消
	var action_row := HBoxContainer.new()
	UIBuilder.set_box_spacing(action_row, 12)
	content.add_child(action_row)
	var start_button := UIBuilder.make_primary_button("开始建造", 160)
	start_button.name = "StartBuildButton"
	start_button.tooltip_text = "按所选建筑进入地图建造"
	start_button.pressed.connect(_on_start_build_pressed)
	action_row.add_child(start_button)
	var flatten_button := UIBuilder.make_button("平整土地", 160)
	flatten_button.name = "FlattenTerrainButton"
	flatten_button.tooltip_text = "进入土地平整模式，将范围内土地统一到目标高度"
	flatten_button.pressed.connect(_on_flatten_terrain_pressed)
	action_row.add_child(flatten_button)
	var cancel_button := UIBuilder.make_button("取消", 160)
	cancel_button.tooltip_text = "关闭建筑选择栏"
	cancel_button.pressed.connect(_close_building_select_panel)
	action_row.add_child(cancel_button)


## 土地平整面板：目标高度等级 / 平整范围 / 预计耗时 / 确认取消。
## 只发出调整与确认命令，地形数据修改由地图系统完成。
func _build_flatten_panel(parent: Control) -> void:
	_flatten_panel = UIBuilder.make_panel(16)
	_flatten_panel.name = "FlattenPanel"
	_flatten_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_flatten_panel.offset_left = -360
	_flatten_panel.offset_top = -480
	_flatten_panel.offset_right = 360
	_flatten_panel.offset_bottom = -140
	_flatten_panel.visible = false
	parent.add_child(_flatten_panel)
	var content := VBoxContainer.new()
	UIBuilder.set_box_spacing(content, 8)
	_flatten_panel.add_child(content)
	var title := UIBuilder.make_label("平整土地", 20, UIBuilder.COLOR_ACCENT)
	content.add_child(title)
	_flatten_reason_label = UIBuilder.make_label("移动鼠标预览平整范围，左键点击锁定位置", 15, UIBuilder.COLOR_MUTED, true)
	content.add_child(_flatten_reason_label)
	_flatten_height_label = _build_flatten_adjuster_row(
		content, "目标高度：", _on_flatten_height_decreased, _on_flatten_height_increased,
		"降低目标高度等级", "提高目标高度等级"
	)
	_flatten_width_label = _build_flatten_adjuster_row(
		content, "平整宽度：", _on_flatten_width_decreased, _on_flatten_width_increased,
		"减少平整宽度", "增加平整宽度"
	)
	_flatten_length_label = _build_flatten_adjuster_row(
		content, "平整长度：", _on_flatten_length_decreased, _on_flatten_length_increased,
		"减少平整长度", "增加平整长度"
	)
	_flatten_duration_label = UIBuilder.make_label("预计耗时：0 秒（测试阶段）", 15, UIBuilder.COLOR_MUTED)
	content.add_child(_flatten_duration_label)
	var action_row := HBoxContainer.new()
	UIBuilder.set_box_spacing(action_row, 12)
	content.add_child(action_row)
	_flatten_confirm_button = UIBuilder.make_primary_button("确认平整", 160)
	_flatten_confirm_button.disabled = true
	_flatten_confirm_button.tooltip_text = "左键锁定位置后，将范围内土地统一调整到目标高度"
	_flatten_confirm_button.pressed.connect(_on_flatten_confirm_pressed)
	action_row.add_child(_flatten_confirm_button)
	_flatten_reselect_button = UIBuilder.make_button("重新选择", 160)
	_flatten_reselect_button.disabled = true
	_flatten_reselect_button.tooltip_text = "解除位置锁定，预览重新跟随鼠标"
	_flatten_reselect_button.pressed.connect(_on_flatten_reselect_pressed)
	action_row.add_child(_flatten_reselect_button)
	var cancel := UIBuilder.make_button("取消", 160)
	cancel.tooltip_text = "退出土地平整模式，不修改地形"
	cancel.pressed.connect(_on_flatten_cancel_pressed)
	action_row.add_child(cancel)


## 生成一行“标题 [-] 数值 [+]”调节器，返回数值 Label 供状态刷新
func _build_flatten_adjuster_row(
	parent: Control,
	title: String,
	decrease_handler: Callable,
	increase_handler: Callable,
	decrease_tooltip: String,
	increase_tooltip: String
) -> Label:
	var row := HBoxContainer.new()
	UIBuilder.set_box_spacing(row, 8)
	parent.add_child(row)
	var title_label := UIBuilder.make_label(title, 16, UIBuilder.COLOR_MUTED)
	title_label.custom_minimum_size.x = 110
	row.add_child(title_label)
	var decrease := UIBuilder.make_button("-", 56)
	decrease.tooltip_text = decrease_tooltip
	decrease.pressed.connect(decrease_handler)
	row.add_child(decrease)
	var value_label := UIBuilder.make_label("", 17, UIBuilder.COLOR_TEXT)
	value_label.custom_minimum_size.x = 150
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value_label)
	var increase := UIBuilder.make_button("+", 56)
	increase.tooltip_text = increase_tooltip
	increase.pressed.connect(increase_handler)
	row.add_child(increase)
	return value_label


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
	if _deployment_panel != null:
		_deployment_panel.apply_responsive_layout(get_viewport_rect().size)


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
	if _deployment_panel != null and _deployment_panel.visible:
		_deployment_panel.hide_panel()
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
	if _deployment_panel != null and _deployment_panel.visible:
		_deployment_panel.hide_panel()


func _on_interaction_panel_closed() -> void:
	pass  # 面板已关闭，其他无需联动


func _on_map_action_executed(action: MapInteractionAction) -> void:
	if action.action_id != MapActionConstants.ACTION_DEPLOY or _deployment_panel == null:
		return
	var context := _interaction_panel.get_current_context()
	if context == null:
		return
	_interaction_panel.visible = false
	_deployment_panel.show_for_city(context)


func _on_deployment_panel_closed() -> void:
	if _interaction_panel != null and _interaction_panel.get_current_context() != null:
		_interaction_panel.visible = true


func _on_player_faction_changed(_previous: StringName, current: StringName) -> void:
	_identity_label.text = "%s\n桃园结义 · 流畅" % DemoPlayerContext.get_faction_display_name(current)
	if _interaction_panel != null and _interaction_panel.get_current_context() != null:
		_interaction_panel.refresh_actions()


func _get_current_faction_id() -> int:
	return _player_context.current_faction_id


func _on_player_faction_id_changed(_previous_faction_id: int, _current_faction_id: int) -> void:
	## 阵营 ID 变更时刷新交互面板（确保主城敌我判断等正确更新）
	if _deployment_panel != null and _deployment_panel.visible:
		_deployment_panel.hide_panel()
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
		"building":
			return MapInteractionContext.from_building_snapshot(selection, map_data)
		_:
			return MapInteractionContext.from_tile_snapshot(selection, map_data)


## ——— 建造模式 UI 事件 ———

## 建造入口：未在建造模式时打开建筑选择栏；建造模式中再次点击 = 取消建造
func _toggle_build_mode() -> void:
	if _map_area.is_flatten_mode_active():
		# 平整模式中点击“建造”：退出平整并返回建筑选择栏
		_map_area.cancel_flatten_mode()
		_open_building_select_panel()
		return
	if _map_area.is_build_mode_active():
		_map_area.cancel_build_mode()
		return
	_more_panel.visible = false
	if _build_select_panel.visible:
		_close_building_select_panel()
	else:
		_open_building_select_panel()


## 打开建筑选择栏：每次从第一项和统一展示角度开始。
func _open_building_select_panel() -> void:
	_selected_building_index = 0
	_refresh_building_select_panel()
	_build_select_panel.visible = true


func _close_building_select_panel() -> void:
	_build_select_panel.visible = false


func _on_building_option_pressed(index: int) -> void:
	if index < 0 or index >= _building_catalog.size():
		return
	_selected_building_index = index
	_refresh_building_select_panel()


## 刷新选择栏按钮选中态与 3D 预览。切换建筑时展示角度从零重新开始。
func _refresh_building_select_panel() -> void:
	for i in range(_building_option_buttons.size()):
		_building_option_buttons[i].theme_type_variation = (
			&"PrimaryButton" if i == _selected_building_index else &""
		)
	if _select_preview_mesh == null or _building_catalog.is_empty():
		return
	var definition := _building_catalog[_selected_building_index]
	var world_size := definition.get_world_size(MapGenerationConfig.DEFAULT_CELL_SIZE)
	var box := _select_preview_mesh.mesh as BoxMesh
	if box != null and box.size != world_size:
		box.size = world_size
	_select_preview_mesh.position = Vector3(0.0, world_size.y * 0.5, 0.0)
	_select_preview_mesh.rotation = Vector3.ZERO
	if _select_preview_root != null:
		_select_preview_root.rotation = Vector3.ZERO


## 开始建造：地图 Preview 始终从默认离散方向开始，与 UI 展示旋转完全解耦。
func _on_start_build_pressed() -> void:
	if _building_catalog.is_empty():
		return
	var definition := _building_catalog[_selected_building_index]
	_close_building_select_panel()
	_build_title_label.text = "建造：%s（方向：%s）" % [
		definition.display_name,
		MapBuildingDefinition.get_rotation_display_name(DEFAULT_BUILD_ROTATION_INDEX),
	]
	_map_area.enter_build_mode(definition, DEFAULT_BUILD_ROTATION_INDEX)


func _on_build_mode_changed(active: bool) -> void:
	_build_panel.visible = active
	if active:
		# 进入建造模式时关闭其他浮层与原选择信息 UI，避免误触发
		_more_panel.visible = false
		_build_select_panel.visible = false
		_clear_map_selection()
		_build_reason_label.text = "移动鼠标预览，左键选择建造位置"
		_build_confirm_button.disabled = true


func _on_build_placement_state_changed(result: Dictionary) -> void:
	var valid := bool(result.get("valid", false))
	var locked := bool(result.get("locked", false))
	# 确认只在“已锁定 + 合法”时可用；非法位置允许锁定但不可确认
	_build_confirm_button.disabled = not (valid and locked)
	# 标题同步当前方向（旋转后实时更新）
	_build_title_label.text = "建造：%s（方向：%s）" % [
		str(result.get("building_name", "建筑")),
		str(result.get("rotation_name", "北")),
	]
	if locked:
		_build_reason_label.text = (
			"位置已锁定，可以建造" if valid else str(result.get("reason", "当前位置不可建造"))
		)
	else:
		_build_reason_label.text = (
			"位置合法，左键锁定建造位置" if valid else str(result.get("reason", "当前位置不可建造"))
		)


func _on_build_rotate_pressed() -> void:
	_map_area.rotate_building()


func _on_build_confirm_pressed() -> void:
	var result := _map_area.confirm_build()
	if not bool(result.get("success", false)):
		NavigationManager.show_message("无法建造", str(result.get("reason", "当前位置不可建造")))


func _on_build_cancel_pressed() -> void:
	_map_area.cancel_build_mode()


func _on_building_placed(snapshot: Dictionary) -> void:
	NavigationManager.show_message("建造完成", "「%s」已放置。" % str(snapshot.get("name", "建筑")))


## ——— 土地平整 UI 事件 ———

## 从建筑选择栏进入土地平整模式：关闭选择栏，模式互斥由 MapWorld 保证
func _on_flatten_terrain_pressed() -> void:
	_close_building_select_panel()
	_map_area.enter_flatten_mode()


func _on_flatten_mode_changed(active: bool) -> void:
	_flatten_panel.visible = active
	if active:
		# 进入平整模式时关闭其他浮层与原选择信息 UI，避免误触发
		_more_panel.visible = false
		_build_select_panel.visible = false
		_clear_map_selection()
		_flatten_confirm_button.disabled = true
		_flatten_reselect_button.disabled = true


## 平整状态刷新：高度/范围/耗时/合法性与按钮可用性。
## 未用左键锁定位置前“确认平整”保持禁用；锁定后“重新选择”可用。
func _on_flatten_state_changed(state: Dictionary) -> void:
	_flatten_height_label.text = "等级 %d" % int(state.get("target_height_level", 0))
	_flatten_width_label.text = "%d 格" % int(state.get("region_width", 0))
	_flatten_length_label.text = "%d 格" % int(state.get("region_length", 0))
	_flatten_duration_label.text = "预计耗时：%d 秒（测试阶段）" % int(state.get("duration", 0.0))
	var valid := bool(state.get("valid", false))
	var locked := bool(state.get("locked", false))
	_flatten_confirm_button.disabled = not (locked and valid)
	_flatten_reselect_button.disabled = not locked
	if not locked:
		_flatten_reason_label.text = "移动鼠标预览平整范围，左键点击锁定位置"
	elif valid:
		_flatten_reason_label.text = "位置已锁定：范围 %d 格，其中 %d 格将调整到目标高度" % [
			int(state.get("cell_count", 0)), int(state.get("changed_count", 0))
		]
	else:
		_flatten_reason_label.text = str(state.get("reason", "该区域不可平整"))


func _on_flatten_height_decreased() -> void:
	_map_area.adjust_flatten_height(-1)


func _on_flatten_height_increased() -> void:
	_map_area.adjust_flatten_height(1)


func _on_flatten_width_decreased() -> void:
	_map_area.adjust_flatten_width(-1)


func _on_flatten_width_increased() -> void:
	_map_area.adjust_flatten_width(1)


func _on_flatten_length_decreased() -> void:
	_map_area.adjust_flatten_length(-1)


func _on_flatten_length_increased() -> void:
	_map_area.adjust_flatten_length(1)


func _on_flatten_confirm_pressed() -> void:
	var result := _map_area.confirm_flatten()
	if not bool(result.get("success", false)):
		NavigationManager.show_message("无法平整", str(result.get("reason", "该区域不可平整")))


## 重新选择位置：解除锁定，预览恢复跟随鼠标（不退出平整模式）
func _on_flatten_reselect_pressed() -> void:
	_map_area.unlock_flatten_position()


## 取消平整：不修改任何地形数据，返回建造面板（保留之前选中的建筑）
func _on_flatten_cancel_pressed() -> void:
	_map_area.cancel_flatten_mode()
	_open_building_select_panel()


## 平整完成后返回建造面板（建筑选择栏保留之前的选中建筑）
func _on_terrain_flattened(result: Dictionary) -> void:
	NavigationManager.show_message("平整完成", "已平整 %d 格土地。" % int(result.get("changed_count", 0)))
	_open_building_select_panel()


## 键盘快捷键预留：R = 旋转建筑。移动端为项目目标平台，正式操作以“旋转”按钮为准。
func _unhandled_input(event: InputEvent) -> void:
	if _map_area == null or not _map_area.is_build_mode_active():
		return
	var key_event := event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo:
		if key_event.keycode == KEY_R:
			_map_area.rotate_building()
			get_viewport().set_input_as_handled()


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
