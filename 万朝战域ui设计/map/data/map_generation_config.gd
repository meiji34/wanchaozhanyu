class_name MapGenerationConfig
extends RefCounted

const DEFAULT_MAP_SIZE := Vector2i(200, 200)
const DEFAULT_CHUNK_SIZE := Vector2i(10, 10)
const DEFAULT_CELL_SIZE := 2.0
const DEFAULT_CITY_COUNT := 12
const DEFAULT_PASS_COUNT := 6
const DEFAULT_SEED := 20260728

var map_size := DEFAULT_MAP_SIZE
var chunk_size := DEFAULT_CHUNK_SIZE
var cell_size := DEFAULT_CELL_SIZE
var city_count := DEFAULT_CITY_COUNT
var pass_count := DEFAULT_PASS_COUNT
@warning_ignore("shadowed_global_identifier")
var seed := DEFAULT_SEED
