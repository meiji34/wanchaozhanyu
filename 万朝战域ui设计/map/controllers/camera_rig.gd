class_name MapCameraRig
extends Node3D

signal camera_changed

const DEFAULT_ORTHO_SIZE := 42.0
const MIN_ORTHO_SIZE := 8.0
const MAX_ORTHO_SIZE := 90.0
const DEFAULT_PITCH_DEGREES := 55.0
const MIN_PITCH_DEGREES := 20.0
const MAX_PITCH_DEGREES := 80.0
const CAMERA_DISTANCE := 110.0
const ROTATION_SENSITIVITY := 0.006
const PITCH_SENSITIVITY := 0.16

@onready var camera: Camera3D = $Camera3D

var target_position := Vector3.ZERO
var ortho_size := DEFAULT_ORTHO_SIZE
var yaw_radians := 0.0
var pitch_degrees := DEFAULT_PITCH_DEGREES
var _map_half_extent := Vector2(200.0, 200.0)
var _last_viewport_size := Vector2(960.0, 540.0)


func _ready() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
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


func pan_by_screen_delta(delta: Vector2, viewport_size: Vector2) -> void:
	if viewport_size.y <= 0.0:
		return
	_last_viewport_size = viewport_size
	var world_units_per_pixel := ortho_size / viewport_size.y
	var right := Vector3(cos(yaw_radians), 0.0, -sin(yaw_radians))
	var view_forward := Vector3(-sin(yaw_radians), 0.0, -cos(yaw_radians))
	target_position += (
		-right * delta.x * world_units_per_pixel
		+ view_forward * delta.y * world_units_per_pixel
	)
	_clamp_target(viewport_size)
	_apply_camera_transform()


func zoom_by_factor(factor: float, viewport_size: Vector2) -> void:
	if factor <= 0.0:
		return
	_last_viewport_size = viewport_size
	ortho_size = clampf(ortho_size / factor, MIN_ORTHO_SIZE, MAX_ORTHO_SIZE)
	_clamp_target(viewport_size)
	_apply_camera_transform()


func rotate_by_screen_delta(delta_x: float) -> void:
	orbit_by_screen_delta(Vector2(delta_x, 0.0))


func orbit_by_screen_delta(delta: Vector2) -> void:
	yaw_radians = fposmod(yaw_radians - delta.x * ROTATION_SENSITIVITY, TAU)
	pitch_degrees = clampf(
		pitch_degrees + delta.y * PITCH_SENSITIVITY,
		MIN_PITCH_DEGREES,
		MAX_PITCH_DEGREES
	)
	_apply_camera_transform()


func set_pitch_degrees(value: float) -> void:
	pitch_degrees = clampf(value, MIN_PITCH_DEGREES, MAX_PITCH_DEGREES)
	_apply_camera_transform()


func screen_to_ground(screen_position: Vector2) -> Variant:
	if camera == null:
		return null
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	return Plane(Vector3.UP, 0.0).intersects_ray(ray_origin, ray_direction)


func get_target_grid(map_data: DemoMapData) -> Vector2i:
	return map_data.world_to_grid(target_position)


func get_debug_data() -> Dictionary:
	return {
		"target": target_position,
		"ortho_size": ortho_size,
		"yaw_degrees": rad_to_deg(yaw_radians),
		"pitch_degrees": pitch_degrees,
	}


func _clamp_target(viewport_size: Vector2) -> void:
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var half_visible_x := ortho_size * aspect * 0.5
	var half_visible_z := ortho_size * 0.5
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
	var horizontal_distance := cos(pitch_radians) * CAMERA_DISTANCE
	camera.position = Vector3(
		sin(yaw_radians) * horizontal_distance,
		sin(pitch_radians) * CAMERA_DISTANCE,
		cos(yaw_radians) * horizontal_distance
	)
	camera.size = ortho_size
	camera.look_at(target_position, Vector3.UP)
	camera_changed.emit()
