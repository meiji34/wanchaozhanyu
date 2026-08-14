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
	for button_name in ["ZoomIn", "ZoomOut", "ToggleViewMode", "ResetView"]:
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
	var resource_point := data.resource_points[0] as MapResourcePointData
	var resource_snapshot := world.get_resource_snapshot(resource_point.resource_id)
	assert_eq(resource_snapshot.get("kind"), "resource")
	assert_eq(resource_snapshot.get("id"), resource_point.resource_id)
	assert_eq(resource_snapshot.get("tile_id"), resource_point.grid_position)
	assert_has_key(resource_snapshot, "resource_name")
	assert_true(bool(resource_snapshot.get("neutral", false)))


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
	assert_eq(camera_rig.pitch_degrees, MapCameraRig.DEFAULT_MANAGEMENT_PITCH_DEGREES)
	camera_rig.set_view_mode(MapCameraRig.ViewMode.BATTLE_2_5D)
	assert_eq(camera_rig.pitch_degrees, MapCameraRig.DEFAULT_BATTLE_PITCH_DEGREES)
	camera_rig.pitch_degrees = 70.0
	camera_rig.reset_view(Vector2(1280.0, 720.0))
	assert_eq(camera_rig.pitch_degrees, MapCameraRig.DEFAULT_BATTLE_PITCH_DEGREES)


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
	# 动作按钮改为在 MapInteractionPanel 中生成，SelectionDrawer 不再持有 SelectionAction
	var interaction_panel := hud.find_child("MapInteractionPanel", true, false) as MapInteractionPanel
	assert_true(interaction_panel != null)
	assert_false(interaction_panel.visible)
	for node in overlay.find_children("*", "Button", true, false):
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
	# 行动面板应已显示并包含行动按钮
	assert_true(interaction_panel.visible)
	assert_true(interaction_panel.get_visible_action_count() > 0, "城市目标应至少产生一个行动按钮")
	hud.call("_on_map_selection_cleared")
	assert_false(selection_drawer.visible)
	assert_false(interaction_panel.visible)


func test_hud_building_selection_bar_and_rotation_flow() -> void:
	var packed := load("res://ui/hud/main_hud.tscn") as PackedScene
	assert_true(packed != null)
	if packed == null:
		return
	var hud := track(packed.instantiate()) as Control
	(Engine.get_main_loop() as SceneTree).root.add_child(hud)
	var map_area := hud._map_area as MapArea
	map_area.call("_load_map_world")
	var world := map_area.get_map_world()
	assert_true(world != null, "地图必须挂载后才能测试建造流程")
	if world == null:
		return
	var construction := world.get_construction_controller()
	var select_panel := hud.find_child("BuildingSelectPanel", true, false) as PanelContainer
	assert_true(select_panel != null, "建筑选择栏必须存在")
	assert_false(select_panel.visible, "选择栏初始隐藏")
	# 打开选择栏：只保留建筑选择、3D 展示和开始建造，不再出现方向按钮
	hud.call("_toggle_build_mode")
	assert_true(select_panel.visible, "建造按钮打开建筑选择栏")
	for node in select_panel.find_children("*", "Button", true, false):
		var button := node as Button
		assert_false(
			["北", "东", "南", "西"].has(button.text),
			"建筑选择栏不得保留方向按钮：%s" % button.text
		)
	var preview_root := hud._select_preview_root as Node3D
	var preview_mesh := hud._select_preview_mesh as MeshInstance3D
	assert_true(preview_root != null)
	assert_true(preview_mesh != null)
	# 展示动画只旋转 PreviewRoot，不改变模型局部方向或任何真实 rotation_index
	hud.call("_process", 2.0)
	assert_gt(preview_root.rotation.y, 0.0, "选择栏 3D Preview 应缓慢自动旋转")
	assert_eq(preview_mesh.rotation, Vector3.ZERO, "展示模型局部方向保持默认值")
	# A → B → A 快速切换：复用同一个 SubViewport/Camera/Light，并从统一展示角度重启
	hud.call("_on_building_option_pressed", 1)
	assert_true(is_zero_approx(preview_root.rotation.y), "切换建筑 B 时展示角度重置")
	hud.call("_on_building_option_pressed", 0)
	assert_true(is_zero_approx(preview_root.rotation.y), "切回建筑 A 时展示角度重置")
	hud.call("_on_building_option_pressed", 1)
	assert_eq(select_panel.find_children("*", "SubViewport", true, false).size(), 1)
	assert_eq(select_panel.find_children("*", "Camera3D", true, false).size(), 1)
	assert_eq(select_panel.find_children("*", "DirectionalLight3D", true, false).size(), 1)
	assert_eq(
		(preview_mesh.mesh as BoxMesh).size,
		(hud._building_catalog[1] as MapBuildingDefinition).get_world_size(
			MapGenerationConfig.DEFAULT_CELL_SIZE
		),
		"选择预览网格保持基础 3×4 尺寸"
	)
	# 让 UI Preview 累积任意视觉角度后开始建造，地图仍必须使用默认真实方向 0
	hud.call("_process", 3.0)
	assert_gt(preview_root.rotation.y, 0.0)
	hud.call("_on_start_build_pressed")
	assert_false(select_panel.visible, "开始建造后选择栏关闭")
	assert_true(map_area.is_build_mode_active(), "开始建造后进入地图建造模式")
	assert_eq(construction.get_rotation_index(), 0, "UI Preview 视觉角度不得写入真实建造方向")
	var build_panel := hud.find_child("ConstructionPanel", true, false) as PanelContainer
	assert_true(build_panel.visible, "建造面板显示")
	assert_contains(hud._build_title_label.text, "北", "地图 Preview 从默认方向开始")
	# 地图阶段旋转按钮仍完整保留：0°→90°
	hud.call("_on_build_rotate_pressed")
	assert_eq(construction.get_rotation_index(), 1, "地图旋转按钮切换到 90°")
	# 取消建造：退出模式；再次打开选择栏仍从统一展示角度开始
	hud.call("_on_build_cancel_pressed")
	assert_false(map_area.is_build_mode_active(), "取消退出建造模式")
	hud.call("_toggle_build_mode")
	assert_true(is_zero_approx(preview_root.rotation.y), "取消后重开选择栏展示角度重置")
	hud.call("_close_building_select_panel")
