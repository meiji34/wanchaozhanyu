extends Control

signal closed

@export var is_error: bool = false

var _title_label: Label
var _message_label: Label
var _button: Button


func _ready() -> void:
	_build_ui()


func configure(title: String, message: String, button_text: String) -> void:
	_title_label.text = title
	_message_label.text = message
	_button.text = button_text


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.74)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := UIBuilder.make_panel()
	panel.custom_minimum_size = Vector2(580, 0)
	center.add_child(panel)
	var content := VBoxContainer.new()
	UIBuilder.set_box_spacing(content, 18)
	panel.add_child(content)
	_title_label = UIBuilder.make_title("提示", 26)
	_title_label.add_theme_color_override("font_color", UIBuilder.COLOR_ERROR if is_error else UIBuilder.COLOR_ACCENT)
	content.add_child(_title_label)
	_message_label = UIBuilder.make_label("", 19, UIBuilder.COLOR_MUTED, true)
	content.add_child(_message_label)
	_button = UIBuilder.make_danger_button("返回", 160) if is_error else UIBuilder.make_primary_button("知道了", 160)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_button.pressed.connect(func() -> void: closed.emit())
	content.add_child(_button)

