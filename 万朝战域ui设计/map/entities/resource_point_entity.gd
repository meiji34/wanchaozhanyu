class_name MapResourcePointEntity
extends Node3D

var resource_id := ""
var resource_type: int = MapResourcePointData.ResourceType.WOOD
var grid_position := Vector2i.ZERO
var display_name := "资源点"


func configure(resource_data: MapResourcePointData, map_data: DemoMapData) -> void:
	resource_id = resource_data.resource_id
	resource_type = resource_data.resource_type
	grid_position = resource_data.grid_position
	display_name = resource_data.display_name
	name = "Resource_%s" % resource_id
	position = map_data.get_surface_world_position(grid_position, 0.08)
	scale = Vector3.ONE * 2.1


func _ready() -> void:
	_build_placeholder_visual()


func _build_placeholder_visual() -> void:
	var color := MapResourcePointData.get_type_color(resource_type)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	match resource_type:
		MapResourcePointData.ResourceType.WOOD:
			_add_cylinder(material, Vector3.ZERO, 0.48, 0.34, 1.3)
			_add_cylinder(material, Vector3(-0.5, 0.0, 0.25), 0.34, 0.24, 0.95)
		MapResourcePointData.ResourceType.STONE:
			_add_box(material, Vector3.ZERO, Vector3(1.3, 0.9, 1.0))
			_add_box(material, Vector3(0.55, 0.0, -0.35), Vector3(0.7, 0.62, 0.65))
		MapResourcePointData.ResourceType.FOOD:
			_add_cylinder(material, Vector3.ZERO, 0.72, 0.72, 0.35)
			_add_cylinder(material, Vector3(0.0, 0.25, 0.0), 0.34, 0.55, 0.85)
		MapResourcePointData.ResourceType.IRON:
			_add_box(material, Vector3.ZERO, Vector3(1.45, 1.1, 1.25))
			_add_box(material, Vector3(0.0, 0.72, 0.0), Vector3(0.62, 0.8, 0.62))
			_add_label()


func _add_box(material: Material, offset: Vector3, size: Vector3) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	instance.position = offset + Vector3(0.0, size.y * 0.5, 0.0)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _add_cylinder(
	material: Material,
	offset: Vector3,
	top_radius: float,
	bottom_radius: float,
	height: float
) -> void:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 6
	mesh.material = material
	instance.mesh = mesh
	instance.position = offset + Vector3(0.0, height * 0.5, 0.0)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _add_label() -> void:
	var label := Label3D.new()
	label.text = display_name
	label.position = Vector3(0.0, 2.0, 0.0)
	label.font_size = 28
	label.modulate = Color("e2d1a8")
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
