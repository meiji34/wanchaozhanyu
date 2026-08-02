class_name MapPassEntity
extends Node3D

var pass_id: String
var grid_position := Vector2i.ZERO


func _ready() -> void:
	_build_placeholder_visual()


func configure(pass_data: Dictionary, map_data: DemoMapData) -> void:
	pass_id = str(pass_data.get("pass_id", "pass"))
	grid_position = pass_data.get("grid_position", Vector2i.ZERO)
	name = "Pass_%s" % pass_id
	position = map_data.grid_to_world(grid_position, 0.1)


func _build_placeholder_visual() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("7e6a52")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for x_position in [-0.72, 0.72]:
		var pillar := MeshInstance3D.new()
		var pillar_mesh := BoxMesh.new()
		pillar_mesh.size = Vector3(0.42, 1.8, 0.55)
		pillar_mesh.material = material
		pillar.mesh = pillar_mesh
		pillar.position = Vector3(x_position, 0.9, 0.0)
		pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(pillar)

	var beam := MeshInstance3D.new()
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(1.95, 0.42, 0.62)
	beam_mesh.material = material
	beam.mesh = beam_mesh
	beam.position = Vector3(0.0, 1.75, 0.0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
