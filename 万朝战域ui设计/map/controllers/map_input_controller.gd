class_name MapInputController
extends Node

const CLICK_DRAG_THRESHOLD := 12.0
const LONG_PRESS_DURATION := 0.45  ## 长按触发侦察的时间（秒）

var _camera_rig: MapCameraRig
var _map_world: MapWorld
var _mouse_pressed := false
var _mouse_rotating := false
var _mouse_start_position := Vector2.ZERO
var _mouse_dragged := false
var _touch_positions: Dictionary = {}      ## {index: Vector2}
var _touch_start_positions: Dictionary = {}  ## {index: Vector2}
var _long_press_timer: SceneTreeTimer
var _long_press_position := Vector2.ZERO
var _long_press_triggered := false


func setup(camera_rig: MapCameraRig, map_world: MapWorld) -> void:
	_camera_rig = camera_rig
	_map_world = map_world


func handle_input(
	event: InputEvent,
	source_size: Vector2,
	viewport_size: Vector2
) -> bool:
	if _camera_rig == null or _map_world == null:
		return false
	if not _camera_rig.input_enabled:
		return true
	if event is InputEventMouseButton:
		return _handle_mouse_button(event, source_size, viewport_size)
	if event is InputEventMouseMotion:
		return _handle_mouse_motion(event, source_size, viewport_size)
	if event is InputEventScreenTouch:
		return _handle_screen_touch(event, source_size, viewport_size)
	if event is InputEventScreenDrag:
		return _handle_screen_drag(event, source_size, viewport_size)
	return false


func _handle_mouse_button(
	event: InputEventMouseButton,
	source_size: Vector2,
	viewport_size: Vector2
) -> bool:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_camera_rig.zoom_by_factor(1.12, viewport_size)
		return true
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_camera_rig.zoom_by_factor(1.0 / 1.12, viewport_size)
		return true
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_pressed = true
			_mouse_dragged = false
			_mouse_start_position = event.position
			# 启动长按检测
			_start_long_press(event.position, source_size, viewport_size)
		else:
			if _mouse_pressed and not _mouse_dragged and not _long_press_triggered:
				_map_world.select_at_viewport_position(
					_scale_position(event.position, source_size, viewport_size)
				)
			_mouse_pressed = false
			_cancel_long_press()
		return true
	# 右键：侦察请求（桌面）
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_mouse_rotating = _camera_rig.is_orbit_enabled()
			# 经营模式下右键=旋转，战争模式下右键=侦察请求
			if not _camera_rig.is_orbit_enabled():
				_map_world.request_scout_at_viewport_position(
					_scale_position(event.position, source_size, viewport_size)
				)
		else:
			_mouse_rotating = false
		return true
	if event.button_index == MOUSE_BUTTON_MIDDLE:
		_mouse_rotating = event.pressed and _camera_rig.is_orbit_enabled()
		return true
	return false


func _handle_mouse_motion(
	event: InputEventMouseMotion,
	source_size: Vector2,
	viewport_size: Vector2
) -> bool:
	if _mouse_pressed:
		if event.position.distance_to(_mouse_start_position) >= CLICK_DRAG_THRESHOLD:
			_mouse_dragged = true
			_cancel_long_press()
		_camera_rig.pan_by_screen_delta(
			_scale_delta(event.relative, source_size, viewport_size),
			viewport_size
		)
		return true
	if _mouse_rotating and _camera_rig.is_orbit_enabled():
		_camera_rig.orbit_by_screen_delta(
			_scale_delta(event.relative, source_size, viewport_size)
		)
		return true
	# 建造模式下鼠标悬停：预览跟随指向格子。
	# 到此处时未按下拖拽、未旋转，不影响既有平移/旋转逻辑。
	if _map_world.is_build_mode_active():
		_map_world.hover_build_position(
			_scale_position(event.position, source_size, viewport_size)
		)
		return true
	return false


func _handle_screen_touch(
	event: InputEventScreenTouch,
	source_size: Vector2,
	viewport_size: Vector2
) -> bool:
	if event.pressed:
		_touch_positions[event.index] = event.position
		_touch_start_positions[event.index] = event.position
		# 单指按下时启动长按计时
		if _touch_positions.size() == 1:
			_start_long_press(event.position, source_size, viewport_size)
	else:
		var start_position: Vector2 = _touch_start_positions.get(event.index, event.position)
		if (
			_touch_positions.size() == 1
			and event.position.distance_to(start_position) < CLICK_DRAG_THRESHOLD
			and not _long_press_triggered
		):
			_map_world.select_at_viewport_position(
				_scale_position(event.position, source_size, viewport_size)
			)
		if _touch_positions.size() <= 1:
			_cancel_long_press()
		_touch_positions.erase(event.index)
		_touch_start_positions.erase(event.index)
	return true


func _handle_screen_drag(
	event: InputEventScreenDrag,
	source_size: Vector2,
	viewport_size: Vector2
) -> bool:
	if not _touch_positions.has(event.index):
		_touch_positions[event.index] = event.position - event.relative
	var previous_position: Vector2 = _touch_positions[event.index]
	_touch_positions[event.index] = event.position
	var start_position: Vector2 = _touch_start_positions.get(event.index, event.position)
	if event.position.distance_to(start_position) >= CLICK_DRAG_THRESHOLD:
		_cancel_long_press()
	if _touch_positions.size() == 1:
		_camera_rig.pan_by_screen_delta(
			_scale_delta(event.position - previous_position, source_size, viewport_size),
			viewport_size
		)
		return true
	if _touch_positions.size() == 2:
		var indices := _touch_positions.keys()
		var other_index: int = indices[0] if indices[1] == event.index else indices[1]
		var other_position: Vector2 = _touch_positions[other_index]
		var old_centroid := (previous_position + other_position) * 0.5
		var new_centroid := (event.position + other_position) * 0.5
		var old_distance := previous_position.distance_to(other_position)
		var new_distance := event.position.distance_to(other_position)
		if old_distance > 1.0 and new_distance > 1.0:
			_camera_rig.zoom_by_factor(new_distance / old_distance, viewport_size)
		if _camera_rig.is_orbit_enabled():
			_camera_rig.orbit_by_screen_delta(
				_scale_delta(new_centroid - old_centroid, source_size, viewport_size)
			)
		return true
	return true


func cancel_active_gestures() -> void:
	_mouse_pressed = false
	_mouse_rotating = false
	_mouse_dragged = false
	_cancel_long_press()
	_touch_positions.clear()
	_touch_start_positions.clear()


## ——— 长按侦察 ———

func _start_long_press(position: Vector2, source_size: Vector2, viewport_size: Vector2) -> void:
	_cancel_long_press()
	_long_press_triggered = false
	_long_press_position = position
	# 地图未就绪或节点未加入场景树时不启动长按计时器。
	# 空值判断覆盖：1) _map_world 未注入  2) 节点未挂入 SceneTree（头显模式） 3) 地图初始化未完成
	if _map_world == null:
		return
	if _map_world.init_state != MapWorld.MapInitState.READY:
		return
	var tree := _map_world.get_tree()
	if tree == null:
		return
	_long_press_timer = tree.create_timer(LONG_PRESS_DURATION)
	_long_press_timer.timeout.connect(
		_on_long_press.bind(source_size, viewport_size),
		CONNECT_ONE_SHOT
	)


func _cancel_long_press() -> void:
	_long_press_triggered = false
	if _long_press_timer != null:
		if _long_press_timer.timeout.is_connected(_on_long_press):
			_long_press_timer.timeout.disconnect(_on_long_press)
		_long_press_timer = null


func _on_long_press(source_size: Vector2, viewport_size: Vector2) -> void:
	if _mouse_dragged:
		return
	_long_press_triggered = true
	_map_world.request_scout_at_viewport_position(
		_scale_position(_long_press_position, source_size, viewport_size)
	)


func _scale_position(
	position: Vector2,
	source_size: Vector2,
	viewport_size: Vector2
) -> Vector2:
	return Vector2(
		position.x * viewport_size.x / maxf(source_size.x, 1.0),
		position.y * viewport_size.y / maxf(source_size.y, 1.0)
	)


func _scale_delta(
	delta: Vector2,
	source_size: Vector2,
	viewport_size: Vector2
) -> Vector2:
	return Vector2(
		delta.x * viewport_size.x / maxf(source_size.x, 1.0),
		delta.y * viewport_size.y / maxf(source_size.y, 1.0)
	)
