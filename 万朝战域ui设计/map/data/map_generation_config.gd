class_name MapGenerationConfig
extends RefCounted

const DEFAULT_MAP_SIZE := Vector2i(400, 400)
const DEFAULT_CHUNK_SIZE := Vector2i(10, 10)
const DEFAULT_CELL_SIZE := 2.0
const CITY_CAPACITY := 12
const STRATEGIC_CITY_COUNT := 4
const MAIN_ROAD_COUNT := 3
const MAIN_ROAD_WIDTH := 2
const NORMAL_ROAD_WIDTH := 1
const RING_ROAD_WIDTH := 1
const HIDDEN_PATH_WIDTH := 1
const PASS_OPENING_WIDTH := 2
const RESOURCE_POINT_COUNT := 20
const IRON_POINT_COUNT := 5
const RESOURCE_SEARCH_RADIUS := 24
const RESOURCE_ROAD_CLEARANCE := 3
const CROSSING_COUNT_MIN := 2
const CROSSING_COUNT_MAX := 3
const DEFAULT_SEED := 20260728

const FOREST_CAPITAL := Vector2i(-116, -88)
const MOUNTAIN_CAPITAL := Vector2i(-116, 88)
const WETLAND_CAPITAL := Vector2i(144, 0)
const CENTRAL_CAPITAL := Vector2i.ZERO

const FOREST_ZONE_RECT := Rect2i(Vector2i(-190, -184), Vector2i(147, 161))
const MOUNTAIN_ZONE_RECT := Rect2i(Vector2i(-190, 24), Vector2i(155, 167))
const WETLAND_ZONE_RECT := Rect2i(Vector2i(40, -156), Vector2i(151, 313))
const CENTRAL_ZONE_RADIUS := 40
const ZONE_BOUNDARY_VARIATION := 10.0
const ZONE_BOUNDARY_CELL_SIZE := 24.0
const CENTRAL_BOUNDARY_VARIATION := 8.0

# 连续地形灰盒参数统一放在配置层，避免生成器、Chunk 和实体各自维护魔法数字。
const PLAIN_HEIGHT_AMPLITUDE := 0.45
const FOREST_HEIGHT_AMPLITUDE := 1.25
const MOUNTAIN_MIN_HEIGHT := 2.0
const MOUNTAIN_MAX_HEIGHT := 12.0
const RIVER_DEPTH_MIN := 0.9
const RIVER_DEPTH_MAX := 1.8
const RIVER_HALF_WIDTH := 3.0
const RIVER_BANK_WIDTH := 3.5
const TRIBUTARY_HALF_WIDTH := 1.4
const TRIBUTARY_BANK_WIDTH := 2.2
const CITY_TERRACE_BLEND_RADIUS := 6
const ROAD_HEIGHT_BLEND_MARGIN := 3.0
const MAX_ROAD_AVERAGE_SLOPE := 0.075
const MAX_BUILDABLE_SLOPE := 0.28

var map_size := DEFAULT_MAP_SIZE
var chunk_size := DEFAULT_CHUNK_SIZE
var cell_size := DEFAULT_CELL_SIZE
var city_capacity := CITY_CAPACITY
var strategic_city_count := STRATEGIC_CITY_COUNT
@warning_ignore("shadowed_global_identifier")
var seed := DEFAULT_SEED
