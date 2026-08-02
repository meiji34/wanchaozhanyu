class_name ResourceBar
extends MarginContainer

signal more_status_requested
signal demo_update_requested

@export var show_demo_controls := false

const RESOURCE_ORDER: Array[String] = ["银两", "粮食", "木材", "石料", "兵力"]
const RESOURCE_ITEM_SCENE := preload("res://ui/components/resource_item.tscn")

var _items: Dictionary = {}
var _items_row: HBoxContainer


func _ready() -> void:
	custom_minimum_size.y = 72
	var row := HBoxContainer.new()
	UIBuilder.set_box_spacing(row, 10)
	add_child(row)
	_items_row = HBoxContainer.new()
	_items_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIBuilder.set_box_spacing(_items_row, 8)
	row.add_child(_items_row)
	for resource_name in RESOURCE_ORDER:
		var item := RESOURCE_ITEM_SCENE.instantiate() as ResourceItem
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_items_row.add_child(item)
		_items[resource_name] = item
	var more_button := UIBuilder.make_button("更多状态", 132)
	more_button.pressed.connect(func() -> void: more_status_requested.emit())
	row.add_child(more_button)
	if show_demo_controls:
		var demo_button := UIBuilder.make_button("数值演示", 126)
		demo_button.pressed.connect(func() -> void: demo_update_requested.emit())
		row.add_child(demo_button)


func set_resources(resources: Dictionary, changes: Dictionary = {}) -> void:
	for resource_name in RESOURCE_ORDER:
		var item := _items.get(resource_name) as ResourceItem
		if item == null:
			continue
		var value := int(resources.get(resource_name, 0))
		if not item.is_configured():
			item.configure(resource_name, value)
		else:
			item.update_value(value, int(changes.get(resource_name, 0)))
