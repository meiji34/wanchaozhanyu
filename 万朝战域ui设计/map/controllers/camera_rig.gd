class_name MapCameraRig
extends Node3D

signal camera_changed
signal view_mode_changed(mode: int)

enum ViewMode {
	MANAGEMENT_3D,
	BATTLE_2_5D,
}

const DEFAULT_ORTHO_SIZE := 60.0
const MIN_ORTHO_SIZE := 18.0
const MAX_ORTHO_SIZE := 90.0
const DEFAULT_PERSPECTIVE_FOV := 48.0
const DEFAULT_PERSPECTIVE_DISTANCE := 150.0
const MIN_PERSPECTIVE_DISTANCE := 35.0
const MAX_PERSPECTIVE_DISTANCE := 180.0
const DEFAULT_MANAGEMENT_PITCH_DEGREES := 55.0
const DEFAULT_BATTLE_PITCH_DEGREES := 45.0
const DEFAULT_PITCH_DEGREES := DEFAULT_MANAGEMENT_PITCH_DEGREES
const MIN_PITCH_DEGREES := 20.0
const MAX_PITCH_DEGREES := 75.0
const BATTLE_CAMERA_DISTANCE := 110.0
const ROTATION_SENSITIVITY := 0.006
const PITCH_SENSITIVITY := 0.16

@onready var camera: Camera3D = get_node_or_null("Camera3D") as Camera3D

var view_mode: int = ViewMode.MANAGEMENT_3D
var input_enabled := true
var target_position := Vector3.ZERO
var ortho_size := DEFAULT_ORTHO_SIZE
var perspective_distance := DEFAULT_PERSPECTIVE_DISTANCE
var yaw_radians := 0.0
var pitch_degrees := DEFAULT_MANAGEMENT_PITCH_DEGREES
var _map_half_extent := Vector2(400.0, 400.0)
var _last_viewport_size := Vector2(960.0, 540.0)
var _management_yaw_radians := 0.0
var _management_pitch_degrees := DEFAULT_MANAGEMENT_PITCH_DEGREES
var _management_distance := DEFAULT_PERSPECTIVE_DISTANCE


func _ready() -> void:
	if camera != null:
		camera.current = true
	_apply_camera_transform()


func configure_bounds(world_half_extent: Vector2) -> void:
	_map_half_extent = world_half_extent
	_clamp_target(_last_viewport_size)
	_apply_camera_transform()


func focus_world_position(world_position: Vector3, viewport_size: Vector2 = Vector2(960.0, 540.0)) -> void:
	_last_viewport_size = viewport_size
	target_position = Vector3(world_position.x, 0.0, world_position.z)
	_clamp_target(viewport_size)
	_apply_camera_transform()


func reset_view(viewport_size: Vector2 = Vector2(960.0, 540.0)) -> void:
	_last_viewport_size = viewport_size
	target_position = Vector3.ZERO
	ortho_size = DEFAULT_ORTHO_SIZE
	if view_mode == ViewMode.MANAGEMENT_3D:
		perspective_distance = DEFAULT_PERSPECTIVE_DISTANCE
		yaw_radians = 0.0
		pitch_degrees = DEFAULT_MANAGEMENT_PITCH_DEGREES
		_save_management_state()
	else:
		yaw_radians = 0.0
		pitch_degrees = DEFAULT_BATTLE_PITCH_DEGREES
	_clamp_target(viewport_size)
	_apply_camera_transform()


func set_view_mode(mode: int, viewport_size: Vector2 = Vector2(960.0, 540.0)) -> void:
	if mode != ViewMode.MANAGEMENT_3D and mode != ViewMode.BATTLE_2_5D:
		push_warning("未知地图相机模式：%s" % mode)
		return
	_last_viewport_size = viewport_size
	if mode == view_mode:
		return
	input_enabled = false
	if view_mode == ViewMode.MANAGEMENT_3D:
		_save_management_state()
	view_mode = mode
	if view_mode == ViewMode.MANAGEMENT_3D:
		yaw_radians = _management_yaw_radians
		pitch_degrees = _management_pitch_degrees
		perspective_distance = _management_distance
	else:
		yaw_radians = 0.0
		pitch_degrees = DEFAULT_BATTLE_PITCH_DEGREES
	_clamp_target(viewport_size)
	_apply_camera_transform()
	input_enabled = true
	view_mode_changed.emit(view_mode)


func toggle_view_mode(viewport_size: Vector2 = Vector2(960.0, 540.0)) -> void:
	var next_mode := (
		ViewMode.BATTLE_2_5D
		if view_mode == ViewMode.MANAGEMENT_3D
		else ViewMode.MANAGEMENT_3D
	)
	set_view_mode(next_mode, viewport_size)


func is_orbit_enabled() -> bool:
	return input_enabled and view_mode == ViewMode.MANAGEMENT_3D


func get_view_mode_display_name() -> String:
	return "经营 3D" if view_mode == ViewMode.MANAGEMENT_3D else "战争 2.5D"


func pan_by_screen_delta(delta: Vector2, viewport_size: Vector2) -> void:
	if not input_enabled or viewport_size.y <= 0.0:
		return
	_last_viewport_size = viewport_size
	var world_units_per_pixel := _get_visible_vertical_span() / viewport_size.y
	var right := Vector3(cos(yaw_radians), 0.0, -sin(yaw_radians))
	var view_forward := Vector3(-sin(yaw_radians), 0.0, -cos(yaw_radians))
	target_position += (
		-right * delta.x * world_units_per_pixel
		+ view_forward * delta.y * world_units_per_pixel
	)
	_clamp_target(viewport_size)
	_apply_camera_transform()


func zoom_by_factor(factor: float, viewport_size: Vector2) -> void:
	if not input_enabled or factor <= 0.0:
		return
	_last_viewport_size = viewport_size
	if view_mode == ViewMode.MANAGEMENT_3D:
		perspective_distance = clampf(
			perspective_distance / factor,
			MIN_PERSPECTIVE_DISTANCE,
			MAX_PERSPECTIVE_DISTANCE
		)
		_management_distance = perspective_distance
	else:
		ortho_size = clampf(ortho_size / factor, MIN_ORTHO_SIZE, MAX_ORTHO_SIZE)
	_clamp_target(viewport_size)
	_apply_camera_transform()


func rotate_by_screen_delta(delta_x: float) -> void:
	orbit_by_screen_delta(Vector2(delta_x, 0.0))


func orbit_by_screen_delta(delta: Vector2) -> void:
	if not is_orbit_enabled():
		return
	yaw_radians = fposmod(yaw_radians - delta.x * ROTATION_SENSITIVITY, TAU)
	pitch_degrees = clampf(
		pitch_degrees + delta.y * PITCH_SENSITIVITY,
		MIN_PITCH_DEGREES,
		MAX_PITCH_DEGREES
	)
	_save_management_state()
	_apply_camera_transform()


func set_pitch_degrees(value: float) -> void:
	if not is_orbit_enabled():
		return
	pitch_degrees = clampf(value, MIN_PITCH_DEGREES, MAX_PITCH_DEGREES)
	_save_management_state()
	_apply_camera_transform()


func screen_to_ground(screen_position: Vector2, map_data: DemoMapData = null) -> Variant:
	if camera == null:
		return null
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	if map_data != null:
		return map_data.intersect_heightfield_ray(ray_origin, ray_direction)
	# 仅供相机脱离地图数据进行独立测试时降级；正式地图拾取必须传入 MapData。
	return Plane(Vector3.UP, 0.0).intersects_ray(ray_origin, ray_direction)


func get_target_grid(map_data: DemoMapData) -> Vector2i:
	return map_data.world_to_grid(target_position)


func get_debug_data() -> Dictionary:
	return {
		"view_mode": view_mode,
		"view_mode_name": get_view_mode_display_name(),
		"projection": "perspective" if view_mode == ViewMode.MANAGEMENT_3D else "orthogonal",
		"input_enabled": input_enabled,
		"target": target_position,
		"ortho_size": ortho_size,
		"perspective_distance": perspective_distance,
		"yaw_degrees": rad_to_deg(yaw_radians),
		"pitch_degrees": pitch_degrees,
	}


func _clamp_target(viewport_size: Vector2) -> void:
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var half_visible_z := _get_visible_vertical_span() * 0.5
	var half_visible_x := half_visible_z * aspect
	var max_x := maxf(0.0, _map_half_extent.x - half_visible_x)
	var max_z := maxf(0.0, _map_half_extent.y - half_visible_z)
	target_position.x = clampf(target_position.x, -max_x, max_x)
	target_position.z = clampf(target_position.z, -max_z, max_z)
	target_position.y = 0.0


func _apply_camera_transform() -> void:
	if camera == null:
		return
	position = target_position
	var pitch_radians := deg_to_rad(pitch_degrees)
	var camera_distance := (
		perspective_distance
		if view_mode == ViewMode.MANAGEMENT_3D
		else BATTLE_CAMERA_DISTANCE
	)
	var horizontal_distance := cos(pitch_radians) * camera_distance
	camera.position = Vector3(
		sin(yaw_radians) * horizontal_distance,
		sin(pitch_radians) * camera_distance,
		cos(yaw_radians) * horizontal_distance
	)
	if view_mode == ViewMode.MANAGEMENT_3D:
		camera.set_perspective(DEFAULT_PERSPECTIVE_FOV, 0.1, 1000.0)
	else:
		camera.set_orthogonal(ortho_size, 0.1, 1000.0)
	camera.look_at(target_position, Vector3.UP)
	camera_changed.emit()


func _get_visible_vertical_span() -> float:
	if view_mode == ViewMode.BATTLE_2_5D:
		return ortho_size
	return 2.0 * perspective_distance * tan(deg_to_rad(DEFAULT_PERSPECTIVE_FOV) * 0.5)


func _save_management_state() -> void:
	_management_yaw_radians = yaw_radians
	_management_pitch_degrees = pitch_degrees
	_management_distance = perspective_distance
