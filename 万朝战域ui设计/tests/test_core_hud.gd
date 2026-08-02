@tool
extends McpTestSuite


func suite_name() -> String:
	return "core_hud"


func test_map_area_has_stable_mount_and_input_structure() -> void:
	var packed := load("res://ui/components/map_area.tscn") as PackedScene
	assert_true(packed != null, "MapArea 场景必须可加载")
	if packed == null:
		return
	var map_area := track(packed.instantiate()) as MapArea
	assert_true(map_area != null, "MapArea 必须使用稳定适配组件脚本")
	if map_area == null:
		return
	assert_eq(map_area.map_scene_path, "res://map/map_world.tscn")
	assert_true(map_area.has_node("MapViewportContainer/MapViewport"))
	assert_true(map_area.has_node("MapUILayer/MapTools"))
	assert_eq(map_area.mouse_filter, Control.MOUSE_FILTER_PASS)
	var ui_layer := map_area.get_node("MapUILayer") as Control
	assert_eq(ui_layer.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_map_tools_are_touch_sized_and_only_buttons_capture_input() -> void:
	var map_area := track(
		(load("res://ui/components/map_area.tscn") as PackedScene).instantiate()
	) as MapArea
	for button_name in ["ZoomIn", "ZoomOut", "ResetView"]:
		var button := map_area.get_node("MapUILayer/MapTools/%s" % button_name) as Button
		assert_true(button != null)
		assert_true(button.custom_minimum_size.x >= 56.0)
		assert_true(button.custom_minimum_size.y >= 56.0)
		assert_eq(button.mouse_filter, Control.MOUSE_FILTER_STOP)


func test_map_area_mounts_world_and_bridges_selection_signals() -> void:
	var map_area := track(
		(load("res://ui/components/map_area.tscn") as PackedScene).instantiate()
	) as MapArea
	var ready_events: Array[bool] = []
	var selections: Array[Dictionary] = []
	var cleared_events: Array[bool] = []
	map_area.map_ready.connect(func() -> void: ready_events.append(true))
	map_area.selection_changed.connect(func(selection: Dictionary) -> void: selections.append(selection))
	map_area.selection_cleared.connect(func() -> void: cleared_events.append(true))
	(Engine.get_main_loop() as SceneTree).root.add_child(map_area)
	map_area.call("_load_map_world")
	assert_true(map_area.get_map_world() != null, "MapArea 必须挂载 MapWorld")
	map_area.call("_on_map_ready")
	assert_eq(ready_events.size(), 1)
	map_area.call("_on_tile_selected", Vector2i.ZERO)
	assert_eq(selections.size(), 1)
	assert_eq(selections[0].get("kind"), "tile")
	map_area.call("_on_selection_cleared")
	assert_eq(cleared_events.size(), 1)


func test_map_area_keeps_placeholder_on_load_failure() -> void:
	var map_area := track(
		(load("res://ui/components/map_area.tscn") as PackedScene).instantiate()
	) as MapArea
	map_area.map_scene_path = "res://map/does_not_exist.tscn"
	var failures: Array[String] = []
	map_area.map_load_failed.connect(func(message: String) -> void: failures.append(message))
	(Engine.get_main_loop() as SceneTree).root.add_child(map_area)
	map_area.call("_load_map_world")
	assert_eq(failures.size(), 1)
	assert_contains(failures[0], "does_not_exist.tscn")
	assert_true(map_area.get_node("PlaceholderBackground").visible)
	assert_eq((map_area.get_node("PlaceholderLabel") as Label).text, "地图暂不可用")


func test_map_world_exposes_neutral_city_and_tile_snapshots() -> void:
	var data := DemoMapGenerator.generate(MapGenerationConfig.new())
	var controller := track(MapController.new()) as MapController
	controller.map_data = data
	var world := track(MapWorld.new()) as MapWorld
	world.map_controller = controller
	var city := data.cities[0] as MapCityData
	var city_snapshot := world.get_city_snapshot(city.city_id)
	assert_eq(city_snapshot.get("kind"), "city")
	assert_eq(city_snapshot.get("id"), city.city_id)
	assert_eq(city_snapshot.get("tile_id"), city.grid_position)
	assert_eq(city_snapshot.get("name"), city.display_name)
	assert_has_key(city_snapshot, "faction")
	var tile_snapshot := world.get_tile_snapshot(Vector2i.ZERO)
	assert_eq(tile_snapshot.get("kind"), "tile")
	assert_eq(tile_snapshot.get("tile_id"), Vector2i.ZERO)
	assert_has_key(tile_snapshot, "terrain")
	assert_has_key(tile_snapshot, "has_road")
	assert_has_key(tile_snapshot, "can_build_city")


func test_camera_reset_restores_command_view() -> void:
	var camera_rig := track(MapCameraRig.new()) as MapCameraRig
	camera_rig.target_position = Vector3(40.0, 0.0, -30.0)
	camera_rig.ortho_size = 18.0
	camera_rig.yaw_radians = 2.0
	camera_rig.pitch_degrees = 72.0
	camera_rig.reset_view(Vector2(1280.0, 720.0))
	assert_eq(camera_rig.target_position, Vector3.ZERO)
	assert_eq(camera_rig.ortho_size, MapCameraRig.DEFAULT_ORTHO_SIZE)
	assert_eq(camera_rig.yaw_radians, 0.0)
	assert_eq(camera_rig.pitch_degrees, MapCameraRig.DEFAULT_PITCH_DEGREES)


func test_hud_builds_overlay_and_selection_drawer_states() -> void:
	var packed := load("res://ui/hud/main_hud.tscn") as PackedScene
	assert_true(packed != null)
	if packed == null:
		return
	var hud := track(packed.instantiate()) as Control
	assert_true(hud != null)
	assert_eq(hud.mouse_filter, Control.MOUSE_FILTER_STOP)
	(Engine.get_main_loop() as SceneTree).root.add_child(hud)
	var overlay := hud.find_child("HUDOverlay", true, false) as Control
	var selection_drawer := hud.find_child("SelectionDrawer", true, false) as PanelContainer
	assert_true(overlay != null)
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_true(selection_drawer != null)
	assert_false(selection_drawer.visible)
	for node in hud.find_children("*", "Button", true, false):
		var button := node as Button
		assert_true(button.custom_minimum_size.y >= 56.0, "%s 必须达到 56px 触控高度" % button.name)
	hud.call("_on_map_selection_changed", {
		"kind": "city",
		"id": "city_test",
		"tile_id": Vector2i(4, 7),
		"name": "测试城池",
		"level": 3,
		"faction": "中立",
	})
	assert_true(selection_drawer.visible)
	var action := selection_drawer.find_child("SelectionAction", true, false) as Button
	assert_true(action != null)
	assert_true(action.visible)
	hud.call("_on_map_selection_cleared")
	assert_false(selection_drawer.visible)
