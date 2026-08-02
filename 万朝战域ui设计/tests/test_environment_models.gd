@tool
extends McpTestSuite


func suite_name() -> String:
	return "environment_models"


func test_model_resources_and_wrapper_scene_are_available() -> void:
	var model_paths: Array[String] = [
		"res://map/assets/models/rts_ancient_pine_hy3d31.glb",
		"res://map/assets/models/rts_mountain_sharp_peak_hy3d31.glb",
		"res://map/assets/models/rts_mountain_long_ridge_hy3d31.glb",
		"res://map/assets/models/rts_mountain_rounded_cluster_hy3d31.glb",
	]
	for model_path in model_paths:
		assert_true(
			ResourceLoader.exists(model_path, "PackedScene"),
			"地图高精度模型必须能够作为 PackedScene 加载：%s" % model_path
		)
	assert_true(
		ResourceLoader.exists(
			"res://map/assets/model_scenes/map_feature_model.tscn",
			"PackedScene"
		),
		"地图装饰模型包装场景必须可用"
	)


func test_feature_model_can_normalize_a_generated_model() -> void:
	var wrapper_scene := load(
		"res://map/assets/model_scenes/map_feature_model.tscn"
	) as PackedScene
	assert_true(wrapper_scene != null)
	if wrapper_scene == null:
		return
	var feature := track(wrapper_scene.instantiate()) as MapFeatureModel
	assert_true(feature != null)
	if feature == null:
		return
	assert_true(
		feature.configure_to_footprint(
			"res://map/assets/models/rts_ancient_pine_hy3d31.glb",
			Vector2(5.4, 5.4)
		),
		"松树模型应能完成边界归一化并实例化"
	)
	assert_true(feature.has_node("Model"))
	assert_eq(feature.target_footprint_size, Vector2(5.4, 5.4))


func test_environment_feature_footprints_are_explicit() -> void:
	assert_eq(MapChunk.TREE_FOOTPRINT_SIZE, Vector2i(3, 3), "树木必须按 3×3 格布置")
	assert_eq(MapChunk.MOUNTAIN_MODEL_SPECS.size(), 3)
	var expected_footprints: Array[Vector2i] = [
		Vector2i(3, 3),
		Vector2i(5, 3),
		Vector2i(5, 5),
	]
	for index in range(MapChunk.MOUNTAIN_MODEL_SPECS.size()):
		var spec := MapChunk.MOUNTAIN_MODEL_SPECS[index]
		assert_eq(
			spec.get("footprint", Vector2i.ZERO),
			expected_footprints[index],
			"每种山体模型必须声明可完整替换的占位范围"
		)
		assert_true(
			ResourceLoader.exists(str(spec.get("path", "")), "PackedScene"),
			"山体规格引用的模型必须可用"
		)
