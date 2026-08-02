class_name TaskPanel
extends PanelContainer

signal task_details_requested(task: Dictionary)
signal tracking_toggled(task_id: String)
signal demo_advance_requested

@export var show_demo_controls := false

const TASK_ITEM_SCENE := preload("res://ui/components/task_item.tscn")

var _list: VBoxContainer
var _empty_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(328, 0)
	var content := VBoxContainer.new()
	UIBuilder.set_box_spacing(content, 12)
	add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := UIBuilder.make_label("任务与事件", 22, UIBuilder.COLOR_ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	if show_demo_controls:
		var demo := UIBuilder.make_button("推进演示", 112)
		demo.custom_minimum_size.y = 56
		demo.pressed.connect(func() -> void: demo_advance_requested.emit())
		header.add_child(demo)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIBuilder.set_box_spacing(_list, 10)
	scroll.add_child(_list)
	_empty_label = UIBuilder.make_label("当前没有任务。侦查或进入联盟后，任务会出现在这里。", 16, UIBuilder.COLOR_MUTED, true)
	_empty_label.visible = false
	_list.add_child(_empty_label)


func set_tasks(tasks: Array[Dictionary]) -> void:
	for child in _list.get_children():
		if child != _empty_label:
			child.queue_free()
	_empty_label.visible = tasks.is_empty()
	for task in tasks:
		var item := TASK_ITEM_SCENE.instantiate() as TaskItem
		_list.add_child(item)
		item.configure(task)
		item.details_requested.connect(func(data: Dictionary) -> void: task_details_requested.emit(data))
		item.tracking_toggled.connect(func(task_id: String) -> void: tracking_toggled.emit(task_id))
