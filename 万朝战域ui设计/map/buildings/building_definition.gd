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

## ——— 旋转方向（第一版仅支持四个标准方向） ———
## rotation_index 语义：0=北(0°) 1=东(90°) 2=南(180°) 3=西(270°)。
## 全项目统一通过本类的静态函数做 index ↔ 角度/名称/占地尺寸 转换，
## 禁止在其他脚本中散落 0.0 / PI/2 等魔法数字。
const ROTATION_COUNT := 4
const ROTATION_NAMES: Array[String] = ["北", "东", "南", "西"]


## 第一版演示建筑：3×3 占地、3 级高度的立方体占位建筑
static func create_test_building() -> MapBuildingDefinition:
	var definition := MapBuildingDefinition.new()
	definition.building_id = &"test_building"
	definition.display_name = "测试建筑"
	definition.footprint_size = Vector2i(3, 3)
	definition.height_levels = 3
	return definition


## 第一版演示建筑 B：3×4 基础占地、3 级高度。
## footprint_size 始终保存基础尺寸；旋转后的 4×3 由 rotation_index 动态推导，不改写本定义。
static func create_test_building_b() -> MapBuildingDefinition:
	var definition := MapBuildingDefinition.new()
	definition.building_id = &"test_building_b"
	definition.display_name = "测试建筑 B"
	definition.footprint_size = Vector2i(3, 4)
	definition.height_levels = 3
	return definition


## 建筑选择栏目录（集中管理，后续可替换为 .tres 资源配置而无需改 UI 结构）
static func get_building_catalog() -> Array[MapBuildingDefinition]:
	return [create_test_building(), create_test_building_b()]


## 将任意整数规范化为合法 rotation_index（0~3）
static func normalize_rotation_index(rotation_index: int) -> int:
	return posmod(rotation_index, ROTATION_COUNT)


## 旋转后的占地尺寸：90°/270° 交换 X、Z 格数，0°/180° 保持基础尺寸
static func get_rotated_footprint_size(base_size: Vector2i, rotation_index: int) -> Vector2i:
	if normalize_rotation_index(rotation_index) % 2 == 1:
		return Vector2i(base_size.y, base_size.x)
	return base_size


## rotation_index → Y 轴旋转角（弧度），供 Preview 与正式建筑节点统一使用
static func rotation_index_to_y_rotation(rotation_index: int) -> float:
	return float(normalize_rotation_index(rotation_index)) * PI * 0.5


## rotation_index → 中文方向名（北/东/南/西），供 UI 显示
static func get_rotation_display_name(rotation_index: int) -> String:
	return ROTATION_NAMES[normalize_rotation_index(rotation_index)]


## 计算以 origin_cell 为基准的占地格子列表。
## 中心约定与 MapCityData.get_occupied_grid_rect() 一致：
## 奇数尺寸时 origin_cell 为正中心格，偶数尺寸时向下取整偏移。
## rotation_index 非 0 时按旋转后的占地尺寸计算（如 3×4 → 4×3）。
func get_footprint_cells(origin_cell: Vector2i, rotation_index: int = 0) -> Array[Vector2i]:
	return compute_footprint_cells(
		origin_cell, get_rotated_footprint_size(footprint_size, rotation_index)
	)


## 占地视觉中心（连续格子坐标，允许半格）。
## 3×3 等奇数占地时正好等于 origin_cell，保证模型中心落在中间格中心。
## 与 get_footprint_cells 使用同一旋转后尺寸，保证占地与视觉中心永远一致。
func get_footprint_center(origin_cell: Vector2i, rotation_index: int = 0) -> Vector2:
	return compute_footprint_center(
		origin_cell, get_rotated_footprint_size(footprint_size, rotation_index)
	)


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
