class_name MapCityEntity
extends Node3D

const NORMAL_COLOR := Color("9a7444")
const SELECTED_COLOR := Color("d5ac5f")
const CITY_MODEL_PATH := "res://map/assets/models/rts_city_hy3d31.glb"
const FOOTPRINT_FILL_RATIO := 0.9
const MIN_LABEL_HEIGHT := 3.05

var city_data: MapCityData
var _body_material: StandardMaterial3D
var _label: Label3D
var _uses_model := false
var _cell_size := 2.0
var _visual_height := MIN_LABEL_HEIGHT - 0.6


func _ready() -> void:
	_uses_model = _build_model_visual()
	if not _uses_model:
		_build_placeholder_visual()
	_build_label(_visual_height + 0.6)
	_update_label()


func configure(p_city_data: MapCityData, map_data: DemoMapData) -> void:
	city_data = p_city_data
	_cell_size = map_data.cell_size
	name = "City_%s" % city_data.city_id
	position = map_data.grid_to_world(city_data.grid_position, 0.08)
	if is_node_ready():
		_update_label()


func set_selected(is_selected: bool) -> void:
	if _body_material == null:
		return
	var color := SELECTED_COLOR if is_selected else NORMAL_COLOR
	_body_material.albedo_color = color
	_body_material.emission_enabled = is_selected
	_body_material.emission = color * 0.55


func _build_placeholder_visual() -> void:
	var footprint_world_size := city_data.get_world_footprint_size(_cell_size)
	var visual_size := footprint_world_size * FOOTPRINT_FILL_RATIO
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = NORMAL_COLOR
	_body_material.roughness = 0.9
	_body_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var base := MeshInstance3D.new()
	base.name = "Base"
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(visual_size.x, 0.55, visual_size.y)
	base_mesh.material = _body_material
	base.mesh = base_mesh
	base.position.y = 0.28
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(base)

	var keep := MeshInstance3D.new()
	keep.name = "Keep"
	var keep_mesh := BoxMesh.new()
	keep_mesh.size = Vector3(visual_size.x * 0.42, 2.4, visual_size.y * 0.42)
	keep_mesh.material = _body_material
	keep.mesh = keep_mesh
	keep.position.y = 1.48
	keep.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(keep)

	var roof := MeshInstance3D.new()
	roof.name = "Roof"
	var roof_mesh := CylinderMesh.new()
	roof_mesh.top_radius = visual_size.x * 0.04
	roof_mesh.bottom_radius = visual_size.x * 0.28
	roof_mesh.height = 1.2
	roof_mesh.radial_segments = 4
	roof_mesh.material = _body_material
	roof.mesh = roof_mesh
	roof.position.y = 3.25
	roof.rotation.y = PI * 0.25
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(roof)
	_visual_height = 3.85


func _build_model_visual() -> bool:
	if not ResourceLoader.exists(CITY_MODEL_PATH, "PackedScene"):
		push_warning("城池模型不存在，使用程序化占位模型：%s" % CITY_MODEL_PATH)
		return false
	var model_scene := load(CITY_MODEL_PATH) as PackedScene
	if model_scene == null:
		push_warning("城池模型加载失败，使用程序化占位模型：%s" % CITY_MODEL_PATH)
		return false
	var model_instance := model_scene.instantiate()
	if not model_instance is Node3D:
		model_instance.queue_free()
		push_warning("城池模型根节点不是 Node3D，使用程序化占位模型")
		return false
	var model_root := model_instance as Node3D
	model_root.name = "CityModel"
	var model_bounds := _calculate_model_bounds(model_root)
	if model_bounds.size.x <= 0.0 or model_bounds.size.z <= 0.0:
		model_root.queue_free()
		push_warning("城池模型边界无效，使用程序化占位模型")
		return false
	var footprint_world_size := city_data.get_world_footprint_size(_cell_size)
	var target_width := minf(footprint_world_size.x, footprint_world_size.y) * FOOTPRINT_FILL_RATIO
	var model_width := maxf(model_bounds.size.x, model_bounds.size.z)
	var uniform_scale := target_width / model_width
	model_root.scale = Vector3.ONE * uniform_scale
	model_root.position.y = -model_bounds.position.y * uniform_scale
	_visual_height = model_bounds.size.y * uniform_scale
	_disable_model_shadows(model_root)
	add_child(model_root)
	return true


func _calculate_model_bounds(root: Node3D) -> AABB:
	var bounds := AABB()
	var has_bounds := false
	var mesh_nodes := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		mesh_nodes.push_front(root)
	for node_variant in mesh_nodes:
		var mesh_instance := node_variant as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var local_transform := _get_transform_relative_to_root(mesh_instance, root)
		var mesh_bounds := local_transform * mesh_instance.mesh.get_aabb()
		if not has_bounds:
			bounds = mesh_bounds
			has_bounds = true
		else:
			bounds = bounds.merge(mesh_bounds)
	return bounds


func _get_transform_relative_to_root(node: Node3D, root: Node3D) -> Transform3D:
	var relative_transform := Transform3D.IDENTITY
	var current: Node3D = node
	while current != null and current != root:
		relative_transform = current.transform * relative_transform
		current = current.get_parent() as Node3D
	return relative_transform


func _disable_model_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_disable_model_shadows(child)


func _build_label(label_height: float) -> void:
	_label = Label3D.new()
	_label.name = "CityLabel"
	_label.position = Vector3(0.0, label_height, 0.0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 30
	_label.pixel_size = 0.012
	_label.outline_size = 7
	_label.modulate = Color("f0dfbd")
	_label.outline_modulate = Color(0.08, 0.07, 0.05, 0.9)
	_label.no_depth_test = true
	add_child(_label)


func _update_label() -> void:
	if _label == null or city_data == null:
		return
	_label.text = "%s  Lv.%d" % [city_data.display_name, city_data.level]
