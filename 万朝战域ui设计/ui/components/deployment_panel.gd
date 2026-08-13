class_name DeploymentPanel
extends Control

signal deployment_submitted(request: DeploymentRequest, result: Dictionary)
signal panel_closed

const PANEL_WIDTH := 900.0
const PANEL_HEIGHT := 650.0
const TOUCH_HEIGHT := 56.0

var _service: DemoDeploymentService
var _context: MapInteractionContext
var _selected_unit_id: StringName = &""
var _unit_buttons: Dictionary = {}
var _title_label: Label
var _summary_label: Label
var _resource_label: Label
var _quantity_input: SpinBox
var _cost_label: Label
var _feedback_label: Label
var _submit_button: Button
var _unit_grid: GridContainer


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_build_ui()
	visible = false


func configure(service: DemoDeploymentService) -> void:
	_service = service


func show_for_city(context: MapInteractionContext) -> void:
	if context == null or context.target_type != MapActionConstants.TargetType.CITY:
		return
	_context = context
	_title_label.text = "从「%s」出兵" % context.display_name
	_feedback_label.text = ""
	_quantity_input.value = 100
	var units := _service.get_units() if _service != null else UnitCatalog.get_all()
	if not units.is_empty():
		_select_unit(StringName(units[0].get("id", &"")))
	_refresh_resource_state()
	visible = true
	move_to_front()


func hide_panel() -> void:
	visible = false
	_context = null
	panel_closed.emit()


func get_selected_unit_id() -> StringName:
	return _selected_unit_id


func get_quantity() -> int:
	return int(_quantity_input.value)


func get_unit_button_count() -> int:
	return _unit_buttons.size()


func apply_responsive_layout(viewport_size: Vector2) -> void:
	var width := minf(PANEL_WIDTH, maxf(320.0, viewport_size.x - 48.0))
	var height := minf(PANEL_HEIGHT, maxf(420.0, viewport_size.y - 120.0))
	offset_left = -width * 0.5
	offset_right = width * 0.5
	offset_top = -height * 0.5
	offset_bottom = height * 0.5
	if _unit_grid != null:
		_unit_grid.columns = 2 if width < 620.0 else (3 if width < 820.0 else 4)
		var button_width := maxf(132.0, (width - 64.0 - 8.0 * float(_unit_grid.columns - 1)) / float(_unit_grid.columns))
		for button_variant: Variant in _unit_buttons.values():
			(button_variant as Button).custom_minimum_size.x = button_width


func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_CENTER)
	offset_left = -PANEL_WIDTH * 0.5
	offset_top = -PANEL_HEIGHT * 0.5
	offset_right = PANEL_WIDTH * 0.5
	offset_bottom = PANEL_HEIGHT * 0.5

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)
	_title_label = _label("出兵编成", 24, Color("d2b45f"))
	_title_label.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(_title_label)
	var close := Button.new()
	close.text = "×"
	close.tooltip_text = "关闭出兵面板"
	close.custom_minimum_size = Vector2(TOUCH_HEIGHT, TOUCH_HEIGHT)
	close.pressed.connect(hide_panel)
	header.add_child(close)

	_resource_label = _label("", 16, Color("c8c2b2"))
	content.add_child(_resource_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_unit_grid = GridContainer.new()
	_unit_grid.columns = 4
	_unit_grid.size_flags_horizontal = SIZE_EXPAND_FILL
	_unit_grid.add_theme_constant_override("h_separation", 8)
	_unit_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_unit_grid)
	_build_unit_buttons()

	_summary_label = _label("", 16, Color("aaa38f"), true)
	content.add_child(_summary_label)
	var quantity_row := HBoxContainer.new()
	quantity_row.add_theme_constant_override("separation", 12)
	content.add_child(quantity_row)
	quantity_row.add_child(_label("出兵数量", 17, Color("e5dfcf")))
	_quantity_input = SpinBox.new()
	_quantity_input.min_value = 10
	_quantity_input.max_value = 10000
	_quantity_input.step = 10
	_quantity_input.value = 100
	_quantity_input.custom_minimum_size = Vector2(180, TOUCH_HEIGHT)
	_quantity_input.value_changed.connect(_on_quantity_changed)
	quantity_row.add_child(_quantity_input)
	_cost_label = _label("", 17, Color("d2b45f"))
	_cost_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantity_row.add_child(_cost_label)

	_feedback_label = _label("", 15, Color("d97962"), true)
	content.add_child(_feedback_label)
	_submit_button = Button.new()
	_submit_button.text = "确认出兵"
	_submit_button.custom_minimum_size.y = TOUCH_HEIGHT
	_submit_button.pressed.connect(_on_submit_pressed)
	content.add_child(_submit_button)


func _build_unit_buttons() -> void:
	for unit: Dictionary in UnitCatalog.get_all():
		var button := Button.new()
		var unit_id := StringName(unit.get("id", &""))
		button.text = "%s\n%s" % [unit.get("name", "兵种"), unit.get("category", "")]
		button.custom_minimum_size = Vector2(190, 68)
		button.toggle_mode = true
		button.tooltip_text = str(unit.get("summary", ""))
		button.pressed.connect(_select_unit.bind(unit_id))
		_unit_grid.add_child(button)
		_unit_buttons[unit_id] = button


func _select_unit(unit_id: StringName) -> void:
	if not UnitCatalog.has_unit(unit_id):
		return
	_selected_unit_id = unit_id
	for id: StringName in _unit_buttons:
		(_unit_buttons[id] as Button).button_pressed = id == unit_id
	var unit := UnitCatalog.get_by_id(unit_id)
	_summary_label.text = "%s · %s · 每名消耗 %d 粮食" % [
		unit.get("name", "兵种"), unit.get("summary", ""), int(unit.get("food_per_unit", 1))
	]
	_refresh_cost()


func _on_quantity_changed(_value: float) -> void:
	_refresh_cost()


func _refresh_resource_state() -> void:
	var resources := _service.get_available_resources() if _service != null else {}
	_resource_label.text = "可用兵力 %d    可用粮食 %d" % [
		int(resources.get("兵力", 0)), int(resources.get("粮食", 0))
	]
	_refresh_cost()


func _refresh_cost() -> void:
	if _cost_label == null:
		return
	var cost := _service.get_cost(_selected_unit_id, get_quantity()) if _service != null else {"兵力": 0, "粮食": 0}
	_cost_label.text = "消耗：兵力 %d · 粮食 %d" % [int(cost.get("兵力", 0)), int(cost.get("粮食", 0))]
	var request := _make_request()
	var validation := _service.can_submit(request) if _service != null else {"success": false, "message": "出兵服务不可用"}
	_submit_button.disabled = not bool(validation.get("success", false))
	_feedback_label.text = "" if not _submit_button.disabled else str(validation.get("message", "无法出兵"))


func _make_request() -> DeploymentRequest:
	var request := DeploymentRequest.new()
	if _context != null:
		request.origin_city_id = _context.target_id
		request.origin_city_name = _context.display_name
		request.faction_id = _context.faction_id
	request.unit_id = _selected_unit_id
	request.quantity = get_quantity()
	return request


func _on_submit_pressed() -> void:
	if _service == null:
		return
	var request := _make_request()
	_submit_button.disabled = true
	_submit_button.text = "正在下达军令..."
	var result := _service.submit(request)
	_submit_button.text = "确认出兵"
	_refresh_resource_state()
	_feedback_label.text = str(result.get("message", ""))
	_feedback_label.add_theme_color_override("font_color", Color("72c98b") if bool(result.get("success", false)) else Color("d97962"))
	deployment_submitted.emit(request, result)


func _label(text: String, size: int, color: Color, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("181a17")
	style.border_color = Color("62583c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	return style
