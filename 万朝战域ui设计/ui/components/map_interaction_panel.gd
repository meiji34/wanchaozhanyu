class_name MapInteractionPanel
extends Control

## ——— 地图行动菜单面板 ———
## 稳定节点（只创建一次）：面板本身、标题、详情、结果标签、按钮容器、确认弹窗
## 动态节点（每次目标变化时重建）：行动按钮
## session_id 确保异步/延迟结果不会污染新目标

signal action_executed(action: MapInteractionAction)
signal panel_closed

const MIN_BUTTON_WIDTH := 96.0
const BUTTON_HEIGHT := 52.0
const MAX_BUTTONS_PER_ROW := 5
const PADDING := 14.0

enum InteractionState {
	IDLE,
	TARGET_SELECTED,
	ACTION_MENU_OPEN,
	CONFIRMING,
	EXECUTING,
	SHOWING_RESULT,
}

var _context: MapInteractionContext = null
var _actions: Array[MapInteractionAction] = []
var _resolver: MapActionResolver = null
var _service: DemoInteractionService = null
var _interaction_state: int = InteractionState.IDLE
var _interaction_session_id: int = 0

# 稳定 UI 节点（只创建一次，永远不释放）
var _button_container: HBoxContainer
var _title_label: Label
var _details_label: Label
var _result_label: Label
var _panel_bg: PanelContainer
var _confirm_dialog: ConfirmationDialog
var _vbox: VBoxContainer


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_build_confirm_dialog()
	_build_ui()
	visible = false


func _build_confirm_dialog() -> void:
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.name = "ConfirmDialog"
	_confirm_dialog.title = "确认操作"
	_confirm_dialog.dialog_hide_on_ok = false
	_confirm_dialog.confirmed.connect(_on_confirm_confirmed)
	_confirm_dialog.canceled.connect(_on_confirm_cancelled)
	add_child(_confirm_dialog)


func configure(resolver: MapActionResolver, service: DemoInteractionService) -> void:
	_resolver = resolver
	_service = service


## 显示指定上下文的行动面板
func show_for_context(context: MapInteractionContext) -> void:
	if context == null or _resolver == null:
		return
	_interaction_session_id += 1
	_context = context
	_actions = _resolver.get_available_actions(context)
	_set_state(InteractionState.ACTION_MENU_OPEN)
	_refresh_ui()
	visible = true


func hide_panel() -> void:
	_interaction_session_id += 1
	_context = null
	_actions.clear()
	_clear_action_buttons()
	_confirm_dialog.hide()
	_confirm_dialog.remove_meta("pending_action")
	_set_state(InteractionState.IDLE)
	visible = false
	panel_closed.emit()


func get_current_context() -> MapInteractionContext:
	return _context


func get_visible_action_count() -> int:
	var count := 0
	for child in _button_container.get_children():
		if child is Button and child.visible:
			count += 1
	return count


## 根据阵营变化刷新当前行动列表（不改变目标）
func refresh_actions() -> void:
	if _context == null or _resolver == null:
		return
	_interaction_session_id += 1
	_actions = _resolver.get_available_actions(_context)
	_set_state(InteractionState.ACTION_MENU_OPEN)
	_clear_action_buttons()
	_build_action_buttons()
	_apply_responsive_layout()


## ——— UI 构建（只执行一次） ———

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM)
	offset_left = -420
	offset_top = -220
	offset_right = 420
	offset_bottom = 0

	_panel_bg = PanelContainer.new()
	_panel_bg.name = "InteractionPanelBg"
	_panel_bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_panel_bg.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(_panel_bg)

	_vbox = VBoxContainer.new()
	_vbox.name = "InteractionVBox"
	_vbox.add_theme_constant_override("separation", 8)
	_panel_bg.add_child(_vbox)

	# 标题行（稳定节点）
	var header_row := HBoxContainer.new()
	_vbox.add_child(header_row)
	_title_label = _make_label("目标", 22, Color("c8a84e"))
	_title_label.size_flags_horizontal = SIZE_EXPAND_FILL
	header_row.add_child(_title_label)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(42, 42)
	close_btn.pressed.connect(hide_panel)
	close_btn.tooltip_text = "关闭行动面板"
	header_row.add_child(close_btn)

	# 详情行（稳定节点）
	_details_label = _make_label("", 15, Color("a09078"), true)
	_details_label.name = "DetailsLabel"
	_vbox.add_child(_details_label)

	# 按钮容器（稳定节点，只清空子节点）
	_button_container = HBoxContainer.new()
	_button_container.name = "ActionButtonContainer"
	_button_container.add_theme_constant_override("separation", 8)
	_button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox.add_child(_button_container)

	# 结果标签（稳定节点，只更新 text）
	_result_label = _make_label("", 15, Color("7acc7a"))
	_result_label.name = "ActionResultLabel"
	_vbox.add_child(_result_label)


func _refresh_ui() -> void:
	if _context == null:
		return
	_title_label.text = _context.display_name
	_details_label.text = _build_detail_text()
	_result_label.text = ""  # 清除旧结果
	_clear_action_buttons()
	_build_action_buttons()
	_apply_responsive_layout()


## 根据目标类型构建详细信息文本（合并原 _selection_panel 的信息）
func _build_detail_text() -> String:
	var parts: Array[String] = []
	var snapshot: Dictionary = _context.raw_snapshot

	match _context.target_type:
		MapActionConstants.TargetType.CITY:
			# 城池：名称(已在标题) + 等级 + 阵营 + 坐标
			var lv: int = int(snapshot.get("level", 1))
			parts.append("等级：Lv.%d" % lv)
			var faction_name: String = _get_faction_display()
			if faction_name != "":
				parts.append("阵营：%s" % faction_name)
			parts.append("坐标：(%d, %d)" % [_context.grid_position.x, _context.grid_position.y])

		MapActionConstants.TargetType.BUILDING:
			# 玩家建造建筑：阵营 + 占地 + 坐标（阵营归属为核心展示信息）
			var building_faction: String = _get_faction_display()
			if building_faction != "":
				parts.append("阵营：%s" % building_faction)
			var footprint: Vector2i = snapshot.get("footprint_size", Vector2i(3, 3))
			parts.append("占地：%d×%d" % [footprint.x, footprint.y])
			parts.append("坐标：(%d, %d)" % [_context.grid_position.x, _context.grid_position.y])

		MapActionConstants.TargetType.RESOURCE, MapActionConstants.TargetType.IRON_MINE:
			# 资源点：类型 + 区域 + 坐标 + 状态
			var res_name: String = str(snapshot.get("resource_name", "未知"))
			parts.append("类型：%s" % res_name)
			if _context.zone_name != "":
				parts.append("区域：%s" % _context.zone_name)
			parts.append("坐标：(%d, %d)" % [_context.grid_position.x, _context.grid_position.y])
			var neutral: bool = bool(snapshot.get("neutral", true))
			parts.append("状态：%s" % ("中立" if neutral else "已占领"))

		_:
			# 普通格子 / 道路 / 桥梁 / 关隘 等：地形 + 区域 + 高度 + 道路 + 坐标
			var terrain: String = str(snapshot.get("terrain", "未知"))
			if terrain != "未知":
				parts.append("地形：%s" % terrain)
			if _context.zone_name != "":
				parts.append("区域：%s" % _context.zone_name)
			var height_val: float = float(snapshot.get("height", 0.0))
			parts.append("高度：%.1f" % height_val)
			var road_name: String = str(snapshot.get("road_name", ""))
			if road_name != "" and road_name != "无":
				parts.append("道路：%s" % road_name)
			var can_build: bool = bool(snapshot.get("can_build_city", false))
			parts.append("可建城：%s" % ("是" if can_build else "否"))
			parts.append("坐标：(%d, %d)" % [_context.grid_position.x, _context.grid_position.y])
			# 过河点信息
			if snapshot.has("crossing_name"):
				parts.append("过河点：%s" % snapshot.get("crossing_name", ""))
			# 阵营信息（通过 faction_id 查询名称）
			var faction_display: String = _get_faction_display()
			if faction_display != "":
				parts.append("阵营：%s" % faction_display)

	return "    ".join(parts)


## 根据 faction_id 获取阵营显示名称
func _get_faction_display() -> String:
	if _context == null:
		return ""
	if _context.faction_id != DemoPlayerContext.FactionId.NONE:
		return DemoPlayerContext.get_faction_name_by_id(_context.faction_id)
	if _context.faction != "":
		return str(_context.faction)
	return ""


## ——— 按钮管理 ———

func _clear_action_buttons() -> void:
	for child in _button_container.get_children():
		child.queue_free()


func _build_action_buttons() -> void:
	var sorted: Array[MapInteractionAction] = []
	for act in _actions:
		if act.enabled:
			sorted.append(act)
	for act in _actions:
		if not act.enabled:
			sorted.append(act)
	for act in sorted:
		var btn := _build_action_button(act)
		_button_container.add_child(btn)


func _build_action_button(act: MapInteractionAction) -> Button:
	var btn := Button.new()
	btn.text = act.display_name
	btn.custom_minimum_size = Vector2(MIN_BUTTON_WIDTH, BUTTON_HEIGHT)
	btn.disabled = not act.enabled
	if not act.enabled and act.disabled_reason != "":
		btn.tooltip_text = act.disabled_reason

	# 根据类别着色
	match act.action_category:
		MapActionConstants.ActionCategory.COMBAT:
			btn.add_theme_color_override("font_color", Color("e07050"))
			btn.add_theme_color_override("font_focus_color", Color("ff8870"))
		MapActionConstants.ActionCategory.RESOURCE:
			btn.add_theme_color_override("font_color", Color("7acc7a"))
			btn.add_theme_color_override("font_focus_color", Color("90e890"))
		MapActionConstants.ActionCategory.STRATEGY:
			btn.add_theme_color_override("font_color", Color("7ab8e0"))
			btn.add_theme_color_override("font_focus_color", Color("90d0f8"))

	# 使用 meta 传 action_id，避免闭包捕获旧 Action 或旧节点
	var capture_id: StringName = act.action_id
	btn.set_meta("action_id", capture_id)
	btn.pressed.connect(_on_action_pressed.bind(capture_id))
	return btn


## ——— 行动执行 ———

func _on_action_pressed(action_id: StringName) -> void:
	if _interaction_state != InteractionState.ACTION_MENU_OPEN and _interaction_state != InteractionState.SHOWING_RESULT:
		return
	var act := _find_action_by_id(action_id)
	if act == null or not act.enabled:
		return
	if act.requires_confirmation:
		_set_state(InteractionState.CONFIRMING)
		_confirm_dialog.dialog_text = "确定要%s「%s」吗？" % [act.display_name, _context.display_name]
		_confirm_dialog.ok_button_text = "确认%s" % act.display_name
		_confirm_dialog.set_meta("pending_action_id", action_id)
		_confirm_dialog.popup_centered()
	else:
		_execute_action(act)


func _find_action_by_id(action_id: StringName) -> MapInteractionAction:
	for act in _actions:
		if act.action_id == action_id:
			return act
	return null


func _on_confirm_confirmed() -> void:
	var action_id: StringName = _confirm_dialog.get_meta("pending_action_id") as StringName
	_confirm_dialog.remove_meta("pending_action_id")
	var act := _find_action_by_id(action_id)
	if act == null:
		_set_state(InteractionState.ACTION_MENU_OPEN)
		return
	# 二次权限校验：防止确认期间阵营变化导致非法执行
	if not act.enabled:
		_set_state(InteractionState.ACTION_MENU_OPEN)
		_show_result("当前阵营不能对己方目标执行此操作")
		return
	_execute_action(act)


func _on_confirm_cancelled() -> void:
	_confirm_dialog.remove_meta("pending_action_id")
	_set_state(InteractionState.ACTION_MENU_OPEN)


func _execute_action(act: MapInteractionAction) -> void:
	var exec_session_id: int = _interaction_session_id
	_set_state(InteractionState.EXECUTING)
	if _service != null:
		var result := _service.execute(act)
		# 会话保护：如果执行期间目标已切换，不显示旧结果
		if exec_session_id == _interaction_session_id:
			_show_result(str(result.get("message", "")))
			_set_state(InteractionState.SHOWING_RESULT)
	action_executed.emit(act)


## ——— 结果展示 ———

func _show_result(message: String) -> void:
	_result_label.text = message


## ——— 状态管理 ———

func _set_state(state: int) -> void:
	_interaction_state = state


func get_interaction_state() -> int:
	return _interaction_state


## ——— 响应式布局 ———

func _apply_responsive_layout() -> void:
	var viewport_width := maxf(320.0, get_viewport_rect().size.x)
	var panel_width := minf(840.0, viewport_width - 48.0)
	offset_left = -panel_width * 0.5
	offset_right = panel_width * 0.5

	var action_count := maxi(1, _actions.size())
	var cols := mini(action_count, MAX_BUTTONS_PER_ROW)
	if viewport_width < 720.0:
		cols = mini(cols, 3)
	var per_button := maxf(MIN_BUTTON_WIDTH, (panel_width - PADDING * 2.0 - 8.0 * (cols - 1)) / float(cols))
	for btn in _button_container.get_children():
		if btn is Button:
			(btn as Button).custom_minimum_size.x = per_button


## ——— 辅助 ———

func _make_label(text: String, font_size: int, color: Color, autowrap: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if autowrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1a1c18")
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color("4a4a3a")
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style
