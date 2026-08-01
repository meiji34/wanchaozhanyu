@tool
class_name MapFeatureModel
extends Node3D

var source_model_path := ""
var target_footprint_size := Vector2.ZERO


func configure(model_path: String, target_width: float) -> bool:
	return configure_to_footprint(
		model_path,
		Vector2(target_width, target_width)
	)


func configure_to_footprint(model_path: String, footprint_world_size: Vector2) -> bool:
	if not ResourceLoader.exists(model_path, "PackedScene"):
		push_warning("地图装饰模型不存在，保留程序化占位：%s" % model_path)
		return false
	var packed_scene := load(model_path) as PackedScene
	if packed_scene == null:
		push_warning("地图装饰模型加载失败，保留程序化占位：%s" % model_path)
		return false
	var instance := packed_scene.instantiate()
	if not instance is Node3D:
		instance.free()
		push_warning("地图装饰模型根节点不是 Node3D：%s" % model_path)
		return false

	var model_root := instance as Node3D
	var bounds := _calculate_model_bounds(model_root)
	var model_width := maxf(bounds.size.x, bounds.size.z)
	if model_width <= 0.0:
		model_root.free()
		push_warning("地图装饰模型边界无效：%s" % model_path)
		return false

	var safe_target_size := Vector2(
		maxf(0.01, footprint_world_size.x),
		maxf(0.01, footprint_world_size.y)
	)
	# 同时受 X/Z 两轴约束，保证任意比例的正式模型都不会越出声明占地。
	var uniform_scale := minf(
		safe_target_size.x / maxf(bounds.size.x, 0.001),
		safe_target_size.y / maxf(bounds.size.z, 0.001)
	)
	var center := bounds.get_center()
	model_root.name = "Model"
	model_root.scale = Vector3.ONE * uniform_scale
	model_root.position = Vector3(
		-center.x * uniform_scale,
		-bounds.position.y * uniform_scale,
		-center.z * uniform_scale
	)
	_disable_shadows(model_root)
	add_child(model_root)
	source_model_path = model_path
	target_footprint_size = safe_target_size
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


func _disable_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_disable_shadows(child)
