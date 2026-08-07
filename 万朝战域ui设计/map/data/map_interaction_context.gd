class_name MapInteractionContext
extends RefCounted

## ——— 统一交互上下文 ———
## 将 city / resource / tile 三种快照统一为一种类型，
## 供行动解析器和 UI 使用，不修改原有 map_world 的数据结构。

## 目标类型
var target_type: int = MapActionConstants.TargetType.TILE

## 唯一目标 ID（城市 city_id / 资源 resource_id / 空时用 grid 字符串）
var target_id: StringName = &""

## 显示名称
var display_name: String = ""

## 格子坐标
var grid_position: Vector2i = Vector2i.ZERO

## 世界坐标
var world_position: Vector3 = Vector3.ZERO

## 区域类型
var zone_type: int = MapTileTypes.Zone.NEUTRAL

## 区域显示名
var zone_name: String = ""

## 阵营显示名（StringName，向后兼容）
var faction: StringName = &""
## 阵营 ID（整数，用于业务逻辑判断）
var faction_id: int = DemoPlayerContext.FactionId.NONE

## 城池角色（MapCityData.Role），用于区分阵营主城和中央主城
var city_role: int = MapCityData.Role.FACTION_CAPITAL

## 是否已发现（FogData: 非 UNKNOWN）
var is_discovered: bool = false

## 是否当前可见（FogData: VISIBLE）
var is_visible: bool = false

## 是否可选中
var is_selectable: bool = true

## 交互标签列表
var interaction_tags: Array[StringName] = []

## 原始快照（保留原有数据供桥接层使用）
var raw_snapshot: Dictionary = {}


## 从 MapWorld 的城市快照创建
static func from_city_snapshot(snapshot: Dictionary, map_data: DemoMapData = null) -> MapInteractionContext:
	var ctx := MapInteractionContext.new()
	ctx.target_type = MapActionConstants.TargetType.CITY
	ctx.target_id = str(snapshot.get("id", "city"))
	ctx.display_name = str(snapshot.get("name", "城池"))
	ctx.grid_position = snapshot.get("tile_id", Vector2i.ZERO) as Vector2i
	ctx.faction = str(snapshot.get("faction", "中立"))
	ctx.faction_id = int(snapshot.get("faction_id", DemoPlayerContext.FactionId.NONE))
	ctx.city_role = int(snapshot.get("city_role", MapCityData.Role.FACTION_CAPITAL))
	ctx.is_discovered = true
	ctx.is_visible = true
	ctx.is_selectable = true
	ctx.zone_name = MapTileTypes.get_zone_display_name(MapTileTypes.Zone.CENTRAL)
	ctx.raw_snapshot = snapshot
	if map_data != null:
		ctx.world_position = map_data.grid_to_world(ctx.grid_position)
		ctx.zone_type = map_data.get_zone_type_at(ctx.grid_position)
		ctx.zone_name = MapTileTypes.get_zone_display_name(ctx.zone_type)
	return ctx


## 从 MapWorld 的资源快照创建
static func from_resource_snapshot(snapshot: Dictionary, map_data: DemoMapData = null) -> MapInteractionContext:
	var ctx := MapInteractionContext.new()
	var resource_type_val: int = int(snapshot.get("resource_type", MapResourcePointData.ResourceType.WOOD))
	if resource_type_val == MapResourcePointData.ResourceType.IRON:
		ctx.target_type = MapActionConstants.TargetType.IRON_MINE
	else:
		ctx.target_type = MapActionConstants.TargetType.RESOURCE
	ctx.target_id = str(snapshot.get("id", "resource"))
	ctx.display_name = str(snapshot.get("name", "资源点"))
	ctx.grid_position = snapshot.get("tile_id", Vector2i.ZERO) as Vector2i
	ctx.faction = "中立"
	ctx.is_discovered = true
	ctx.is_visible = true
	ctx.is_selectable = true
	ctx.interaction_tags = [&"resource"]
	ctx.raw_snapshot = snapshot
	if map_data != null:
		ctx.world_position = map_data.grid_to_world(ctx.grid_position)
		ctx.zone_type = map_data.get_zone_type_at(ctx.grid_position)
		ctx.zone_name = MapTileTypes.get_zone_display_name(ctx.zone_type)
	return ctx


## 从 MapWorld 的建筑快照创建（第一版建造系统占位建筑）
static func from_building_snapshot(snapshot: Dictionary, map_data: DemoMapData = null) -> MapInteractionContext:
	var ctx := MapInteractionContext.new()
	ctx.target_type = MapActionConstants.TargetType.BUILDING
	ctx.target_id = str(snapshot.get("id", "building"))
	ctx.display_name = str(snapshot.get("name", "建筑"))
	ctx.grid_position = snapshot.get("tile_id", Vector2i.ZERO) as Vector2i
	ctx.faction = str(snapshot.get("faction", "中立"))
	ctx.faction_id = int(snapshot.get("faction_id", DemoPlayerContext.FactionId.NONE))
	ctx.is_discovered = true
	ctx.is_visible = true
	ctx.is_selectable = true
	ctx.interaction_tags = [&"building"]
	ctx.raw_snapshot = snapshot
	if map_data != null:
		ctx.world_position = map_data.grid_to_world(ctx.grid_position)
		ctx.zone_type = map_data.get_zone_type_at(ctx.grid_position)
		ctx.zone_name = MapTileTypes.get_zone_display_name(ctx.zone_type)
	return ctx


## 从 MapWorld 的 tile 快照创建
static func from_tile_snapshot(snapshot: Dictionary, map_data: DemoMapData = null) -> MapInteractionContext:
	var ctx := MapInteractionContext.new()
	ctx.grid_position = snapshot.get("tile_id", Vector2i.ZERO) as Vector2i
	ctx.target_id = "tile_%d_%d" % [ctx.grid_position.x, ctx.grid_position.y]
	ctx.display_name = "%s  (%d, %d)" % [
		MapTileTypes.get_display_name(int(snapshot.get("terrain", 0))),
		ctx.grid_position.x, ctx.grid_position.y,
	]
	ctx.is_discovered = true
	ctx.is_visible = true
	ctx.is_selectable = true
	ctx.faction_id = int(snapshot.get("faction_id", DemoPlayerContext.FactionId.NONE))
	ctx.raw_snapshot = snapshot

	# 根据 tile 数据推断更精确的目标类型
	var road_type_raw: int = int(snapshot.get("road_type", MapTileTypes.RoadType.NONE))
	var has_crossing: bool = snapshot.has("crossing_name")

	if has_crossing:
		var ct := str(snapshot.get("crossing_type", "bridge"))
		ctx.target_type = MapActionConstants.TargetType.BRIDGE if ct == "bridge" else MapActionConstants.TargetType.FORD
		ctx.display_name = str(snapshot.get("crossing_name", "过河点"))
		ctx.interaction_tags = [ctx.target_id, &"crossing", StringName(ct)]
	elif road_type_raw == MapTileTypes.RoadType.HIDDEN:
		ctx.target_type = MapActionConstants.TargetType.HIDDEN_PATH
		ctx.display_name = "隐藏小径  (%d, %d)" % [ctx.grid_position.x, ctx.grid_position.y]
		ctx.interaction_tags = [ctx.target_id, &"hidden_path"]
		ctx.is_discovered = false
		ctx.is_visible = false
	elif road_type_raw != MapTileTypes.RoadType.NONE:
		ctx.target_type = MapActionConstants.TargetType.ROAD
		ctx.display_name = "%s  (%d, %d)" % [
			MapTileTypes.get_road_display_name(road_type_raw),
			ctx.grid_position.x, ctx.grid_position.y,
		]
		ctx.interaction_tags = [ctx.target_id, &"road", StringName(str(road_type_raw))]
	else:
		# 根据地形推断（高地/山地）
		var terrain_type := int(snapshot.get("terrain", MapTileTypes.Terrain.PLAIN))
		if terrain_type == MapTileTypes.Terrain.MOUNTAIN:
			ctx.target_type = MapActionConstants.TargetType.HIGH_GROUND
			ctx.display_name = "高地  (%d, %d)" % [ctx.grid_position.x, ctx.grid_position.y]
			ctx.interaction_tags = [ctx.target_id, &"high_ground"]
		else:
			ctx.target_type = MapActionConstants.TargetType.TILE
			ctx.interaction_tags = [ctx.target_id, &"tile"]

	if map_data != null:
		ctx.world_position = map_data.grid_to_world(ctx.grid_position)
		ctx.zone_type = map_data.get_zone_type_at(ctx.grid_position)
		ctx.zone_name = MapTileTypes.get_zone_display_name(ctx.zone_type)
	return ctx
