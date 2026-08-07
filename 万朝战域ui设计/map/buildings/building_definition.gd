class_name MapBuildingDefinition
extends RefCounted

## ——— 建筑定义（静态参数） ———
## 描述一种建筑的占地、高度等静态配置，与具体实例无关。
## 第一版仅提供“测试建筑”；后续可扩展为 .tres 资源配置或表格驱动，
## 支持不同占地尺寸（1×1 / 2×2 / 4×2 …）、不同模型和不同地形要求。

## 建筑类型 ID（稳定标识，供数据记录与后续资源配置使用）
var building_id: StringName = &""

## 显示名称
var display_name: String = ""

## 占地尺寸（格），x=X 方向格数，y=Z 方向格数
var footprint_size: Vector2i = Vector2i(3, 3)

## 视觉高度级数，每级对应一个标准高度单位（MapGenerationConfig.HEIGHT_STEP）
var height_levels: int = 3


## 第一版演示建筑：3×3 占地、3 级高度的立方体占位建筑
static func create_test_building() -> MapBuildingDefinition:
	var definition := MapBuildingDefinition.new()
	definition.building_id = &"test_building"
	definition.display_name = "测试建筑"
	definition.footprint_size = Vector2i(3, 3)
	definition.height_levels = 3
	return definition


## 计算以 origin_cell 为基准的占地格子列表。
## 中心约定与 MapCityData.get_occupied_grid_rect() 一致：
## 奇数尺寸时 origin_cell 为正中心格，偶数尺寸时向下取整偏移。
func get_footprint_cells(origin_cell: Vector2i) -> Array[Vector2i]:
	return compute_footprint_cells(origin_cell, footprint_size)


## 占地视觉中心（连续格子坐标，允许半格）。
## 3×3 等奇数占地时正好等于 origin_cell，保证模型中心落在中间格中心。
func get_footprint_center(origin_cell: Vector2i) -> Vector2:
	return compute_footprint_center(origin_cell, footprint_size)


## 建筑世界尺寸：宽/深 = 占地格数 × cell_size，高 = 高度级数 × 标准高度单位。
## cell_size 必须来自项目当前地图数据，禁止写死。
func get_world_size(cell_size: float) -> Vector3:
	return Vector3(
		float(footprint_size.x) * cell_size,
		float(height_levels) * MapGenerationConfig.HEIGHT_STEP,
		float(footprint_size.y) * cell_size
	)


## 通用占地格子计算（静态版，供任意占地尺寸复用）
static func compute_footprint_cells(origin_cell: Vector2i, p_footprint_size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var half := Vector2i(
		floori(float(p_footprint_size.x) * 0.5),
		floori(float(p_footprint_size.y) * 0.5)
	)
	var start := origin_cell - half
	for y in range(start.y, start.y + p_footprint_size.y):
		for x in range(start.x, start.x + p_footprint_size.x):
			cells.append(Vector2i(x, y))
	return cells


## 通用占地视觉中心（静态版，连续格子坐标）。
## 格子中心即整数格坐标本身，因此中心 = 起始格 + (尺寸 - 1) / 2。
static func compute_footprint_center(origin_cell: Vector2i, p_footprint_size: Vector2i) -> Vector2:
	var half := Vector2i(
		floori(float(p_footprint_size.x) * 0.5),
		floori(float(p_footprint_size.y) * 0.5)
	)
	var start := Vector2(origin_cell - half)
	return start + (Vector2(p_footprint_size) - Vector2.ONE) * 0.5
