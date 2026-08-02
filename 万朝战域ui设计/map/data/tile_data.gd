class_name MapTileData
extends RefCounted

var grid_position: Vector2i
var terrain_type: int = MapTileTypes.Terrain.PLAIN
var height: float = 0.0
var has_road: bool = false
var can_build_city: bool = true


func _init(
	p_grid_position: Vector2i = Vector2i.ZERO,
	p_terrain_type: int = MapTileTypes.Terrain.PLAIN,
	p_height: float = 0.0
) -> void:
	grid_position = p_grid_position
	terrain_type = p_terrain_type
	height = p_height
	can_build_city = terrain_type == MapTileTypes.Terrain.PLAIN
