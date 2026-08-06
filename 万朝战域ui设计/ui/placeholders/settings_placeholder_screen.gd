extends Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("11100f")
	add_child(background)
	var safe := SafeAreaContainer.new()
	add_child(safe)
	var content := VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UIBuilder.set_box_spacing(content, 20)
	safe.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var back := UIBuilder.make_button("返回", 120)
	back.pressed.connect(func() -> void: NavigationManager.go_back("main_hud"))
	header.add_child(back)
	var title := UIBuilder.make_title("设置", 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)
	var balance := Control.new()
	balance.custom_minimum_size.x = 120
	header.add_child(balance)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(center)
	var panel := UIBuilder.make_panel()
	panel.custom_minimum_size = Vector2(680, 260)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	UIBuilder.set_box_spacing(box, 18)
	panel.add_child(box)
	var state := UIBuilder.make_label("设置功能后续添加", 28, UIBuilder.COLOR_ACCENT)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(state)
	var note := UIBuilder.make_label("本阶段不修改音量、画质、帧率、振动、语言或项目配置。", 18, UIBuilder.COLOR_MUTED, true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)

