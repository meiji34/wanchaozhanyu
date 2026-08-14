@tool
extends McpTestSuite

## 土地平整无窗口测试：
## 覆盖高度等级换算、合法性校验（边界/河流/道路/城池/资源点/建筑占用）、
## 确认前预览不修改真实数据、平整执行（削低+抬高）、平整后原建造校验自然通过、
## 施工时间接口当前返回 0。

const INVALID_ORIGIN := Vector2i(999999, 999999)

var _map_data: DemoMapData


func suite_name() -> String:
	return "terrain_flatten"


## 地图数据生成成本较高，套件内共享
func _get_map_data() -> DemoMapData:
	if _map_data == null:
		_map_data = DemoMapGenerator.generate(MapGenerationConfig.new())
	return _map_data


func _make_controller(data: DemoMapData) -> MapController:
	var controller := MapController.new()
	controller.map_data = data
	return controller


func _make_manager(controller: MapController) -> MapBuildingManager:
	var manager := MapBuildingManager.new()
	manager.setup(controller)
	return manager


## 在指定搜索范围内寻找一块“高度不一致但其他条件可平整”的 3×3 区域
func _find_mixed_terrain_region(data: DemoMapData, size: Vector2i) -> Array[Vector2i]:
	for y in range(-80, 80):
		for x in range(-80, 80):
			var cells := MapBuildingDefinition.compute_footprint_cells(Vector2i(x, y), size)
			var usable := true
			var mixed := false
			var min_level := 0
			var max_level := 0
			for i in range(cells.size()):
				var cell := cells[i]
				if (
					not data.is_valid_grid(cell)
					or not data.is_buildable_at(cell)
					or data.get_terrain_type_at(cell) != MapTileTypes.Terrain.PLAIN
					or data.has_road_at(cell)
					or data.get_city_at_grid(cell) != null
					or data.get_resource_at_grid(cell) != null
				):
					usable = false
					break
				var level := data.get_height_level_at_grid(cell)
				if i == 0:
					min_level = level
					max_level = level
				else:
					min_level = mini(min_level, level)
					max_level = maxi(max_level, level)
					if level != min_level:
						mixed = true
			# 目标取区域最高等级时最大高度差 = 极差，要求 <= 平整允许差值
			if usable and mixed and max_level - min_level <= MapTerrainFlattenController.MAX_FLATTEN_HEIGHT_DELTA:
				return cells
	return []


func test_height_level_roundtrip() -> void:
	var data := _get_map_data()
	var cell := Vector2i(5, 5)
	data.set_height_level_at_grid(cell, 4)
	assert_eq(data.get_height_level_at_grid(cell), 4, "高度等级写入后必须可读回")
	assert_eq(
		data.get_surface_height_at_grid(cell), 4.0 * MapGenerationConfig.HEIGHT_STEP,
		"阶梯表面高度必须等于 等级 × HEIGHT_STEP"
	)
	data.set_height_level_at_grid(cell, 1)
	assert_eq(data.get_height_level_at_grid(cell), 1, "高度等级必须支持削低")


func test_validate_rejects_special_cells() -> void:
	var data := _get_map_data()
	var controller := _make_controller(data)
	var manager := _make_manager(controller)
	# 地图边界外
	var out_cells: Array[Vector2i] = [INVALID_ORIGIN]
	var result := MapTerrainFlattenController.validate_flatten_cells(
		data, manager, out_cells, 1, DemoPlayerContext.FactionId.FOREST, false
	)
	assert_false(bool(result.get("valid", true)), "地图边界外必须禁止平整")
	# 主城占用格
	var city_cells: Array[Vector2i] = [MapGenerationConfig.FOREST_CAPITAL]
	result = MapTerrainFlattenController.validate_flatten_cells(
		data, manager, city_cells, 1, DemoPlayerContext.FactionId.FOREST, false
	)
	assert_false(bool(result.get("valid", true)), "主城占用格必须禁止平整")
	# 河流格
	var river_cell := INVALID_ORIGIN
	for y in range(-150, 150):
		var found := false
		for x in range(-150, 150):
			var cell := Vector2i(x, y)
			if data.get_terrain_type_at(cell) == MapTileTypes.Terrain.RIVER:
				river_cell = cell
				found = true
				break
		if found:
			break
	assert_ne(river_cell, INVALID_ORIGIN, "演示地图必须包含河流")
	result = MapTerrainFlattenController.validate_flatten_cells(
		data, manager, [river_cell] as Array[Vector2i], 1,
		DemoPlayerContext.FactionId.FOREST, false
	)
	assert_false(bool(result.get("valid", true)), "河流格必须禁止平整")
	# 资源点格
	var iron_points := data.get_resources_by_type(MapResourcePointData.ResourceType.IRON)
	assert_true(iron_points.size() > 0, "演示地图必须包含铁矿")
	result = MapTerrainFlattenController.validate_flatten_cells(
		data, manager, [iron_points[0].grid_position] as Array[Vector2i], 1,
		DemoPlayerContext.FactionId.FOREST, false
	)
	assert_false(bool(result.get("valid", true)), "资源点格必须禁止平整")


func test_validate_rejects_building_occupied() -> void:
	var data := _get_map_data()
	var controller := _make_controller(data)
	var manager := _make_manager(controller)
	var definition := MapBuildingDefinition.create_test_building()
	var placed_origin := INVALID_ORIGIN
	for y in range(-60, 60):
		var found := false
		for x in range(-60, 60):
			var origin := Vector2i(x, y)
			var check := manager.validate_placement(
				definition, origin, DemoPlayerContext.FactionId.FOREST
			)
			if bool(check.get("valid", false)):
				placed_origin = origin
				found = true
				break
		if found:
			break
	assert_ne(placed_origin, INVALID_ORIGIN, "必须存在可建造位置")
	var place := manager.place_building(
		definition, placed_origin, DemoPlayerContext.FactionId.FOREST
	)
	assert_true(bool(place.get("success", false)), "前置建筑放置必须成功")
	var occupied: Array[Vector2i] = [placed_origin]
	var result := MapTerrainFlattenController.validate_flatten_cells(
		data, manager, occupied, 1, DemoPlayerContext.FactionId.FOREST, false
	)
	assert_false(bool(result.get("valid", true)), "已有建筑占用格必须禁止平整")
	assert_eq(
		str(result.get("reason", "")), "平整范围已被建筑占用", "占用原因必须明确"
	)


func test_flatten_unifies_height_and_enables_building() -> void:
	var data := _get_map_data()
	var controller := _make_controller(data)
	var manager := _make_manager(controller)
	var region := _find_mixed_terrain_region(data, Vector2i(3, 3))
	assert_false(region.is_empty(), "必须找到高度不一致的可平整区域")
	# 目标取区域最高等级：高度差规则下整个区域必然合法，同时覆盖削低+抬高
	var target_level := 0
	for cell in region:
		target_level = maxi(target_level, data.get_height_level_at_grid(cell))
	# 预览阶段的合法性校验不得修改真实数据
	var before_levels: Array[int] = []
	for cell in region:
		before_levels.append(data.get_height_level_at_grid(cell))
	var preview_check := MapTerrainFlattenController.validate_flatten_cells(
		data, manager, region, target_level, DemoPlayerContext.FactionId.FOREST, false
	)
	assert_true(bool(preview_check.get("valid", false)), "混合高度区域必须可以平整")
	for i in range(region.size()):
		assert_eq(
			data.get_height_level_at_grid(region[i]), before_levels[i],
			"校验/预览阶段不得修改真实地形数据"
		)
	# 执行平整（含削低与抬高的双向调整）
	var result := controller.flatten_terrain(region, target_level)
	assert_true(bool(result.get("success", false)), "平整执行必须成功")
	for cell in region:
		assert_eq(
			data.get_height_level_at_grid(cell), target_level,
			"平整后所有格子必须处于目标高度等级"
		)
	# 原有建造合法性判断必须基于新高度自然通过（无任何 force_buildable 旁路）
	var definition := MapBuildingDefinition.create_test_building()
	var build_check := manager.validate_placement(
		definition, region[4], DemoPlayerContext.FactionId.FOREST
	)
	assert_true(
		bool(build_check.get("valid", false)),
		"平整后的区域必须自然满足建造高度条件：%s" % str(build_check.get("reason", ""))
	)


func test_flatten_rejects_out_of_bounds() -> void:
	var data := _get_map_data()
	var controller := _make_controller(data)
	var cells: Array[Vector2i] = [INVALID_ORIGIN]
	var result := controller.flatten_terrain(cells, 2)
	assert_false(bool(result.get("success", true)), "数据层必须复核地图边界")


func test_request_flatten_immediate_and_duration_zero() -> void:
	var data := _get_map_data()
	var controller := _make_controller(data)
	var manager := _make_manager(controller)
	var flatten := MapTerrainFlattenController.new()
	flatten.setup(controller, manager)
	var region := _find_mixed_terrain_region(data, Vector2i(2, 2))
	assert_false(region.is_empty(), "必须找到高度不一致的可平整区域")
	var target_level := 0
	for cell in region:
		target_level = maxi(target_level, data.get_height_level_at_grid(cell))
	# 施工时间接口：当前测试阶段必须立即完成
	var duration := flatten.calculate_flatten_duration(region, target_level)
	assert_eq(duration, 0.0, "测试阶段平整时间必须为 0（立即完成）")
	var result := flatten.request_flatten_terrain(region, target_level)
	assert_true(bool(result.get("success", false)), "duration=0 时必须立即执行平整")
	for cell in region:
		assert_eq(
			data.get_height_level_at_grid(cell), target_level,
			"请求入口执行后格子必须处于目标高度等级"
		)
	flatten.free()


func test_preview_does_not_modify_data() -> void:
	var data := _get_map_data()
	var controller := _make_controller(data)
	var manager := _make_manager(controller)
	var flatten := MapTerrainFlattenController.new()
	flatten.setup(controller, manager)
	flatten.enter_flatten_mode(2)
	assert_true(flatten.is_flatten_mode, "进入平整模式必须成功")
	var sample_cell := Vector2i(3, 3)
	var before := data.get_height_level_at_grid(sample_cell)
	flatten.hover_at_grid(sample_cell)
	flatten.adjust_target_height(1)
	flatten.adjust_region_width(1)
	flatten.adjust_region_length(-1)
	assert_eq(
		data.get_height_level_at_grid(sample_cell), before,
		"预览/调参阶段不得修改真实地形数据"
	)
	flatten.exit_flatten_mode()
	assert_false(flatten.is_flatten_mode, "退出平整模式必须成功")
	assert_eq(
		data.get_height_level_at_grid(sample_cell), before,
		"取消后真实地形必须完全不变"
	)
	flatten.free()


func test_position_lock_flow() -> void:
	var data := _get_map_data()
	var controller := _make_controller(data)
	var manager := _make_manager(controller)
	var flatten := MapTerrainFlattenController.new()
	flatten.setup(controller, manager)
	flatten.enter_flatten_mode(2)
	# 未锁定时：悬停跟随，确认被拒绝
	flatten.hover_at_grid(Vector2i(3, 3))
	assert_false(flatten.is_position_locked(), "悬停不得自动锁定位置")
	var unlocked_confirm := flatten.confirm()
	assert_false(bool(unlocked_confirm.get("success", true)), "未锁定位置不得确认平整")
	assert_eq(
		str(unlocked_confirm.get("reason", "")), "请先点击地图锁定平整位置",
		"未锁定确认必须给出明确提示"
	)
	# 左键点击锁定：悬停不再移动锚点
	flatten.handle_map_click(Vector2i(5, 5))
	assert_true(flatten.is_position_locked(), "左键点击必须锁定位置")
	flatten.hover_at_grid(Vector2i(9, 9))
	assert_eq(
		flatten.get_last_state().get("anchor_cell"), Vector2i(5, 5),
		"锁定后悬停不得移动预览锚点"
	)
	# 锁定后调整范围/高度仍以锁定锚点重算，不恢复跟随
	flatten.adjust_region_width(1)
	flatten.adjust_target_height(1)
	assert_eq(
		flatten.get_last_state().get("anchor_cell"), Vector2i(5, 5),
		"锁定后调整参数不得改变锚点"
	)
	# 已锁定时再次点击可改锁到新格子
	flatten.handle_map_click(Vector2i(7, 7))
	assert_eq(
		flatten.get_last_state().get("anchor_cell"), Vector2i(7, 7),
		"锁定后再次点击应改锁到新格子"
	)
	# 重新选择：解除锁定，悬停恢复跟随
	flatten.unlock_position()
	assert_false(flatten.is_position_locked(), "重新选择必须解除锁定")
	flatten.hover_at_grid(Vector2i(11, 11))
	assert_eq(
		flatten.get_last_state().get("anchor_cell"), Vector2i(11, 11),
		"解除锁定后悬停必须恢复跟随"
	)
	flatten.free()


func test_height_delta_rule() -> void:
	var data := _get_map_data()
	var controller := _make_controller(data)
	var manager := _make_manager(controller)
	# 找两个相邻的普通陆地格（无道路/城池/资源点），排除其他拒绝原因干扰
	var cells: Array[Vector2i] = []
	for y in range(-100, 100):
		var found := false
		for x in range(-100, 100):
			var pair: Array[Vector2i] = [Vector2i(x, y), Vector2i(x + 1, y)]
			var clean := true
			for cell in pair:
				if (
					not data.is_valid_grid(cell)
					or not data.is_buildable_at(cell)
					or data.get_terrain_type_at(cell) != MapTileTypes.Terrain.PLAIN
					or data.has_road_at(cell)
					or data.get_city_at_grid(cell) != null
					or data.get_resource_at_grid(cell) != null
				):
					clean = false
					break
			if clean:
				cells = pair
				found = true
				break
		if found:
			break
	assert_false(cells.is_empty(), "必须找到两格普通陆地")
	var original_0 := data.get_height_level_at_grid(cells[0])
	var original_1 := data.get_height_level_at_grid(cells[1])
	# 构造差值 2（允许）与差值 3（禁止）逐格规则验证
	var target := 5
	data.set_height_level_at_grid(cells[0], target - 2)
	data.set_height_level_at_grid(cells[1], target)
	var ok := MapTerrainFlattenController.validate_flatten_cells(
		data, manager, cells, target, DemoPlayerContext.FactionId.FOREST, false
	)
	assert_true(bool(ok.get("valid", false)), "差值 <= 2 必须允许平整")
	data.set_height_level_at_grid(cells[0], target - 3)
	var denied := MapTerrainFlattenController.validate_flatten_cells(
		data, manager, cells, target, DemoPlayerContext.FactionId.FOREST, false
	)
	assert_false(bool(denied.get("valid", true)), "存在差值 3 的格子必须禁止平整")
	assert_eq(
		str(denied.get("reason", "")),
		"目标区域存在与目标高度等级相差超过 2 级的地块",
		"高度差超限必须给出明确原因"
	)
	var states := denied.get("cell_states", {}) as Dictionary
	assert_eq(
		int(states.get(cells[0], -1)), int(MapTerrainFlattenController.CellState.INVALID),
		"超限格子预览必须显示为非法（红色）"
	)
	assert_eq(
		int(states.get(cells[1], -1)), int(MapTerrainFlattenController.CellState.SAME),
		"合规格子预览不得被误判为非法"
	)
	data.set_height_level_at_grid(cells[0], original_0)
	data.set_height_level_at_grid(cells[1], original_1)


## 寻找 3×3 纯山地区域（高度不一致且极差 <= 平整允许差值，无道路/城池/资源点）。
## 不过滤 is_buildable_at——山地格子在修复前该标记恒为 false，正是被测对象。
## 额外精确模拟平整后的边缘坡度（中心差分合向量），保证平整后全部 9 格
## 满足既有 MAX_BUILDABLE_SLOPE 规则，避免紧邻悬崖的边缘格仍然不可建造。
func _find_mountain_region(data: DemoMapData, size: Vector2i) -> Array[Vector2i]:
	for y in range(-140, 140):
		for x in range(-140, 140):
			var origin := Vector2i(x, y)
			var cells := MapBuildingDefinition.compute_footprint_cells(origin, size)
			var usable := true
			var mixed := false
			var min_level := 0
			var max_level := 0
			for i in range(cells.size()):
				var cell := cells[i]
				if (
					not data.is_valid_grid(cell)
					or data.get_terrain_type_at(cell) != MapTileTypes.Terrain.MOUNTAIN
					or data.has_road_at(cell)
					or data.get_city_at_grid(cell) != null
					or data.get_resource_at_grid(cell) != null
				):
					usable = false
					break
				var level := data.get_height_level_at_grid(cell)
				if i == 0:
					min_level = level
					max_level = level
				else:
					min_level = mini(min_level, level)
					max_level = maxi(max_level, level)
					if level != min_level:
						mixed = true
			if not usable or not mixed:
				continue
			if max_level - min_level > MapTerrainFlattenController.MAX_FLATTEN_HEIGHT_DELTA:
				continue
			# 精确模拟平整后的边缘坡度：区域格取目标高度、外圈格取真实高度，
			# 按中心差分计算每格坡度，必须全部 <= MAX_BUILDABLE_SLOPE。
			# 坡度是两个分量的合向量，仅限制单轴差值不足以保证可建造。
			var cell_set := {}
			for cell in cells:
				cell_set[cell] = true
			var slopes_ok := true
			for cell in cells:
				var left := _sim_level(data, cell + Vector2i.LEFT, cell_set, max_level)
				var right := _sim_level(data, cell + Vector2i.RIGHT, cell_set, max_level)
				var back := _sim_level(data, cell + Vector2i.UP, cell_set, max_level)
				var front := _sim_level(data, cell + Vector2i.DOWN, cell_set, max_level)
				var slope := Vector2(right - left, front - back).length() * (
					MapGenerationConfig.HEIGHT_STEP / (data.cell_size * 2.0)
				)
				if slope > MapGenerationConfig.MAX_BUILDABLE_SLOPE:
					slopes_ok = false
					break
			if slopes_ok:
				return cells
	return []


## 模拟平整后的格子高度等级：区域内取目标等级，区域外取真实等级
func _sim_level(
	data: DemoMapData, cell: Vector2i, region_set: Dictionary, target_level: int
) -> float:
	if region_set.has(cell):
		return float(target_level)
	if not data.is_valid_grid(cell):
		return float(target_level)
	return float(data.get_height_level_at_grid(cell))


func test_flattened_mountain_becomes_buildable() -> void:
	var data := _get_map_data()
	var controller := _make_controller(data)
	var manager := _make_manager(controller)
	var definition := MapBuildingDefinition.create_test_building()
	var region := _find_mountain_region(data, Vector2i(3, 3))
	assert_false(region.is_empty(), "演示地图必须存在可合法平整的山地区域")
	if region.is_empty():
		return
	var center := region[4]
	# 测试 A：未经平整的山地（高度不一致）必须不可建造
	var before := manager.validate_placement(
		definition, center, DemoPlayerContext.FactionId.FOREST
	)
	assert_false(bool(before.get("valid", true)), "未经平整的山地必须不可建造")
	# 合法平整：目标取区域最高等级，保证每格高度差 <= 2
	var target_level := 0
	for cell in region:
		target_level = maxi(target_level, data.get_height_level_at_grid(cell))
	var flat := controller.flatten_terrain(region, target_level)
	assert_true(bool(flat.get("success", false)), "山地合法平整必须成功")
	# 平整只改高度：地形类型保留 MOUNTAIN（区域/生态属性不变）
	assert_eq(
		data.get_terrain_type_at(center), MapTileTypes.Terrain.MOUNTAIN,
		"平整不得把山地地形类型改成平原"
	)
	# 派生数据已同步：坡度重算为平地，可建造标记按真实状态重算
	assert_true(
		data.get_slope_at(center) <= MapGenerationConfig.MAX_BUILDABLE_SLOPE,
		"平整后坡度派生数据必须同步刷新"
	)
	assert_true(
		data.is_buildable_at(center),
		"平整后可建造标记必须按真实地形状态重算"
	)
	# 测试 B：原有建筑校验基于真实状态自然通过，且可真实放置
	var after := manager.validate_placement(
		definition, center, DemoPlayerContext.FactionId.FOREST
	)
	assert_true(
		bool(after.get("valid", false)),
		"平整后的山地必须自然满足建造条件：%s" % str(after.get("reason", ""))
	)
	var placed := manager.place_building(
		definition, center, DemoPlayerContext.FactionId.FOREST
	)
	assert_true(bool(placed.get("success", false)), "平整后的山地必须可以真实建造")


func test_unflattened_mountain_remains_unbuildable() -> void:
	var data := _get_map_data()
	var controller := _make_controller(data)
	var manager := _make_manager(controller)
	var definition := MapBuildingDefinition.create_test_building()
	# 测试 E：找到一块高度不一致的山地（未平整），确认仍然不可建造
	var found := false
	for y in range(-140, 140):
		if found:
			break
		for x in range(-140, 140):
			var origin := Vector2i(x, y)
			var cells := definition.get_footprint_cells(origin, 0)
			var all_mountain := true
			var mixed := false
			var first_level := 0
			for i in range(cells.size()):
				var cell := cells[i]
				if (
					not data.is_valid_grid(cell)
					or data.get_terrain_type_at(cell) != MapTileTypes.Terrain.MOUNTAIN
					or data.has_road_at(cell)
					or data.get_city_at_grid(cell) != null
					or data.get_resource_at_grid(cell) != null
				):
					all_mountain = false
					break
				var level := data.get_height_level_at_grid(cell)
				if i == 0:
					first_level = level
				elif level != first_level:
					mixed = true
			if not all_mountain or not mixed:
				continue
			var result := manager.validate_placement(
				definition, origin, DemoPlayerContext.FactionId.FOREST
			)
			assert_false(
				bool(result.get("valid", true)),
				"未经平整的山地（高度不一致）必须仍然不可建造"
			)
			found = true
			break
	assert_true(found, "演示地图必须存在未经平整的山地区域")


func test_building_rejects_road_cells() -> void:
	var data := _get_map_data()
	var controller := _make_controller(data)
	var manager := _make_manager(controller)
	var definition := MapBuildingDefinition.create_test_building()
	# 寻找一个道路格：前置校验（边界/地形/高度一致）可通过，失败原因必须是道路本身
	var road_origin := INVALID_ORIGIN
	for y in range(-140, 140):
		var found := false
		for x in range(-140, 140):
			var origin := Vector2i(x, y)
			var cells := definition.get_footprint_cells(origin, 0)
			var road_count := 0
			var preconditions_ok := true
			for cell in cells:
				if (
					not data.is_valid_grid(cell)
					or not data.is_buildable_at(cell)
					or data.get_city_at_grid(cell) != null
					or data.get_resource_at_grid(cell) != null
				):
					preconditions_ok = false
					break
				if data.has_road_at(cell):
					road_count += 1
			if not preconditions_ok or road_count == 0:
				continue
			var foundation := data.get_surface_height_at_grid(origin)
			var height_ok := true
			for cell in cells:
				if not is_equal_approx(data.get_surface_height_at_grid(cell), foundation):
					height_ok = false
					break
			if height_ok:
				road_origin = origin
				found = true
				break
		if found:
			break
	assert_ne(road_origin, INVALID_ORIGIN, "演示地图必须存在前置校验可通过的道路建造位置")
	var check := manager.validate_placement(
		definition, road_origin, DemoPlayerContext.FactionId.FOREST
	)
	assert_false(bool(check.get("valid", true)), "footprint 包含道路必须不可建造")
	assert_eq(
		str(check.get("reason", "")), "占地区域包含道路",
		"道路占用必须给出明确原因（完整 footprint 任一道路格即拒绝）"
	)
	# 最终放置同样被拒绝（预览与正式施工共用同一校验入口）
	var placed := manager.place_building(
		definition, road_origin, DemoPlayerContext.FactionId.FOREST
	)
	assert_false(bool(placed.get("success", true)), "道路上禁止最终放置建筑")
