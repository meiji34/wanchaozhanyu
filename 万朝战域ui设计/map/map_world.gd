class_name MapWorld
extends Node3D

signal map_ready
signal tile_selected(tile_id: Vector2i)
signal city_selected(city_id: String, tile_id: Vector2i)
signal selection_cleared

@onready var map_controller: MapController = $MapController
@onready var camera_rig: MapCameraRig = $CameraRig
@onready var map_input_controller: MapInputController = $MapInputController
@onready var chunk_root: Node3D = $ChunkRoot
@onready var entity_root: Node3D = $EntityRoot
@onready var selection_root: Node3D = $SelectionRoot
@onready var debug_overlay: MapDebugOverlay = $DebugOverlay

var _selection_marker: MeshInstance3D
var _selected_city_id := ""


func _ready() -> void:
	_ensure_environment()
	_ensure_lighting()
	_build_selection_marker()
	map_input_controller.setup(camera_rig, self)
	map_controller.map_ready.connect(_on_map_ready)
	map_controller.initialize(camera_rig, chunk_root, entity_root)
	debug_overlay.setup(map_controller, camera_rig)


func handle_map_input(
	event: InputEvent,
	source_size: Vector2,
	viewport_size: Vector2
) -> bool:
	return map_input_controller.handle_input(event, source_size, viewport_size)


func select_at_viewport_position(viewport_position: Vector2) -> void:
	if map_controller.map_data == null:
		return
	var hit_variant: Variant = camera_rig.screen_to_ground(viewport_position)
	if hit_variant == null:
		clear_selection()
		return
	var world_position := hit_variant as Vector3
	var grid_position := map_controller.map_data.world_to_grid(world_position)
	if not map_controller.map_data.is_valid_grid(grid_position):
		clear_selection()
		return
	var city := map_controller.get_city_at_grid(grid_position)
	if city != null:
		_select_city(city)
	else:
		_select_tile(grid_position)


func clear_selection() -> void:
	_selected_city_id = ""
	map_controller.set_selected_city("")
	_selection_marker.visible = false
	selection_cleared.emit()


func set_debug_enabled(enabled: bool) -> void:
	debug_overlay.set_debug_enabled(enabled)


func get_debug_snapshot() -> Dictionary:
	var snapshot := map_controller.get_debug_snapshot()
	snapshot["camera"] = camera_rig.get_debug_data()
	snapshot["selected_city_id"] = _selected_city_id
	snapshot["selection_visible"] = _selection_marker.visible
	return snapshot


func _select_city(city: MapCityData) -> void:
	_selected_city_id = city.city_id
	map_controller.set_selected_city(city.city_id)
	_place_selection_marker(city.grid_position, true)
	city_selected.emit(city.city_id, city.grid_position)


func _select_tile(grid_position: Vector2i) -> void:
	_selected_city_id = ""
	map_controller.set_selected_city("")
	_place_selection_marker(grid_position, false)
	tile_selected.emit(grid_position)


func _place_selection_marker(grid_position: Vector2i, is_city: bool) -> void:
	var tile := map_controller.map_data.get_tile(grid_position)
	var height := tile.height if tile != null else 0.0
	var marker_grid_position := grid_position
	var footprint_size := Vector2i.ONE
	if is_city:
		var city := map_controller.get_city_at_grid(grid_position)
		if city != null:
			marker_grid_position = city.grid_position
			footprint_size = city.footprint_size
	_selection_marker.position = map_controller.map_data.grid_to_world(
		marker_grid_position,
		height + 0.08
	)
	_selection_marker.scale = Vector3(
		float(footprint_size.x),
		1.0,
		float(footprint_size.y)
	)
	_selection_marker.visible = true


func _build_selection_marker() -> void:
	_selection_marker = MeshInstance3D.new()
	_selection_marker.name = "SelectionMarker"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.82, 0.04, 1.82)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.72, 0.25, 0.58)
	material.emission_enabled = true
	material.emission = Color(0.95, 0.62, 0.18)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	_selection_marker.mesh = mesh
	_selection_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_selection_marker.visible = false
	selection_root.add_child(_selection_marker)


func _ensure_environment() -> void:
	if get_node_or_null("WorldEnvironment") != null:
		return
	var environment_node := WorldEnvironment.new()
	environment_node.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("161a16")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d8c6a4")
	environment.ambient_light_energy = 0.55
	environment_node.environment = environment
	add_child(environment_node)
	move_child(environment_node, 0)


func _ensure_lighting() -> void:
	if get_node_or_null("MapKeyLight") != null:
		return
	var key_light := DirectionalLight3D.new()
	key_light.name = "MapKeyLight"
	key_light.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	key_light.light_color = Color("f1d8ad")
	key_light.light_energy = 1.15
	key_light.shadow_enabled = false
	add_child(key_light)
	move_child(key_light, 1)


func _on_map_ready() -> void:
	map_ready.emit()
