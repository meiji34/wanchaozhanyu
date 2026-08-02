class_name MapInputAnchor
extends SubViewportContainer

@onready var _map_viewport: SubViewport = $MapViewport

var _map_world: MapWorld


func set_map_world(map_world: MapWorld) -> void:
	_map_world = map_world


func _gui_input(event: InputEvent) -> void:
	if _map_world == null:
		return
	var handled: bool = _map_world.handle_map_input(
		event,
		size,
		Vector2(_map_viewport.size)
	)
	if handled:
		accept_event()
