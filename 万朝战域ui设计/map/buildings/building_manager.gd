class_name MapBuildingManager
extends Node3D

## ——— 建筑管理器 ———
## 建造系统的唯一数据与放置校验入口：
## - 建筑注册表（building_id → MapBuildingData）
## - 格子占用索引（cell → building_id），供校验与未来寻路避让使用
## - 集中式放置合法性校验（validate_placement）
## - 正式占位建筑模型的生成与迷雾可见性
##
## 格子只记录 building_id，建筑数据由本管理器持有，视觉节点单独索引，
## 业务数据不保存节点引用。

## 建筑生命周期事件（供 UI 刷新、后续存档/寻路/资源系统使用）
signal building_created(building_id: String)
signal building_removed(building_id: String)

## 正式占位建筑颜色（低饱和木色，与现有古风低保真配色一致）
const BUILDING_COLOR := Color("8a6a45")

## 阵营底座标识厚度（世界单位）
const FACTION_PLATE_THICKNESS := 0.06

var _map_controller: MapController
## 建筑注册表 {building_id: MapBuildingData}
var _buildings: Dictionary = {}
## 格子占用索引 {Vector2i: building_id}，包含已建与施工预留（第一版无施工态）
var _occupied_cells: Dictionary = {}
## 视觉节点索引 {building_id: MeshInstance3D}，仅用于显示，不参与业务判断
var _building_nodes: Dictionary = {}
var _next_building_serial := 1


func setup(map_controller: MapController) -> void:
	_map_controller = map_controller
	# 迷雾数据变更时同步建筑可见性，与既有实体可见性规则保持一致
	if not _map_controller.fog_changed.is_connected(_update_buildings_visibility):
		_map_controller.fog_changed.connect(_update_buildings_visibility)


func get_map_data() -> DemoMapData:
	return _map_controller.map_data if _map_controller != null else null


## ——— 放置校验（集中入口） ———
## 返回 {valid, reason, occupied_cells, foundation_height}，
## UI 可直接展示 reason，occupied_cells 供后续锁定格子使用。
func validate_placement(
	definition: MapBuildingDefinition,
	origin_cell: Vector2i,
	faction_id: int
) -> Dictionary:
	var result := {
		"valid": false,
		"reason": "",
		"occupied_cells": [],
		"foundation_height": 0.0,
	}
	var map_data := get_map_data()
	if definition == null or map_data == null:
		result["reason"] = "建造系统尚未就绪"
		return result
	var cells := definition.get_footprint_cells(origin_cell)
	result["occupied_cells"] = cells
	# 地基高度默认取基准格表面高度，保证非法位置下预览也能贴合地形显示
	if map_data.is_valid_grid(origin_cell):
		result["foundation_height"] = map_data.get_surface_height_at_grid(origin_cell)

	# 1. 地图边界：占地全部格子必须真实存在
	for cell in cells:
		if not map_data.is_valid_grid(cell):
			result["reason"] = "占地区域超出地图边界"
			return result
	# 2. 地形类型：复用既有可建造标记（水面、山地等已标记为不可建造）
	for cell in cells:
		if not map_data.is_buildable_at(cell):
			result["reason"] = "占地区域包含不可建造地形"
			return result
	# 3. 阶梯高度：第一版要求占地全部格子处于同一 surface_height
	var foundation := map_data.get_surface_height_at_grid(origin_cell)
	for cell in cells:
		if not is_equal_approx(map_data.get_surface_height_at_grid(cell), foundation):
			result["reason"] = "占地区域高度不一致"
			return result
	result["foundation_height"] = foundation
	# 4. 已有城池（阵营主城与中央主城统一由 _cities_by_grid 索引）
	for cell in cells:
		if map_data.get_city_at_grid(cell) != null:
			result["reason"] = "占地区域与城池重叠"
			return result
	# 5. 资源点（铁矿等）
	for cell in cells:
		if map_data.get_resource_at_grid(cell) != null:
			result["reason"] = "占地区域与资源点重叠"
			return result
	# 6. 已被其他建筑占用或施工预留
	for cell in cells:
		if _occupied_cells.has(cell):
			result["reason"] = "占地区域已被其他建筑占用"
			return result
	# 7. 战争迷雾：只允许在当前阵营当前可见（VISIBLE）的格子建造，占地 9 格全部检查。
	# 视野数据真值来源统一为 FogData 公共查询接口：
	# 未探索（UNKNOWN）与已探索但当前不可见（EXPLORED）均禁止建造，分别给出原因。
	var fog := map_data.fog_data if _map_controller.fog_enabled else null
	if fog != null:
		for cell in cells:
			if fog.is_unknown(cell, faction_id):
				result["reason"] = "占地区域尚未探索"
				return result
			if not fog.is_visible(cell, faction_id):
				result["reason"] = "占地区域不在当前视野内"
				return result
	result["valid"] = true
	result["reason"] = "位置合法"
	return result


## ——— 放置建筑 ———
## 生成前会重新校验一次，防止预览合法后地图状态已变化。
## 返回 {success, reason, building_id, snapshot}
func place_building(
	definition: MapBuildingDefinition,
	origin_cell: Vector2i,
	faction_id: int
) -> Dictionary:
	var check := validate_placement(definition, origin_cell, faction_id)
	if not bool(check.get("valid", false)):
		return {"success": false, "reason": str(check.get("reason", "当前位置不可建造"))}

	var building := MapBuildingData.new()
	building.building_id = _allocate_building_id()
	building.definition_id = definition.building_id
	building.display_name = definition.display_name
	building.origin_cell = origin_cell
	building.footprint_size = definition.footprint_size
	building.height_levels = definition.height_levels
	building.foundation_height = float(check["foundation_height"])
	building.owner_faction_id = faction_id
	building.occupied_cells = check["occupied_cells"]

	_buildings[building.building_id] = building
	# 锁定占地格子
	for cell in building.occupied_cells:
		_occupied_cells[cell] = building.building_id
	_spawn_building_visual(building)
	print("[Build] 已放置建筑 id=%s cell=%s faction=%d cells=%d" % [
		building.building_id, building.origin_cell, faction_id, building.occupied_cells.size()
	])
	building_created.emit(building.building_id)
	return {
		"success": true,
		"reason": "",
		"building_id": building.building_id,
		"snapshot": building.get_snapshot(),
	}


## ——— 删除建筑（统一业务入口） ———
## 完整业务流程：存在性检查 → 阵营权限二次校验 → 精确释放占用格 →
## 移除注册数据 → 释放视觉节点 → 发出事件。
## 权限由本层强制验证，不依赖 UI 是否显示了“删除”按钮。
func request_delete_building(building_id: String, requester_faction_id: int) -> Dictionary:
	var building := _buildings.get(building_id) as MapBuildingData
	# 1. 建筑必须存在（覆盖重复删除、旧 building_id、过期 UI 调用）
	if building == null:
		return {
			"success": false,
			"reason": "建筑不存在",
			"message": "建筑不存在或已被删除",
		}
	# 2. 阵营权限：只有建筑归属阵营才能删除（owner_faction_id 为唯一判定依据）
	if (
		building.owner_faction_id == DemoPlayerContext.FactionId.NONE
		or building.owner_faction_id != requester_faction_id
	):
		return {
			"success": false,
			"reason": "无权删除",
			"message": "只能删除本方阵营的建筑",
		}
	# 3. 精确释放该建筑登记的占用格：
	# 以创建时保存的 occupied_cells 为准，并逐格确认占用归属，避免误清其他建筑
	for cell in building.occupied_cells:
		if _occupied_cells.get(cell, "") == building_id:
			_occupied_cells.erase(cell)
	# 4. 移除注册数据
	_buildings.erase(building_id)
	# 5. 释放视觉节点（先从索引摘除，其他系统不再能拿到该节点引用）
	var node := _building_nodes.get(building_id) as MeshInstance3D
	_building_nodes.erase(building_id)
	if node != null and is_instance_valid(node):
		node.queue_free()
	print("[Build] 已删除建筑 id=%s cell=%s faction=%d" % [
		building_id, building.origin_cell, building.owner_faction_id
	])
	# 6. 发出删除事件
	building_removed.emit(building_id)
	return {
		"success": true,
		"reason": "",
		"message": "已删除「%s」" % building.display_name,
	}


## ——— 查询 ———

func get_building_by_id(building_id: String) -> MapBuildingData:
	return _buildings.get(building_id) as MapBuildingData


func get_building_at_grid(grid_position: Vector2i) -> MapBuildingData:
	var building_id: Variant = _occupied_cells.get(grid_position, "")
	if building_id == "":
		return null
	return _buildings.get(building_id) as MapBuildingData


## 格子是否已被建筑占用（预留接口，供后续寻路/单位通行使用）
func is_cell_occupied_by_building(grid_position: Vector2i) -> bool:
	return _occupied_cells.has(grid_position)


func get_building_count() -> int:
	return _buildings.size()


## ——— 内部 ———

func _allocate_building_id() -> String:
	var building_id := "building_%d" % _next_building_serial
	_next_building_serial += 1
	return building_id


## 生成正式占位建筑：不透明立方体，底面贴合阶梯地形表面。
## BoxMesh 原点位于几何中心，因此中心 Y = 地基高度 + 建筑高度 / 2。
func _spawn_building_visual(building: MapBuildingData) -> void:
	var map_data := get_map_data()
	if map_data == null:
		return
	var world_size := Vector3(
		float(building.footprint_size.x) * map_data.cell_size,
		float(building.height_levels) * MapGenerationConfig.HEIGHT_STEP,
		float(building.footprint_size.y) * map_data.cell_size
	)
	var material := StandardMaterial3D.new()
	material.albedo_color = BUILDING_COLOR
	material.roughness = 0.85
	var mesh := BoxMesh.new()
	mesh.size = world_size
	mesh.material = material
	var node := MeshInstance3D.new()
	node.name = "Building_%s" % building.building_id
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = map_data.grid_to_world_continuous(
		building.get_footprint_center(),
		building.foundation_height + world_size.y * 0.5
	)
	# 轻量阵营识别：建筑底部薄底座使用既有阵营显示色（不大面积染色主体立方体）
	var faction_color := DemoPlayerContext.get_faction_display_color(building.owner_faction_id)
	if faction_color != Color.TRANSPARENT:
		var plate_material := StandardMaterial3D.new()
		plate_material.albedo_color = Color(faction_color.r, faction_color.g, faction_color.b, 0.85)
		plate_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var plate_mesh := BoxMesh.new()
		plate_mesh.size = Vector3(
			world_size.x + 0.2,
			FACTION_PLATE_THICKNESS,
			world_size.z + 0.2
		)
		plate_mesh.material = plate_material
		var plate := MeshInstance3D.new()
		plate.name = "FactionPlate"
		plate.mesh = plate_mesh
		plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# 底座贴合地基表面（相对建筑中心向下半个建筑高度）
		plate.position = Vector3(0.0, -world_size.y * 0.5 + FACTION_PLATE_THICKNESS * 0.5, 0.0)
		node.add_child(plate)
	add_child(node)
	_building_nodes[building.building_id] = node
	_update_building_visibility(building)


## 建筑可见性：与既有实体规则一致（非 UNKNOWN 即可见），不修改迷雾数据本身
func _update_buildings_visibility() -> void:
	for building_id in _buildings:
		_update_building_visibility(_buildings[building_id] as MapBuildingData)


func _update_building_visibility(building: MapBuildingData) -> void:
	var node := _building_nodes.get(building.building_id) as MeshInstance3D
	if building == null or node == null or not is_instance_valid(node):
		return
	var map_data := get_map_data()
	var fog := map_data.fog_data if map_data != null and _map_controller.fog_enabled else null
	if fog == null:
		node.visible = true
		return
	node.visible = not fog.is_unknown(building.origin_cell, _map_controller.current_fog_faction_id)
