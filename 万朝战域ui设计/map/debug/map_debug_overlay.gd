class_name MapDebugOverlay
extends CanvasLayer

@export var debug_enabled := false

var _controller: MapController
var _camera_rig: MapCameraRig
var _label: Label


func _ready() -> void:
	visible = debug_enabled
	_build_overlay()


func setup(controller: MapController, camera_rig: MapCameraRig) -> void:
	_controller = controller
	_camera_rig = camera_rig


func set_debug_enabled(enabled: bool) -> void:
	debug_enabled = enabled
	visible = enabled


func _process(_delta: float) -> void:
	if not debug_enabled or _controller == null or _camera_rig == null:
		return
	var chunk_data := _controller.get_debug_snapshot()
	var camera_data := _camera_rig.get_debug_data()
	_label.text = (
		"地图调试\n种子：%d\n相机 Chunk：%s\n活跃 / 缓存 / 队列：%d / %d / %d"
		+ "\n资源 / 铁矿 / 关隘 / 过河点：%d / %d / %d / %d"
		+ "\n铁矿落点：%s"
		+ "\n模式：%s  投影：%s\n缩放：%.1f  视距：%.1f  旋转：%.1f°  俯角：%.1f°"
		+ "\n迷雾：探索 %s（%d / %d）  LOD：%d / %d / %d"
	) % [
		int(chunk_data.get("seed", 0)),
		str(chunk_data.get("camera_chunk", Vector2i.ZERO)),
		int(chunk_data.get("active_chunk_count", 0)),
		int(chunk_data.get("cached_chunk_count", 0)),
		int(chunk_data.get("queued_chunk_count", 0)),
		int(chunk_data.get("resource_count", 0)),
		int(chunk_data.get("iron_count", 0)),
		int(chunk_data.get("pass_count", 0)),
		int(chunk_data.get("crossing_count", 0)),
		", ".join(chunk_data.get("iron_positions", []) as Array),
		str(camera_data.get("view_mode_name", "未知")),
		str(camera_data.get("projection", "未知")),
		float(camera_data.get("ortho_size", 0.0)),
		float(camera_data.get("perspective_distance", 0.0)),
		float(camera_data.get("yaw_degrees", 0.0)),
		float(camera_data.get("pitch_degrees", 0.0)),
		str(chunk_data.get("fog_explored_ratio", "0%")),
		int(chunk_data.get("fog_explored", 0)),
		int(chunk_data.get("fog_unknown", 0)),
		int(chunk_data.get("lod0_chunks", 0)),
		int(chunk_data.get("lod1_chunks", 0)),
		int(chunk_data.get("lod2_chunks", 0)),
	]


func _build_overlay() -> void:
	var background := ColorRect.new()
	background.position = Vector2(12.0, 12.0)
	background.size = Vector2(700.0, 222.0)
	background.color = Color(0.05, 0.04, 0.03, 0.78)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_label = Label.new()
	_label.position = Vector2(24.0, 20.0)
	_label.size = Vector2(676.0, 206.0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("font_color", Color("ead9b7"))
	_label.add_theme_font_size_override("font_size", 16)
	add_child(_label)
