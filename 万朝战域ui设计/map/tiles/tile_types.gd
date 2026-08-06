class_name MapTileTypes
extends RefCounted

enum Terrain {
	PLAIN,
	MOUNTAIN,
	RIVER,
}

enum Zone {
	NEUTRAL,
	FOREST,
	MOUNTAIN,
	WETLAND,
	CENTRAL,
}

enum RoadType {
	NONE,
	MAIN,
	NORMAL,
	RING,
	HIDDEN,
}


static func get_display_name(terrain_type: int) -> String:
	match terrain_type:
		Terrain.MOUNTAIN:
			return "山地"
		Terrain.RIVER:
			return "河流"
		_:
			return "平原"


static func get_zone_display_name(zone_type: int) -> String:
	match zone_type:
		Zone.FOREST:
			return "森林区"
		Zone.MOUNTAIN:
			return "山地区"
		Zone.WETLAND:
			return "湿地区"
		Zone.CENTRAL:
			return "中央区"
		_:
			return "公共区"


static func get_road_display_name(road_type: int) -> String:
	match road_type:
		RoadType.MAIN:
			return "主干道"
		RoadType.NORMAL:
			return "普通道路"
		RoadType.RING:
			return "外围环路"
		RoadType.HIDDEN:
			return "隐藏小径"
		_:
			return "无"


static func get_road_priority(road_type: int) -> int:
	match road_type:
		RoadType.MAIN:
			return 4
		RoadType.RING:
			return 3
		RoadType.NORMAL:
			return 2
		RoadType.HIDDEN:
			return 1
		_:
			return 0
