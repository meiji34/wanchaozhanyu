class_name MapResourcePointData
extends RefCounted

enum ResourceType {
	WOOD,
	STONE,
	FOOD,
	IRON,
}

var resource_id: String
var display_name: String
var resource_type: int
var grid_position: Vector2i
var seed_grid_position: Vector2i
var zone_type: int
var is_neutral := true
var is_interactable := true


func _init(
	p_resource_id: String = "resource",
	p_display_name: String = "资源点",
	p_resource_type: int = ResourceType.WOOD,
	p_grid_position: Vector2i = Vector2i.ZERO,
	p_seed_grid_position: Vector2i = Vector2i.ZERO,
	p_zone_type: int = MapTileTypes.Zone.NEUTRAL
) -> void:
	resource_id = p_resource_id
	display_name = p_display_name
	resource_type = p_resource_type
	grid_position = p_grid_position
	seed_grid_position = p_seed_grid_position
	zone_type = p_zone_type


static func get_type_display_name(type: int) -> String:
	match type:
		ResourceType.STONE:
			return "石料"
		ResourceType.FOOD:
			return "粮食"
		ResourceType.IRON:
			return "铁矿"
		_:
			return "木材"


static func get_type_color(type: int) -> Color:
	match type:
		ResourceType.STONE:
			return Color("8b8b82")
		ResourceType.FOOD:
			return Color("c8a84e")
		ResourceType.IRON:
			return Color("55616a")
		_:
			return Color("426846")
