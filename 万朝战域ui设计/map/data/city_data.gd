class_name MapCityData
extends RefCounted

const DEFAULT_FOOTPRINT_SIZE := Vector2i(13, 13)

var city_id: String
var display_name: String
var grid_position: Vector2i
var level: int = 1
var faction_placeholder: String = "中立"
var footprint_size := DEFAULT_FOOTPRINT_SIZE


func _init(
	p_city_id: String = "",
	p_display_name: String = "",
	p_grid_position: Vector2i = Vector2i.ZERO,
	p_level: int = 1,
	p_footprint_size: Vector2i = DEFAULT_FOOTPRINT_SIZE
) -> void:
	city_id = p_city_id
	display_name = p_display_name
	grid_position = p_grid_position
	level = p_level
	footprint_size = Vector2i(
		maxi(1, p_footprint_size.x),
		maxi(1, p_footprint_size.y)
	)


func get_occupied_grid_rect() -> Rect2i:
	var half_size := Vector2i(
		floori(float(footprint_size.x) * 0.5),
		floori(float(footprint_size.y) * 0.5)
	)
	return Rect2i(grid_position - half_size, footprint_size)


func get_world_footprint_size(cell_size: float) -> Vector2:
	return Vector2(footprint_size) * cell_size
