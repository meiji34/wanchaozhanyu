class_name SafeAreaContainer
extends MarginContainer

@export var minimum_safe_padding: int = 28


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()


func _exit_tree() -> void:
	if get_viewport() != null and get_viewport().size_changed.is_connected(_apply_safe_area):
		get_viewport().size_changed.disconnect(_apply_safe_area)


func _apply_safe_area() -> void:
	var left := minimum_safe_padding
	var top := minimum_safe_padding
	var right := minimum_safe_padding
	var bottom := minimum_safe_padding

	# 移动端才读取系统安全区域，桌面演示保留统一基础留白。
	if OS.has_feature("mobile"):
		var screen_size := DisplayServer.screen_get_size()
		var safe_rect := DisplayServer.get_display_safe_area()
		var viewport_size := get_viewport_rect().size
		if screen_size.x > 0 and screen_size.y > 0:
			var scale_x := viewport_size.x / float(screen_size.x)
			var scale_y := viewport_size.y / float(screen_size.y)
			left = maxi(left, roundi(safe_rect.position.x * scale_x))
			top = maxi(top, roundi(safe_rect.position.y * scale_y))
			right = maxi(right, roundi((screen_size.x - safe_rect.end.x) * scale_x))
			bottom = maxi(bottom, roundi((screen_size.y - safe_rect.end.y) * scale_y))

	add_theme_constant_override("margin_left", left)
	add_theme_constant_override("margin_top", top)
	add_theme_constant_override("margin_right", right)
	add_theme_constant_override("margin_bottom", bottom)
