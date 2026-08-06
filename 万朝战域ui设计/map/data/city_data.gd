class_name MapCityData
extends RefCounted

const DEFAULT_FOOTPRINT_SIZE := Vector2i(13, 13)
const CENTRAL_FOOTPRINT_MULTIPLIER := 2  ## 中央主城占地倍率

enum Role {
	FACTION_CAPITAL,
	CENTRAL_CAPITAL,
}

var city_id: String
var display_name: String
var grid_position: Vector2i
var level: int = 1
## 阵营归属 ID（NONE=-1 表示中立），用于业务逻辑判断
var faction_id: int = DemoPlayerContext.FactionId.NONE
## 阵营占位文本（保留向后兼容，由 faction_id 自动推导）
var faction_placeholder: String = "中立"
var city_role: int = Role.FACTION_CAPITAL
var footprint_size := DEFAULT_FOOTPRINT_SIZE

## 从模型 AABB 计算的自然占地（不含缩放），仅在模型加载后填充
var natural_footprint_size := Vector2i.ZERO

## 模型加载后的实际世界包围盒（用于调试显示）
var model_world_aabb := AABB()


func _init(
	p_city_id: String = "",
	p_display_name: String = "",
	p_grid_position: Vector2i = Vector2i.ZERO,
	p_level: int = 1,
	p_footprint_size: Vector2i = DEFAULT_FOOTPRINT_SIZE,
	p_city_role: int = Role.FACTION_CAPITAL,
	p_faction_placeholder: String = "中立",
	p_faction_id: int = DemoPlayerContext.FactionId.NONE
) -> void:
	city_id = p_city_id
	display_name = p_display_name
	grid_position = p_grid_position
	level = p_level
	city_role = p_city_role
	faction_id = p_faction_id
	# 如果传入了 faction_id，自动推导 faction_placeholder
	if p_faction_id != DemoPlayerContext.FactionId.NONE:
		faction_placeholder = DemoPlayerContext.get_faction_name_by_id(p_faction_id)
	else:
		faction_placeholder = p_faction_placeholder
	# 中央主城应用 2 倍占地
	if p_city_role == Role.CENTRAL_CAPITAL:
		p_footprint_size = Vector2i(
			maxi(1, p_footprint_size.x * CENTRAL_FOOTPRINT_MULTIPLIER),
			maxi(1, p_footprint_size.y * CENTRAL_FOOTPRINT_MULTIPLIER)
		)
	footprint_size = Vector2i(
		maxi(1, p_footprint_size.x),
		maxi(1, p_footprint_size.y)
	)


## 获取阵营显示名称
func get_faction_display_name() -> String:
	return DemoPlayerContext.get_faction_name_by_id(faction_id)


func get_occupied_grid_rect() -> Rect2i:
	var half_size := Vector2i(
		floori(float(footprint_size.x) * 0.5),
		floori(float(footprint_size.y) * 0.5)
	)
	return Rect2i(grid_position - half_size, footprint_size)


func get_world_footprint_size(cell_size: float) -> Vector2:
	return Vector2(footprint_size) * cell_size


func get_occupied_cells() -> Array[Vector2i]:
	## 返回建筑占据的全部格子坐标列表
	var cells: Array[Vector2i] = []
	var rect := get_occupied_grid_rect()
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			cells.append(Vector2i(x, y))
	return cells
