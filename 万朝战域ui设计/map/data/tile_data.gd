class_name MapTileData
extends RefCounted

var grid_position: Vector2i
var terrain_type: int = MapTileTypes.Terrain.PLAIN
var zone_type: int = MapTileTypes.Zone.NEUTRAL
## 阵营归属 ID，NONE(-1) 表示中立。与 zone_type（地形区域）独立
var faction_id: int = DemoPlayerContext.FactionId.NONE
var height: float = 0.0
var slope: float = 0.0
var forest_density: float = 0.0
var river_mask: float = 0.0
var water_height: float = 0.0
var has_road: bool = false
var road_type: int = MapTileTypes.RoadType.NONE
var can_build_city: bool = true


func _init(
	p_grid_position: Vector2i = Vector2i.ZERO,
	p_terrain_type: int = MapTileTypes.Terrain.PLAIN,
	p_height: float = 0.0,
	p_zone_type: int = MapTileTypes.Zone.NEUTRAL
) -> void:
	grid_position = p_grid_position
	terrain_type = p_terrain_type
	height = p_height
	zone_type = p_zone_type
	can_build_city = terrain_type == MapTileTypes.Terrain.PLAIN


func set_road_type(value: int) -> void:
	road_type = value
	has_road = road_type != MapTileTypes.RoadType.NONE
