@tool
extends McpTestSuite


func suite_name() -> String:
	return "environment_models"


func test_first_version_terrain_materials_are_available() -> void:
	var material_paths: Array[String] = [
		"res://map/materials/grass_ground_material.tres",
		"res://map/materials/forest_ground_material.tres",
		"res://map/materials/mountain_ground_material.tres",
		"res://map/materials/wetland_ground_material.tres",
		"res://map/materials/central_ground_material.tres",
		"res://map/materials/river_water_material.tres",
	]
	for material_path in material_paths:
		assert_true(
			ResourceLoader.exists(material_path, "Material"),
			"第一版地形纹理材质必须可用：%s" % material_path
		)


func test_region_materials_use_shared_ground_texture() -> void:
	var material := load("res://map/materials/forest_ground_material.tres") as ShaderMaterial
	assert_true(material != null, "森林区材质必须能加载为 ShaderMaterial")
	if material != null:
		assert_true(
			material.get_shader_parameter("ground_texture") is Texture2D,
			"区域材质必须绑定地表贴图"
		)


func test_ground_materials_encode_elevation_with_brightness() -> void:
	var material_paths: Array[String] = [
		"res://map/materials/grass_ground_material.tres",
		"res://map/materials/forest_ground_material.tres",
		"res://map/materials/mountain_ground_material.tres",
		"res://map/materials/wetland_ground_material.tres",
		"res://map/materials/central_ground_material.tres",
	]
	var mountain_contrast := 0.0
	var grass_contrast := 0.0
	for material_path in material_paths:
		var material := load(material_path) as ShaderMaterial
		assert_true(material != null, "高程着色材质必须可加载：%s" % material_path)
		if material == null:
			continue
		var elevation_min := float(material.get_shader_parameter("elevation_min"))
		var elevation_max := float(material.get_shader_parameter("elevation_max"))
		var elevation_contrast := float(material.get_shader_parameter("elevation_contrast"))
		assert_gt(elevation_max, elevation_min, "高程映射范围必须有效")
		assert_gt(elevation_contrast, 0.0, "地表贴图必须启用随高度变化的明暗对比")
		if material_path.contains("mountain"):
			mountain_contrast = elevation_contrast
		elif material_path.contains("grass_ground"):
			grass_contrast = elevation_contrast
	assert_gt(mountain_contrast, grass_contrast, "山地的高程明暗层次应比平原更强")


func test_bridge_placeholder_uses_generated_deck_texture() -> void:
	var texture_path := "res://map/assets/sprites/terrain/bridge_deck_albedo.png"
	var material_path := "res://map/materials/bridge_deck_material.tres"
	assert_true(ResourceLoader.exists(texture_path, "Texture2D"), "临时桥梁贴图必须已导入")
	assert_true(ResourceLoader.exists(material_path, "Material"), "桥面贴图材质必须可用")
	var texture := load(texture_path) as Texture2D
	var material := load(material_path) as ShaderMaterial
	assert_true(texture != null)
	assert_true(material != null)
	if texture != null:
		assert_eq(texture.get_size(), Vector2(1024.0, 1024.0), "桥梁贴图应规范化为移动端友好的尺寸")
	if material != null:
		assert_true(
			material.get_shader_parameter("bridge_texture") is Texture2D,
			"桥面材质必须绑定生成的木板贴图"
		)
