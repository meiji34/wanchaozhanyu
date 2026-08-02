class_name ResourceItem
extends PanelContainer

var _name_label: Label
var _value_label: Label
var _delta_label: Label
var _current_value: int = 0
var _configured: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(92, 54)
	var content := VBoxContainer.new()
	UIBuilder.set_box_spacing(content, 2)
	add_child(content)
	_name_label = UIBuilder.make_label("资源", 15, UIBuilder.COLOR_MUTED)
	content.add_child(_name_label)
	var value_row := HBoxContainer.new()
	UIBuilder.set_box_spacing(value_row, 4)
	content.add_child(value_row)
	_value_label = UIBuilder.make_label("0", 20, UIBuilder.COLOR_TEXT)
	_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_row.add_child(_value_label)
	_delta_label = UIBuilder.make_label("", 14, UIBuilder.COLOR_SUCCESS)
	_delta_label.visible = false
	value_row.add_child(_delta_label)


func configure(resource_name: String, value: int) -> void:
	_name_label.text = resource_name
	_current_value = value
	_value_label.text = _format_value(value)
	_configured = true


func is_configured() -> bool:
	return _configured


func update_value(value: int, delta: int = 0) -> void:
	_current_value = value
	_value_label.text = _format_value(value)
	if delta == 0:
		return
	_delta_label.text = "%+d" % delta
	_delta_label.add_theme_color_override("font_color", UIBuilder.COLOR_SUCCESS if delta > 0 else UIBuilder.COLOR_ERROR)
	_delta_label.visible = true
	modulate = UIBuilder.COLOR_SUCCESS if delta > 0 else UIBuilder.COLOR_ERROR
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color.WHITE, 0.22)
	tween.tween_interval(1.0)
	tween.tween_callback(func() -> void: _delta_label.visible = false)


func _format_value(value: int) -> String:
	if value >= 10000:
		return "%.1f万" % (value / 10000.0)
	return str(value)
