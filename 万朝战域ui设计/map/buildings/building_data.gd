class_name MapBuildingData
extends RefCounted

## ——— 建筑实例数据 ———
## 记录一座已放置建筑的全部业务数据。
## 注意：本数据不保存任何场景节点引用，视觉节点由 MapBuildingManager 单独管理，
## 以便后续存档、删除建筑、联机同步和地图重载。

## 建筑唯一 ID（由 MapBuildingManager 分配）
var building_id: String = ""

## 建筑类型 ID（对应 MapBuildingDefinition.building_id）
var definition_id: StringName = &""

## 显示名称
var display_name: String = ""

## 占地基准格（逻辑锚点；奇数占地时即正中心格）
var origin_cell: Vector2i = Vector2i.ZERO

## 基础占地尺寸（格），与 MapBuildingDefinition 一致，不随旋转改写
var footprint_size: Vector2i = Vector2i(3, 3)

## 旋转方向索引（0=北 1=东 2=南 3=西），业务数据只保存离散方向，
## 实际占地由 footprint_size + rotation_index 动态推导
var rotation_index: int = 0

## 视觉高度级数
var height_levels: int = 3

## 地基高度（占地九格统一的 surface_height，放置时已校验一致）
var foundation_height: float = 0.0

## 归属阵营 ID（使用现有 DemoPlayerContext.FactionId，不新建阵营枚举）
var owner_faction_id: int = DemoPlayerContext.FactionId.NONE

## 占用的全部格子（二维格子坐标，是未来寻路避让的数据接口）
var occupied_cells: Array[Vector2i] = []


## 旋转后的实际占地尺寸（如 3×4 旋转 90° 后为 4×3）
func get_rotated_footprint_size() -> Vector2i:
	return MapBuildingDefinition.get_rotated_footprint_size(footprint_size, rotation_index)


## 占地视觉中心（连续格子坐标，与 MapBuildingDefinition 中心约定一致）。
## 使用旋转后尺寸，保证与 occupied_cells 覆盖同一区域。
func get_footprint_center() -> Vector2:
	return MapBuildingDefinition.compute_footprint_center(origin_cell, get_rotated_footprint_size())


## 中立快照，供 UI / 交互系统使用，不暴露内部引用
func get_snapshot() -> Dictionary:
	return {
		"kind": "building",
		"id": building_id,
		"name": display_name,
		"tile_id": origin_cell,
		"faction_id": owner_faction_id,
		"faction": DemoPlayerContext.get_faction_name_by_id(owner_faction_id),
		"footprint_size": get_rotated_footprint_size(),
		"rotation_index": rotation_index,
		"rotation_name": MapBuildingDefinition.get_rotation_display_name(rotation_index),
		"height_levels": height_levels,
		"foundation_height": foundation_height,
	}
