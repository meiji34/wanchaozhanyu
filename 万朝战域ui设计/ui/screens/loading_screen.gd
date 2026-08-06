extends Control

var _target_route: String = "start"
var _duration: float = 1.2
var _message: String = "加载"
var _progress: ProgressBar
var _status_label: Label
var _started: bool = false


func _ready() -> void:
	_build_ui()
	call_deferred("_start_loading")


func configure(params: Dictionary) -> void:
	_target_route = str(params.get("target", "start"))
	_duration = float(params.get("duration", 1.2))
	_message = str(params.get("message", "加载"))
	if _status_label != null:
		_status_label.text = _message


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("11100f")
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 560
	UIBuilder.set_box_spacing(content, 24)
	center.add_child(content)
	var title := UIBuilder.make_title("万朝战域", 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	_status_label = UIBuilder.make_label(_message, 22, UIBuilder.COLOR_ACCENT)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_status_label)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size.y = 20
	_progress.value = 0
	_progress.show_percentage = false
	content.add_child(_progress)
	var hint := UIBuilder.make_label("本地计时模拟，不读取地图、服务器或正式游戏资源。", 16, UIBuilder.COLOR_MUTED, true)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint)


func _start_loading() -> void:
	if _started:
		return
	_started = true
	_status_label.text = _message
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_progress, 0.0, 100.0, _duration)
	tween.tween_callback(func() -> void: NavigationManager.replace_screen(_target_route, {}, true))


func _set_progress(value: float) -> void:
	_progress.value = value
	var dots := ".".repeat(int(value / 20.0) % 4)
	_status_label.text = _message + dots

