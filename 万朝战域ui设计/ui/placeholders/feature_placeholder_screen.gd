extends Control

@export var feature_title: String = "未命名功能"
@export_multiline var feature_description: String = "该功能将在后续阶段开发。"

var _title_label: Label
var _description_label: Label


func _ready() -> void:
	_build_ui()


func configure(params: Dictionary) -> void:
	if params.has("title"):
		feature_title = str(params["title"])
	if params.has("description"):
		feature_description = str(params["description"])
	if _title_label != null:
		_title_label.text = feature_title
	if _description_label != null:
		_description_label.text = feature_description


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("11100f")
	add_child(background)
	var safe := SafeAreaContainer.new()
	add_child(safe)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	safe.add_child(center)
	var panel := UIBuilder.make_panel()
	panel.custom_minimum_size = Vector2(720, 0)
	center.add_child(panel)
	var content := VBoxContainer.new()
	UIBuilder.set_box_spacing(content, 20)
	panel.add_child(content)
	_title_label = UIBuilder.make_title(feature_title, 34)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_title_label)
	var state := UIBuilder.make_label("功能开发中", 24, UIBuilder.COLOR_ACCENT)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(state)
	_description_label = UIBuilder.make_label(feature_description, 18, UIBuilder.COLOR_MUTED, true)
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_description_label)
	var back := UIBuilder.make_primary_button("返回主界面", 240)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: NavigationManager.go_back("main_hud"))
	content.add_child(back)
