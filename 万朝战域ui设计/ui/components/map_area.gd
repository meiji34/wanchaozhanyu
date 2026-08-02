class_name MapArea
extends Control

signal map_ready
signal map_load_failed(message: String)
signal selection_changed(selection: Dictionary)
signal selection_cleared

@export_file("*.tscn") var map_scene_path := "res://map/map_world.tscn"

@onready var _placeholder_background: ColorRect = $PlaceholderBackground
@onready var _placeholder_label: Label = $PlaceholderLabel
@onready var _input_anchor: MapInputAnchor = $MapViewportContainer
@onready var _map_viewport: SubViewport = $MapViewportContainer/MapViewport
@onready var _zoom_in_button: Button = $MapUILayer/MapTools/ZoomIn
@onready var _zoom_out_button: Button = $MapUILayer/MapTools/ZoomOut
@onready var _reset_button: Button = $MapUILayer/MapTools/ResetView

var _map_world: MapWorld


func _ready() -> void:
	_zoom_in_button.pressed.connect(zoom_in)
	_zoom_out_button.pressed.connect(zoom_out)
	_reset_button.pressed.connect(reset_view)
	call_deferred("_load_map_world")


func zoom_in() -> void:
	if _map_world != null:
		_map_world.zoom_by_factor(1.25, Vector2(_map_viewport.size))


func zoom_out() -> void:
	if _map_world != null:
		_map_world.zoom_by_factor(0.8, Vector2(_map_viewport.size))


func reset_view() -> void:
	if _map_world != null:
		_map_world.reset_view(Vector2(_map_viewport.size))


func get_map_world() -> MapWorld:
	return _map_world


func _load_map_world() -> void:
	if not ResourceLoader.exists(map_scene_path, "PackedScene"):
		_fail_map_load("地图场景不存在：%s" % map_scene_path)
		return
	var packed_scene := load(map_scene_path) as PackedScene
	if packed_scene == null:
		_fail_map_load("地图场景无法读取：%s" % map_scene_path)
		return
	var instance := packed_scene.instantiate()
	if not instance is MapWorld:
		instance.queue_free()
		_fail_map_load("地图场景根节点必须是 MapWorld")
		return
	_map_world = instance as MapWorld
	_map_world.map_ready.connect(_on_map_ready)
	_map_world.city_selected.connect(_on_city_selected)
	_map_world.tile_selected.connect(_on_tile_selected)
	_map_world.selection_cleared.connect(_on_selection_cleared)
	_map_viewport.add_child(_map_world)
	_input_anchor.set_map_world(_map_world)
	_set_placeholder_visible(false)


func _fail_map_load(message: String) -> void:
	push_warning(message)
	_placeholder_label.text = "地图暂不可用"
	_set_placeholder_visible(true)
	map_load_failed.emit(message)


func _set_placeholder_visible(visible_state: bool) -> void:
	_placeholder_background.visible = visible_state
	_placeholder_label.visible = visible_state


func _on_map_ready() -> void:
	map_ready.emit()


func _on_city_selected(city_id: String, _tile_id: Vector2i) -> void:
	var snapshot := _map_world.get_city_snapshot(city_id)
	if not snapshot.is_empty():
		selection_changed.emit(snapshot)


func _on_tile_selected(tile_id: Vector2i) -> void:
	var snapshot := _map_world.get_tile_snapshot(tile_id)
	if not snapshot.is_empty():
		selection_changed.emit(snapshot)


func _on_selection_cleared() -> void:
	selection_cleared.emit()
