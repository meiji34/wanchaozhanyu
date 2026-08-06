class_name TaskItem
extends PanelContainer

signal details_requested(task: Dictionary)
signal tracking_toggled(task_id: String)

var _task: Dictionary = {}
var _details: VBoxContainer
var _title_button: Button
var _progress_label: Label
var _status_label: Label
var _track_button: Button
var _expanded: bool = true


func _ready() -> void:
	_build_ui()


func configure(task: Dictionary) -> void:
	_task = task.duplicate(true)
	_refresh()


func _build_ui() -> void:
	var content := VBoxContainer.new()
	UIBuilder.set_box_spacing(content, 8)
	add_child(content)
	var top := HBoxContainer.new()
	UIBuilder.set_box_spacing(top, 8)
	content.add_child(top)
	_title_button = UIBuilder.make_button("任务", 0)
	_title_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title_button.pressed.connect(_toggle_expanded)
	top.add_child(_title_button)
	_status_label = UIBuilder.make_label("进行中", 15, UIBuilder.COLOR_WARNING)
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(_status_label)
	_details = VBoxContainer.new()
	UIBuilder.set_box_spacing(_details, 8)
	content.add_child(_details)
	var description := UIBuilder.make_label("任务描述", 16, UIBuilder.COLOR_MUTED, true)
	description.name = "Description"
	_details.add_child(description)
	_progress_label = UIBuilder.make_label("0 / 1", 15, UIBuilder.COLOR_TEXT)
	_details.add_child(_progress_label)
	var actions := HBoxContainer.new()
	UIBuilder.set_box_spacing(actions, 8)
	_details.add_child(actions)
	var details_button := UIBuilder.make_button("查看详情", 118)
	details_button.custom_minimum_size.y = 56
	details_button.pressed.connect(func() -> void: details_requested.emit(_task.duplicate(true)))
	actions.add_child(details_button)
	_track_button = UIBuilder.make_button("追踪", 100)
	_track_button.custom_minimum_size.y = 56
	_track_button.pressed.connect(func() -> void: tracking_toggled.emit(str(_task.get("id", ""))))
	actions.add_child(_track_button)


func _refresh() -> void:
	if _task.is_empty() or _title_button == null:
		return
	var unread_prefix := "● " if bool(_task.get("unread", false)) else ""
	var arrow := "▼ " if _expanded else "▶ "
	_title_button.text = arrow + unread_prefix + str(_task.get("title", "未命名任务"))
	var description := _details.get_node_or_null("Description") as Label
	if description != null:
		description.text = str(_task.get("description", "暂无描述"))
	_progress_label.text = "进度 %d / %d" % [int(_task.get("current", 0)), int(_task.get("target", 0))]
	var status := str(_task.get("status", "进行中"))
	_status_label.text = status
	_status_label.add_theme_color_override("font_color", UIBuilder.status_color(status))
	var trackable := bool(_task.get("trackable", false))
	_track_button.visible = trackable
	_track_button.text = "取消追踪" if bool(_task.get("tracked", false)) else "追踪任务"
	_details.visible = _expanded


func _toggle_expanded() -> void:
	_expanded = not _expanded
	_refresh()
