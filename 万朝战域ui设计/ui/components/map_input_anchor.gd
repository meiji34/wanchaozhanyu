extends SubViewportContainer

const MAP_SCENE_PATH := "res://map/map_world.tscn"

@onready var _map_viewport: SubViewport = $MapViewport

var _map_world: Node3D


func _ready() -> void:
	call_deferred("_load_map_world")


func _gui_input(event: InputEvent) -> void:
	if _map_world == null or not _map_world.has_method("handle_map_input"):
		return
	var handled: bool = _map_world.handle_map_input(
		event,
		size,
		Vector2(_map_viewport.size)
	)
	if handled:
		accept_event()


func _load_map_world() -> void:
	if not ResourceLoader.exists(MAP_SCENE_PATH):
		push_warning("地图场景不存在，保留 HUD 地图占位层：%s" % MAP_SCENE_PATH)
		return
	var packed_scene := load(MAP_SCENE_PATH) as PackedScene
	if packed_scene == null:
		push_warning("地图场景加载失败，保留 HUD 地图占位层")
		return
	var instance := packed_scene.instantiate()
	if not instance is Node3D:
		push_warning("地图场景根节点不是 Node3D，保留 HUD 地图占位层")
		instance.queue_free()
		return
	_map_world = instance as Node3D
	_map_viewport.add_child(_map_world)
	_set_placeholder_visible(false)


func _set_placeholder_visible(visible_state: bool) -> void:
	var map_area := get_parent()
	if map_area == null:
		return
	var background := map_area.get_node_or_null("PlaceholderBackground") as CanvasItem
	var label := map_area.get_node_or_null("PlaceholderLabel") as CanvasItem
	var hint := map_area.get_node_or_null("MapUILayer/Hint") as Label
	if background != null:
		background.visible = visible_state
	if label != null:
		label.visible = visible_state
	if hint != null and not visible_state:
		hint.text = "单指/左键平移 · 滚轮/双指缩放 · 右/中键或双指拖动旋转与俯仰"
