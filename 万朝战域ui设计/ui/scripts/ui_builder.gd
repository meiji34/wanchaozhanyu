class_name UIBuilder
extends RefCounted

const COLOR_TEXT := Color("eee9df")
const COLOR_MUTED := Color("aaa99f")
const COLOR_ACCENT := Color("c99648")
const COLOR_SUCCESS := Color("6f9d82")
const COLOR_WARNING := Color("c58d45")
const COLOR_ERROR := Color("bf6259")
const COLOR_INFO := Color("6f908d")


static func make_label(
	text_value: String,
	font_size: int = 18,
	color: Color = COLOR_TEXT,
	should_wrap: bool = false
) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if should_wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


static func make_title(text_value: String, font_size: int = 30) -> Label:
	var label := make_label(text_value, font_size, COLOR_TEXT, true)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


static func make_button(text_value: String, minimum_width: float = 0.0) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(minimum_width, 56)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


static func make_primary_button(text_value: String, minimum_width: float = 0.0) -> Button:
	var button := make_button(text_value, minimum_width)
	button.theme_type_variation = &"PrimaryButton"
	return button


static func make_danger_button(text_value: String, minimum_width: float = 0.0) -> Button:
	var button := make_button(text_value, minimum_width)
	button.theme_type_variation = &"DangerButton"
	return button


static func make_panel(padding: int = 20) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_constant_override("padding", padding)
	return panel


static func set_box_spacing(box: BoxContainer, spacing: int = 12) -> void:
	box.add_theme_constant_override("separation", spacing)


static func add_v_spacer(parent: BoxContainer, height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	parent.add_child(spacer)
	return spacer


static func status_color(status: String) -> Color:
	match status:
		"流畅", "已完成", "完好":
			return COLOR_SUCCESS
		"繁忙", "进行中", "负伤":
			return COLOR_WARNING
		"维护", "错误", "破碎":
			return COLOR_ERROR
		_:
			return COLOR_INFO
