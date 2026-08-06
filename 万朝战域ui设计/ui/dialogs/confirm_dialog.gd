extends Control

signal confirmed
signal cancelled

var _title_label: Label
var _message_label: Label
var _confirm_button: Button
var _cancel_button: Button


func _ready() -> void:
	_build_ui()


func configure(title: String, message: String, confirm_text: String, cancel_text: String) -> void:
	_title_label.text = title
	_message_label.text = message
	_confirm_button.text = confirm_text
	_cancel_button.text = cancel_text


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
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)
	var content := VBoxContainer.new()
	UIBuilder.set_box_spacing(content, 18)
	panel.add_child(content)
	_title_label = UIBuilder.make_title("确认操作", 26)
	content.add_child(_title_label)
	_message_label = UIBuilder.make_label("", 19, UIBuilder.COLOR_MUTED, true)
	content.add_child(_message_label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	UIBuilder.set_box_spacing(buttons, 12)
	content.add_child(buttons)
	_cancel_button = UIBuilder.make_button("取消", 140)
	_cancel_button.pressed.connect(func() -> void: cancelled.emit())
	buttons.add_child(_cancel_button)
	_confirm_button = UIBuilder.make_primary_button("确认", 160)
	_confirm_button.pressed.connect(func() -> void: confirmed.emit())
	buttons.add_child(_confirm_button)

