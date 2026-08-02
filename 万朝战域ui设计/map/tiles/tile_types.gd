class_name MapTileTypes
extends RefCounted

enum Terrain {
	PLAIN,
	MOUNTAIN,
	RIVER,
}


static func get_display_name(terrain_type: int) -> String:
	match terrain_type:
		Terrain.MOUNTAIN:
			return "山地"
		Terrain.RIVER:
			return "河流"
		_:
			return "平原"
