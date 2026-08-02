@tool
extends McpTestSuite


func suite_name() -> String:
	return "demo_map"


func test_coordinate_round_trip_and_bounds() -> void:
	var config := MapGenerationConfig.new()
	var data := DemoMapData.new(
		config.map_size,
		config.chunk_size,
		config.cell_size,
		config.seed
	)
	var samples: Array[Vector2i] = [
		Vector2i(-100, -100),
		Vector2i(-1, -1),
		Vector2i.ZERO,
		Vector2i(99, 99),
	]
	for grid_position in samples:
		assert_eq(
			data.world_to_grid(data.grid_to_world(grid_position)),
			grid_position,
			"格子与世界坐标应可往返转换"
		)
	assert_true(data.is_valid_grid(Vector2i(-100, -100)))
	assert_true(data.is_valid_grid(Vector2i(99, 99)))
	assert_false(data.is_valid_grid(Vector2i(100, 0)))
	assert_eq(data.grid_to_chunk(Vector2i(-1, -1)), Vector2i(-1, -1))
	assert_eq(data.grid_to_chunk(Vector2i(0, 0)), Vector2i.ZERO)


func test_generator_produces_required_demo_content() -> void:
	var data := DemoMapGenerator.generate(MapGenerationConfig.new())
	var terrain_counts := {
		MapTileTypes.Terrain.PLAIN: 0,
		MapTileTypes.Terrain.MOUNTAIN: 0,
		MapTileTypes.Terrain.RIVER: 0,
	}
	var road_count := 0
	for tile_variant in data.tiles.values():
		var tile := tile_variant as MapTileData
		terrain_counts[tile.terrain_type] += 1
		if tile.has_road:
			road_count += 1
	assert_eq(data.tiles.size(), 40000, "演示地图必须生成 200×200 个格子")
	assert_eq(data.cities.size(), 12, "首版必须生成 12 座城市")
	assert_eq(data.passes.size(), 6, "首版生成 6 个关隘占位")
	for city in data.cities:
		assert_eq(city.footprint_size, Vector2i(13, 13), "每座城池必须占用 13×13 格")
		assert_eq(
			city.get_world_footprint_size(data.cell_size),
			Vector2(26.0, 26.0),
			"单格 2 世界单位时城池占地必须为 26×26 世界单位"
		)
		var occupied_rect := city.get_occupied_grid_rect()
		for grid_y in range(occupied_rect.position.y, occupied_rect.end.y):
			for grid_x in range(occupied_rect.position.x, occupied_rect.end.x):
				assert_eq(
					data.get_city_at_grid(Vector2i(grid_x, grid_y)),
					city,
					"城池占地区域内的任意格子都应命中该城池"
				)
	assert_gt(terrain_counts[MapTileTypes.Terrain.PLAIN], 10000)
	assert_gt(terrain_counts[MapTileTypes.Terrain.MOUNTAIN], 500)
	assert_gt(terrain_counts[MapTileTypes.Terrain.RIVER], 200)
	assert_gt(road_count, 200)


func test_map_world_scene_has_stable_mount_structure() -> void:
	var packed := load("res://map/map_world.tscn") as PackedScene
	assert_true(packed != null, "地图主场景应可加载")
	if packed == null:
		return
	var world := track(packed.instantiate()) as Node
	assert_true(world is Node3D)
	assert_true(world.has_node("MapController"))
	assert_true(world.has_node("CameraRig/Camera3D"))
	assert_true(world.has_node("ChunkRoot"))
	assert_true(world.has_node("EntityRoot"))
	assert_true(world.has_node("SelectionRoot"))


func test_camera_supports_close_zoom_and_free_orbit() -> void:
	var camera_rig := track(MapCameraRig.new()) as MapCameraRig
	camera_rig.zoom_by_factor(100.0, Vector2(960.0, 540.0))
	assert_eq(camera_rig.ortho_size, 8.0, "最近缩放必须允许正交尺寸 8")

	var starting_yaw := camera_rig.yaw_radians
	var starting_pitch := camera_rig.pitch_degrees
	camera_rig.orbit_by_screen_delta(Vector2(120.0, 50.0))
	assert_ne(camera_rig.yaw_radians, starting_yaw, "水平拖动必须改变相机方位")
	assert_gt(camera_rig.pitch_degrees, starting_pitch, "向下拖动必须提高俯仰角")

	camera_rig.set_pitch_degrees(-100.0)
	assert_eq(camera_rig.pitch_degrees, 20.0, "俯仰下限必须保持安全")
	camera_rig.set_pitch_degrees(100.0)
	assert_eq(camera_rig.pitch_degrees, 80.0, "俯仰上限必须保持安全")


func test_mouse_and_touch_input_can_orbit_camera() -> void:
	var camera_rig := track(MapCameraRig.new()) as MapCameraRig
	var map_world := track(MapWorld.new()) as MapWorld
	var input_controller := track(MapInputController.new()) as MapInputController
	input_controller.setup(camera_rig, map_world)

	var mouse_press := InputEventMouseButton.new()
	mouse_press.button_index = MOUSE_BUTTON_RIGHT
	mouse_press.pressed = true
	input_controller.handle_input(mouse_press, Vector2(960.0, 540.0), Vector2(960.0, 540.0))
	var mouse_motion := InputEventMouseMotion.new()
	mouse_motion.relative = Vector2(100.0, 40.0)
	input_controller.handle_input(mouse_motion, Vector2(960.0, 540.0), Vector2(960.0, 540.0))
	assert_ne(camera_rig.yaw_radians, 0.0, "右键水平拖动必须旋转相机")
	assert_gt(camera_rig.pitch_degrees, MapCameraRig.DEFAULT_PITCH_DEGREES, "右键向下拖动必须提高俯仰角")

	camera_rig.yaw_radians = 0.0
	camera_rig.pitch_degrees = MapCameraRig.DEFAULT_PITCH_DEGREES
	var first_touch := InputEventScreenTouch.new()
	first_touch.index = 0
	first_touch.position = Vector2(400.0, 300.0)
	first_touch.pressed = true
	input_controller.handle_input(first_touch, Vector2(960.0, 540.0), Vector2(960.0, 540.0))
	var second_touch := InputEventScreenTouch.new()
	second_touch.index = 1
	second_touch.position = Vector2(600.0, 300.0)
	second_touch.pressed = true
	input_controller.handle_input(second_touch, Vector2(960.0, 540.0), Vector2(960.0, 540.0))
	var first_drag := InputEventScreenDrag.new()
	first_drag.index = 0
	first_drag.position = Vector2(420.0, 320.0)
	first_drag.relative = Vector2(20.0, 20.0)
	input_controller.handle_input(first_drag, Vector2(960.0, 540.0), Vector2(960.0, 540.0))
	var second_drag := InputEventScreenDrag.new()
	second_drag.index = 1
	second_drag.position = Vector2(620.0, 320.0)
	second_drag.relative = Vector2(20.0, 20.0)
	input_controller.handle_input(second_drag, Vector2(960.0, 540.0), Vector2(960.0, 540.0))
	assert_ne(camera_rig.yaw_radians, 0.0, "双指整体水平拖动必须旋转相机")
	assert_gt(camera_rig.pitch_degrees, MapCameraRig.DEFAULT_PITCH_DEGREES, "双指向下拖动必须提高俯仰角")


func test_terrain_texture_materials_are_available() -> void:
	var grass_material_path := "res://map/materials/grass_ground_material.tres"
	var river_material_path := "res://map/materials/river_water_material.tres"
	assert_true(
		ResourceLoader.exists(grass_material_path, "Material"),
		"草地共享材质必须可用"
	)
	assert_true(
		ResourceLoader.exists(river_material_path, "Material"),
		"河流共享材质必须可用"
	)

	var grass_material := load(grass_material_path) as ShaderMaterial
	var river_material := load(river_material_path) as ShaderMaterial
	assert_true(grass_material != null, "草地材质必须能加载为 ShaderMaterial")
	assert_true(river_material != null, "河流材质必须能加载为 ShaderMaterial")
	if grass_material != null:
		assert_true(
			grass_material.get_shader_parameter("ground_texture") is Texture2D,
			"草地材质必须绑定纹理"
		)
	if river_material != null:
		assert_true(
			river_material.get_shader_parameter("water_texture") is Texture2D,
			"河流材质必须绑定纹理"
		)
