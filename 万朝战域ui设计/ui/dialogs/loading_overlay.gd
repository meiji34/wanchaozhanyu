extends Control

var _message_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.68)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := UIBuilder.make_panel()
	panel.custom_minimum_size = Vector2(380, 150)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	UIBuilder.set_box_spacing(box, 16)
	panel.add_child(box)
	_message_label = UIBuilder.make_label("处理中…", 22, UIBuilder.COLOR_ACCENT)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_message_label)
	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(320, 18)
	progress.indeterminate = true
	progress.show_percentage = false
	box.add_child(progress)


func configure(message: String) -> void:
	_message_label.text = message

