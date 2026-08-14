@tool
extends McpTestSuite

## 建造系统第一版无窗口测试：
## 覆盖占地计算、中心对齐、合法性校验（边界/地形/高度/城池/资源点/占用/迷雾）、
## 放置与重复放置拦截、阵营归属、占位模型尺寸与贴地。

const INVALID_ORIGIN := Vector2i(999999, 999999)

var _map_data: DemoMapData


func suite_name() -> String:
	return "construction"


## 地图数据生成成本较高，套件内共享；建筑占用数据保存在各自 Manager 中，互不影响
func _get_map_data() -> DemoMapData:
	if _map_data == null:
		_map_data = DemoMapGenerator.generate(MapGenerationConfig.new())
	return _map_data


func _make_manager() -> MapBuildingManager:
	var controller := MapController.new()
	controller.map_data = _get_map_data()
	var manager := MapBuildingManager.new()
	manager.setup(controller)
	return manager


func _find_flat_buildable_origin(manager: MapBuildingManager) -> Vector2i:
	var definition := MapBuildingDefinition.create_test_building()
	for y in range(-60, 60):
		for x in range(-60, 60):
			var origin := Vector2i(x, y)
			var result := manager.validate_placement(
				definition, origin, DemoPlayerContext.FactionId.FOREST
			)
			if bool(result.get("valid", false)):
				return origin
	return INVALID_ORIGIN


func test_footprint_cells_and_center_alignment() -> void:
	var definition := MapBuildingDefinition.create_test_building()
	var cells := definition.get_footprint_cells(Vector2i(10, 10))
	assert_eq(cells.size(), 9, "3×3 建筑必须占用 9 格")
	assert_true(cells.has(Vector2i(9, 9)))
	assert_true(cells.has(Vector2i(11, 11)))
	assert_true(cells.has(Vector2i(10, 10)))
	# 奇数占地：视觉中心必须正好等于基准格，不允许半格偏移
	assert_eq(definition.get_footprint_center(Vector2i(10, 10)), Vector2(10, 10))
	# 偶数占地：中心允许半格，规则需稳定
	var even_cells := MapBuildingDefinition.compute_footprint_cells(Vector2i.ZERO, Vector2i(4, 2))
	assert_eq(even_cells.size(), 8, "4×2 建筑必须占用 8 格")
	assert_eq(
		MapBuildingDefinition.compute_footprint_center(Vector2i.ZERO, Vector2i(4, 2)),
		Vector2(-0.5, -0.5)
	)


func test_world_size_uses_map_parameters() -> void:
	var definition := MapBuildingDefinition.create_test_building()
	var data := _get_map_data()
	# 宽深 = 占地 × cell_size，高 = 高度级数 × HEIGHT_STEP，禁止写死 Vector3(3,3,3)
	var expected := Vector3(
		3.0 * data.cell_size,
		3.0 * MapGenerationConfig.HEIGHT_STEP,
		3.0 * data.cell_size
	)
	assert_eq(definition.get_world_size(data.cell_size), expected)


func test_validate_rejects_out_of_bounds() -> void:
	var manager := _make_manager()
	var definition := MapBuildingDefinition.create_test_building()
	var data := _get_map_data()
	var corner := data.get_min_grid()
	var result := manager.validate_placement(
		definition, corner, DemoPlayerContext.FactionId.FOREST
	)
	assert_false(bool(result.get("valid", true)))
	assert_eq(str(result.get("reason", "")), "占地区域超出地图边界")


func test_validate_rejects_city_overlap() -> void:
	var manager := _make_manager()
	var definition := MapBuildingDefinition.create_test_building()
	for capital in [
		MapGenerationConfig.FOREST_CAPITAL,
		MapGenerationConfig.MOUNTAIN_CAPITAL,
		MapGenerationConfig.WETLAND_CAPITAL,
		MapGenerationConfig.CENTRAL_CAPITAL,
	]:
		var result := manager.validate_placement(
			definition, capital, DemoPlayerContext.FactionId.FOREST
		)
		assert_false(bool(result.get("valid", true)), "主城位置必须禁止建造：%s" % capital)
		assert_eq(str(result.get("reason", "")), "占地区域与城池重叠")


func test_validate_rejects_resource_overlap() -> void:
	var manager := _make_manager()
	var definition := MapBuildingDefinition.create_test_building()
	var data := _get_map_data()
	var iron_points := data.get_resources_by_type(MapResourcePointData.ResourceType.IRON)
	assert_true(iron_points.size() > 0, "演示地图必须包含铁矿")
	var checked := false
	for resource_point in iron_points:
		# 仅当地形与高度前置检查能通过时，才能精确命中资源点拦截
		var origin: Vector2i = resource_point.grid_position
		var cells := definition.get_footprint_cells(origin)
		var precheck_ok := true
		var foundation := data.get_surface_height_at_grid(origin)
		for cell in cells:
			if (
				not data.is_valid_grid(cell)
				or not data.is_buildable_at(cell)
				or not is_equal_approx(data.get_surface_height_at_grid(cell), foundation)
			):
				precheck_ok = false
				break
		var result := manager.validate_placement(definition, origin, DemoPlayerContext.FactionId.FOREST)
		assert_false(bool(result.get("valid", true)), "铁矿位置必须禁止建造：%s" % origin)
		if precheck_ok:
			assert_eq(str(result.get("reason", "")), "占地区域与资源点重叠")
			checked = true
	assert_true(checked, "至少一个铁矿应命中资源点拦截分支")


func test_validate_rejects_height_mismatch() -> void:
	var manager := _make_manager()
	var definition := MapBuildingDefinition.create_test_building()
	var data := _get_map_data()
	var found := INVALID_ORIGIN
	for y in range(-120, 120):
		for x in range(-120, 120):
			var origin := Vector2i(x, y)
			var cells := definition.get_footprint_cells(origin)
			var foundation := data.get_surface_height_at_grid(origin)
			var all_buildable := true
			var differ := false
			for cell in cells:
				if not data.is_valid_grid(cell) or not data.is_buildable_at(cell):
					all_buildable = false
					break
				if not is_equal_approx(data.get_surface_height_at_grid(cell), foundation):
					differ = true
			if all_buildable and differ:
				found = origin
				break
		if found != INVALID_ORIGIN:
			break
	assert_ne(found, INVALID_ORIGIN, "阶梯平原中应存在可建造但高度不一致的 3×3 区域")
	var result := manager.validate_placement(definition, found, DemoPlayerContext.FactionId.FOREST)
	assert_false(bool(result.get("valid", true)))
	assert_eq(str(result.get("reason", "")), "占地区域高度不一致")


func test_place_building_and_overlap_protection() -> void:
	var manager := _make_manager()
	var definition := MapBuildingDefinition.create_test_building()
	var origin := _find_flat_buildable_origin(manager)
	assert_ne(origin, INVALID_ORIGIN, "应能找到合法的 3×3 平整建造区域")
	var result := manager.place_building(
		definition, origin, DemoPlayerContext.FactionId.FOREST
	)
	assert_true(bool(result.get("success", false)), "合法位置必须建造成功")
	var building_id := str(result.get("building_id", ""))
	assert_true(building_id != "")
	# 9 格全部锁定且可反查
	var building := manager.get_building_by_id(building_id)
	assert_true(building != null)
	assert_eq(building.occupied_cells.size(), 9)
	for cell in building.occupied_cells:
		assert_true(manager.is_cell_occupied_by_building(cell))
		assert_eq(manager.get_building_at_grid(cell), building)
	# 重复放置：原点相同或部分重叠都必须拒绝
	var again := manager.place_building(definition, origin, DemoPlayerContext.FactionId.FOREST)
	assert_false(bool(again.get("success", true)), "同一位置禁止重复建造")
	assert_eq(str(again.get("reason", "")), "占地区域已被其他建筑占用")
	var shifted := manager.validate_placement(
		definition, origin + Vector2i(1, 0), DemoPlayerContext.FactionId.FOREST
	)
	assert_false(bool(shifted.get("valid", true)), "部分重叠也必须拒绝")
	assert_eq(str(shifted.get("reason", "")), "占地区域已被其他建筑占用")


func test_building_visual_matches_grid_and_foundation() -> void:
	var manager := _make_manager()
	var definition := MapBuildingDefinition.create_test_building()
	var data := _get_map_data()
	var origin := _find_flat_buildable_origin(manager)
	assert_ne(origin, INVALID_ORIGIN)
	var result := manager.place_building(
		definition, origin, DemoPlayerContext.FactionId.FOREST
	)
	assert_true(bool(result.get("success", false)))
	var building := manager.get_building_by_id(str(result.get("building_id", "")))
	assert_true(building != null)
	# 地基高度 = 占地统一 surface_height
	assert_eq(building.foundation_height, data.get_surface_height_at_grid(origin))
	# 视觉节点：尺寸来自地图参数，中心对齐中间格，底面贴合阶梯顶部
	var node := manager._building_nodes.get(building.building_id) as MeshInstance3D
	assert_true(node != null, "正式占位模型必须生成")
	if node != null:
		var mesh := node.mesh as BoxMesh
		assert_true(mesh != null)
		var world_size := definition.get_world_size(data.cell_size)
		assert_eq(mesh.size, world_size)
		var expected_center := data.grid_to_world(origin)
		assert_eq(node.position.x, expected_center.x)
		assert_eq(node.position.z, expected_center.z)
		assert_eq(node.position.y, building.foundation_height + world_size.y * 0.5)


func test_building_owner_faction() -> void:
	var manager := _make_manager()
	var definition := MapBuildingDefinition.create_test_building()
	var origin := _find_flat_buildable_origin(manager)
	assert_ne(origin, INVALID_ORIGIN)
	for faction_id in [
		DemoPlayerContext.FactionId.FOREST,
		DemoPlayerContext.FactionId.WETLAND,
		DemoPlayerContext.FactionId.MOUNTAIN,
	]:
		var fresh := _make_manager()
		var placed := fresh.place_building(definition, origin, faction_id)
		assert_true(bool(placed.get("success", false)))
		var snapshot: Dictionary = placed.get("snapshot", {})
		assert_eq(str(snapshot.get("kind", "")), "building")
		assert_eq(int(snapshot.get("faction_id", -99)), faction_id)
		assert_eq(
			str(snapshot.get("faction", "")),
			DemoPlayerContext.get_faction_name_by_id(faction_id)
		)


func test_fog_rules() -> void:
	var data := _get_map_data()
	var controller := MapController.new()
	controller.map_data = data
	var manager := MapBuildingManager.new()
	manager.setup(controller)
	var definition := MapBuildingDefinition.create_test_building()
	var origin := _find_flat_buildable_origin(manager)
	assert_ne(origin, INVALID_ORIGIN)
	# 附加迷雾数据：全部 UNKNOWN 时禁止建造
	data.fog_data = FogData.new(data.map_size)
	var faction := DemoPlayerContext.FactionId.FOREST
	var unknown_result := manager.validate_placement(definition, origin, faction)
	assert_false(bool(unknown_result.get("valid", true)), "未探索区域禁止建造")
	assert_eq(str(unknown_result.get("reason", "")), "占地区域尚未探索")
	# 严格 VISIBLE 规则：已探索但当前不可见（仅 EXPLORED）同样禁止建造
	data.fog_data.reveal_circle(origin, 5, faction)
	var explored_result := manager.validate_placement(definition, origin, faction)
	assert_false(bool(explored_result.get("valid", true)), "已探索但当前不可见区域禁止建造")
	assert_eq(str(explored_result.get("reason", "")), "占地区域不在当前视野内")
	# 当前可见（VISIBLE）才允许建造
	data.fog_data.update_visibility(origin, 5, faction)
	var visible_result := manager.validate_placement(definition, origin, faction)
	assert_true(bool(visible_result.get("valid", false)), "当前可见区域必须允许建造")
	var far_origin := origin + Vector2i(40, 40)
	if data.is_valid_grid(far_origin):
		data.fog_data.reveal_circle(far_origin, 5, faction)
		var explored_only := manager.validate_placement(definition, far_origin, faction)
		assert_false(bool(explored_only.get("valid", true)), "远离视野的已探索区域禁止建造")
		assert_eq(str(explored_only.get("reason", "")), "占地区域不在当前视野内")
	# 清理共享地图数据上的迷雾，避免影响其他测试
	data.fog_data = null


func test_footprint_requires_all_nine_cells_visible() -> void:
	var data := _get_map_data()
	var controller := MapController.new()
	controller.map_data = data
	var manager := MapBuildingManager.new()
	manager.setup(controller)
	var definition := MapBuildingDefinition.create_test_building()
	var origin := _find_flat_buildable_origin(manager)
	assert_ne(origin, INVALID_ORIGIN)
	data.fog_data = FogData.new(data.map_size)
	var faction := DemoPlayerContext.FactionId.FOREST
	# 先探索（EXPLORED）半径 8，再设当前可见（VISIBLE）半径 5：origin 自身 3×3 全部在可见圆内
	data.fog_data.reveal_circle(origin, 8, faction)
	data.fog_data.update_visibility(origin, 5, faction)
	var inside := manager.validate_placement(definition, origin, faction)
	assert_true(bool(inside.get("valid", false)), "9 格全部可见时必须允许建造")
	# 边缘格：中心格可见（距离 5），但 3×3 部分占用格超出可见圆（已探索但当前不可见）
	var edge_origin := origin + Vector2i(5, 0)
	assert_true(data.fog_data.is_visible(edge_origin, faction), "前提：中心格在可见圆内")
	var edge := manager.validate_placement(definition, edge_origin, faction)
	assert_false(bool(edge.get("valid", true)), "部分占用格不可见时必须禁止建造")
	assert_eq(str(edge.get("reason", "")), "占地区域不在当前视野内")
	data.fog_data = null


func test_delete_own_building_releases_everything() -> void:
	var manager := _make_manager()
	var definition := MapBuildingDefinition.create_test_building()
	var origin := _find_flat_buildable_origin(manager)
	assert_ne(origin, INVALID_ORIGIN)
	var placed := manager.place_building(definition, origin, DemoPlayerContext.FactionId.FOREST)
	assert_true(bool(placed.get("success", false)))
	var building_id := str(placed.get("building_id", ""))
	var occupied: Array = manager.get_building_by_id(building_id).occupied_cells.duplicate()
	var removed_event := {"id": ""}
	manager.building_removed.connect(func(bid: String) -> void: removed_event["id"] = bid)
	var deleted := manager.request_delete_building(building_id, DemoPlayerContext.FactionId.FOREST)
	assert_true(bool(deleted.get("success", false)), "己方建筑必须可以删除")
	assert_eq(str(removed_event["id"]), building_id, "必须发出 building_removed 事件")
	assert_eq(manager.get_building_count(), 0, "注册表必须移除建筑数据")
	assert_true(manager.get_building_by_id(building_id) == null)
	assert_false(manager._building_nodes.has(building_id), "视觉节点索引必须清理")
	for cell in occupied:
		assert_false(manager.is_cell_occupied_by_building(cell), "占用格必须释放：%s" % cell)
		assert_true(manager.get_building_at_grid(cell) == null)
	# 删除后原位置必须重新通过合法性校验（绿色 Preview）
	var revalidated := manager.validate_placement(definition, origin, DemoPlayerContext.FactionId.FOREST)
	assert_true(bool(revalidated.get("valid", false)), "删除后原位置必须可重新建造")


func test_delete_requires_owner_faction() -> void:
	var manager := _make_manager()
	var definition := MapBuildingDefinition.create_test_building()
	var origin := _find_flat_buildable_origin(manager)
	assert_ne(origin, INVALID_ORIGIN)
	var placed := manager.place_building(definition, origin, DemoPlayerContext.FactionId.FOREST)
	assert_true(bool(placed.get("success", false)))
	var building_id := str(placed.get("building_id", ""))
	# 业务层强制校验：即使绕过 UI 强制调用，非归属阵营也必须被拒绝
	var denied := manager.request_delete_building(building_id, DemoPlayerContext.FactionId.MOUNTAIN)
	assert_false(bool(denied.get("success", true)), "非归属阵营删除必须被拒绝")
	assert_eq(str(denied.get("reason", "")), "无权删除")
	assert_true(manager.get_building_by_id(building_id) != null, "越权删除不得影响建筑")
	assert_true(manager.is_cell_occupied_by_building(origin), "越权删除不得释放格子")
	# 归属阵营删除成功
	var allowed := manager.request_delete_building(building_id, DemoPlayerContext.FactionId.FOREST)
	assert_true(bool(allowed.get("success", false)))


func test_delete_nonexistent_and_repeat_is_safe() -> void:
	var manager := _make_manager()
	var ghost := manager.request_delete_building("building_999", DemoPlayerContext.FactionId.FOREST)
	assert_false(bool(ghost.get("success", true)))
	assert_eq(str(ghost.get("reason", "")), "建筑不存在")
	var definition := MapBuildingDefinition.create_test_building()
	var origin := _find_flat_buildable_origin(manager)
	var placed := manager.place_building(definition, origin, DemoPlayerContext.FactionId.FOREST)
	var building_id := str(placed.get("building_id", ""))
	assert_true(bool(manager.request_delete_building(building_id, DemoPlayerContext.FactionId.FOREST).get("success", false)))
	# 快速重复删除：第二次安全返回“建筑不存在”，不崩溃、不误清
	var again := manager.request_delete_building(building_id, DemoPlayerContext.FactionId.FOREST)
	assert_false(bool(again.get("success", true)))
	assert_eq(str(again.get("reason", "")), "建筑不存在")


func test_delete_does_not_affect_adjacent_building() -> void:
	var manager := _make_manager()
	var definition := MapBuildingDefinition.create_test_building()
	var data := _get_map_data()
	# 寻找一对相邻但不重叠的合法位置（x 方向间隔 3 格）
	var origin_a := INVALID_ORIGIN
	var origin_b := INVALID_ORIGIN
	for y in range(-60, 60):
		for x in range(-60, 60):
			var candidate := Vector2i(x, y)
			var neighbor := candidate + Vector2i(3, 0)
			if not data.is_valid_grid(neighbor):
				continue
			var ra := manager.validate_placement(definition, candidate, DemoPlayerContext.FactionId.FOREST)
			var rb := manager.validate_placement(definition, neighbor, DemoPlayerContext.FactionId.FOREST)
			if bool(ra.get("valid", false)) and bool(rb.get("valid", false)):
				origin_a = candidate
				origin_b = neighbor
				break
		if origin_a != INVALID_ORIGIN:
			break
	assert_ne(origin_a, INVALID_ORIGIN, "应能找到一对相邻合法建造位置")
	# 不同阵营分别建造，验证数据完全独立
	var pa := manager.place_building(definition, origin_a, DemoPlayerContext.FactionId.FOREST)
	var pb := manager.place_building(definition, origin_b, DemoPlayerContext.FactionId.MOUNTAIN)
	assert_true(bool(pa.get("success", false)))
	assert_true(bool(pb.get("success", false)))
	var id_a := str(pa.get("building_id", ""))
	var id_b := str(pb.get("building_id", ""))
	var building_b := manager.get_building_by_id(id_b)
	var b_cells: Array = building_b.occupied_cells.duplicate()
	# 删除 A，B 必须不受影响
	assert_true(bool(manager.request_delete_building(id_a, DemoPlayerContext.FactionId.FOREST).get("success", false)))
	assert_true(manager.get_building_by_id(id_b) != null, "相邻建筑节点数据必须保留")
	assert_eq(manager.get_building_by_id(id_b).occupied_cells, b_cells, "相邻建筑占地不得变化")
	assert_eq(manager.get_building_by_id(id_b).owner_faction_id, DemoPlayerContext.FactionId.MOUNTAIN)
	assert_true(manager._building_nodes.has(id_b), "相邻建筑视觉节点必须保留")
	for cell in b_cells:
		assert_eq(manager.get_building_at_grid(cell), building_b, "相邻建筑格子占用不得被误清")


func test_delete_does_not_touch_fog() -> void:
	var data := _get_map_data()
	var controller := MapController.new()
	controller.map_data = data
	var manager := MapBuildingManager.new()
	manager.setup(controller)
	var definition := MapBuildingDefinition.create_test_building()
	var origin := _find_flat_buildable_origin(manager)
	assert_ne(origin, INVALID_ORIGIN)
	data.fog_data = FogData.new(data.map_size)
	var faction := DemoPlayerContext.FactionId.WETLAND
	data.fog_data.reveal_circle(origin, 8, faction)
	data.fog_data.update_visibility(origin, 8, faction)
	var before_explored := data.fog_data.get_explored_count(faction)
	var before_visible := data.fog_data.get_visible_count(faction)
	var placed := manager.place_building(definition, origin, faction)
	var building_id := str(placed.get("building_id", ""))
	var deleted := manager.request_delete_building(building_id, faction)
	assert_true(bool(deleted.get("success", false)))
	# 删除不得揭示、清除或刷新任何阵营的视野数据
	assert_eq(data.fog_data.get_explored_count(faction), before_explored)
	assert_eq(data.fog_data.get_visible_count(faction), before_visible)
	assert_eq(data.fog_data.get_explored_count(DemoPlayerContext.FactionId.FOREST), 0)
	data.fog_data = null


func test_resolver_delete_action_follows_live_faction() -> void:
	var player := DemoPlayerContext.new()
	var resolver := MapActionResolver.new()
	resolver.set_player_context(player)
	var snapshot := {
		"kind": "building",
		"id": "building_x",
		"name": "测试建筑",
		"tile_id": Vector2i(5, 5),
		"faction_id": DemoPlayerContext.FactionId.FOREST,
		"faction": "森林",
		"footprint_size": Vector2i(3, 3),
		"height_levels": 3,
		"foundation_height": 0.0,
	}
	var context := MapInteractionContext.from_building_snapshot(snapshot)
	# 同阵营（森林）：查看 + 删除，删除需二次确认
	var actions := resolver.get_available_actions(context)
	assert_eq(actions.size(), 2, "己方建筑应显示查看+删除")
	var delete_action: MapInteractionAction = null
	for act in actions:
		if act.action_id == MapActionConstants.ACTION_DELETE_BUILDING:
			delete_action = act
	assert_true(delete_action != null, "己方建筑必须提供删除行动")
	assert_true(delete_action.requires_confirmation, "删除必须要求二次确认")
	# 切换山地/湿地：同一上下文实时重算，不得出现删除
	player.set_current_faction_by_id(DemoPlayerContext.FactionId.MOUNTAIN)
	actions = resolver.get_available_actions(context)
	assert_eq(actions.size(), 1, "非己方建筑只显示查看")
	assert_eq(actions[0].action_id, MapActionConstants.ACTION_VIEW)
	player.set_current_faction_by_id(DemoPlayerContext.FactionId.WETLAND)
	actions = resolver.get_available_actions(context)
	assert_eq(actions.size(), 1)
	# 切回森林：删除恢复
	player.set_current_faction_by_id(DemoPlayerContext.FactionId.FOREST)
	actions = resolver.get_available_actions(context)
	assert_eq(actions.size(), 2, "切回归属阵营后删除恢复")


func test_debug_reveal_grants_visible_and_buildable() -> void:
	var data := _get_map_data()
	var controller := MapController.new()
	controller.map_data = data
	controller.current_fog_faction_id = DemoPlayerContext.FactionId.FOREST
	var manager := MapBuildingManager.new()
	manager.setup(controller)
	var definition := MapBuildingDefinition.create_test_building()
	var origin := _find_flat_buildable_origin(manager)
	assert_ne(origin, INVALID_ORIGIN)
	data.fog_data = FogData.new(data.map_size)
	# 揭示前：未探索，禁止建造
	var before := manager.validate_placement(definition, origin, DemoPlayerContext.FactionId.FOREST)
	assert_false(bool(before.get("valid", true)))
	assert_eq(str(before.get("reason", "")), "占地区域尚未探索")
	# 走真实“揭示格子”路径（默认参数 = 当前迷雾阵营）
	controller.reveal_area(origin, 5)
	# 揭示语义 = 当前可见：VISIBLE 与 EXPLORED 必须同时成立
	assert_true(
		data.fog_data.is_visible(origin, DemoPlayerContext.FactionId.FOREST),
		"揭示后必须写入 VISIBLE"
	)
	assert_true(
		data.fog_data.is_revealed(origin, DemoPlayerContext.FactionId.FOREST),
		"揭示后必须写入 EXPLORED"
	)
	assert_true(
		data.fog_data.is_unknown(origin, DemoPlayerContext.FactionId.MOUNTAIN),
		"揭示不得污染山地阵营视野"
	)
	assert_true(
		data.fog_data.is_unknown(origin, DemoPlayerContext.FactionId.WETLAND),
		"揭示不得污染湿地阵营视野"
	)
	# 揭示区域允许建造（与开局视野、侦察视野行为一致）
	var after := manager.validate_placement(definition, origin, DemoPlayerContext.FactionId.FOREST)
	assert_true(bool(after.get("valid", false)), "揭示区域必须允许建造")
	data.fog_data = null


func test_building_does_not_pollute_fog_data() -> void:
	var data := _get_map_data()
	var controller := MapController.new()
	controller.map_data = data
	var manager := MapBuildingManager.new()
	manager.setup(controller)
	var definition := MapBuildingDefinition.create_test_building()
	var origin := _find_flat_buildable_origin(manager)
	assert_ne(origin, INVALID_ORIGIN)
	data.fog_data = FogData.new(data.map_size)
	var faction := DemoPlayerContext.FactionId.MOUNTAIN
	data.fog_data.reveal_circle(origin, 8, faction)
	data.fog_data.update_visibility(origin, 8, faction)
	var before := data.fog_data.get_explored_count(faction)
	var placed := manager.place_building(definition, origin, faction)
	assert_true(bool(placed.get("success", false)))
	# 建造不得揭示额外格子、不得污染探索数据
	assert_eq(data.fog_data.get_explored_count(faction), before)
	assert_eq(
		data.fog_data.get_explored_count(DemoPlayerContext.FactionId.FOREST),
		0,
		"山地阵营建造不得影响森林阵营探索数据"
	)
	data.fog_data = null


## ——— 建筑方向选择（第一版）———


func test_building_catalog_contains_both_test_buildings() -> void:
	var catalog := MapBuildingDefinition.get_building_catalog()
	assert_eq(catalog.size(), 2, "建筑目录必须包含 2 种测试建筑")
	assert_eq(catalog[0].footprint_size, Vector2i(3, 3), "建筑 A 基础占地 3×3")
	assert_eq(catalog[1].footprint_size, Vector2i(3, 4), "建筑 B 基础占地 3×4")
	assert_eq(catalog[1].height_levels, 3, "建筑 B 高度 3 级")
	assert_ne(catalog[0].building_id, catalog[1].building_id, "两种建筑 ID 必须不同")


func test_rotated_footprint_size() -> void:
	# 3×4：90°/270° 交换 X、Z，0°/180° 保持基础尺寸
	assert_eq(MapBuildingDefinition.get_rotated_footprint_size(Vector2i(3, 4), 0), Vector2i(3, 4))
	assert_eq(MapBuildingDefinition.get_rotated_footprint_size(Vector2i(3, 4), 1), Vector2i(4, 3))
	assert_eq(MapBuildingDefinition.get_rotated_footprint_size(Vector2i(3, 4), 2), Vector2i(3, 4))
	assert_eq(MapBuildingDefinition.get_rotated_footprint_size(Vector2i(3, 4), 3), Vector2i(4, 3))
	# 3×3：四个方向占地不变
	for i in range(4):
		assert_eq(
			MapBuildingDefinition.get_rotated_footprint_size(Vector2i(3, 3), i),
			Vector2i(3, 3),
			"3×3 旋转后占地必须仍为 3×3"
		)
	# 索引规范化：负数与越界索引安全循环
	assert_eq(MapBuildingDefinition.normalize_rotation_index(4), 0)
	assert_eq(MapBuildingDefinition.normalize_rotation_index(-1), 3)
	# index → 角度统一换算（禁止散落魔法数字）
	assert_true(is_equal_approx(MapBuildingDefinition.rotation_index_to_y_rotation(1), PI * 0.5))
	assert_true(is_equal_approx(MapBuildingDefinition.rotation_index_to_y_rotation(3), PI * 1.5))
	assert_eq(MapBuildingDefinition.get_rotation_display_name(0), "北")
	assert_eq(MapBuildingDefinition.get_rotation_display_name(3), "西")


func test_rotated_footprint_cells_and_anchor() -> void:
	var definition := MapBuildingDefinition.create_test_building_b()
	var origin := Vector2i(10, 10)
	var cells_0 := definition.get_footprint_cells(origin, 0)
	var cells_1 := definition.get_footprint_cells(origin, 1)
	var cells_2 := definition.get_footprint_cells(origin, 2)
	var cells_3 := definition.get_footprint_cells(origin, 3)
	# 四个方向占地均为 12 格，且锚点格始终包含在占地内
	for cells in [cells_0, cells_1, cells_2, cells_3]:
		assert_eq(cells.size(), 12, "3×4 建筑任意方向必须占 12 格")
		assert_true(cells.has(origin), "锚点格必须始终包含在占地内")
	# 0° 与 180° 占地一致，90° 与 270° 占地一致，两组之间不同
	assert_eq(cells_0, cells_2)
	assert_eq(cells_1, cells_3)
	assert_ne(cells_0, cells_1, "3×4 旋转 90° 后占地格子必须变化")
	# 占地中心与旋转后尺寸一致（统一锚点函数，无手动半格偏移）
	assert_eq(
		definition.get_footprint_center(origin, 1),
		MapBuildingDefinition.compute_footprint_center(origin, Vector2i(4, 3))
	)
	assert_eq(
		definition.get_footprint_center(origin, 0),
		MapBuildingDefinition.compute_footprint_center(origin, Vector2i(3, 4))
	)


func _find_flat_buildable_origin_for(
	manager: MapBuildingManager,
	definition: MapBuildingDefinition,
	rotation_index: int
) -> Vector2i:
	for y in range(-60, 60):
		for x in range(-60, 60):
			var origin := Vector2i(x, y)
			var result := manager.validate_placement(
				definition, origin, DemoPlayerContext.FactionId.FOREST, rotation_index
			)
			if bool(result.get("valid", false)):
				return origin
	return INVALID_ORIGIN


func test_place_rotated_building_saves_direction() -> void:
	var manager := _make_manager()
	var definition := MapBuildingDefinition.create_test_building_b()
	var data := _get_map_data()
	var origin := _find_flat_buildable_origin_for(manager, definition, 1)
	assert_ne(origin, INVALID_ORIGIN, "应能找到合法的 4×3 平整建造区域")
	var result := manager.place_building(definition, origin, DemoPlayerContext.FactionId.FOREST, 1)
	assert_true(bool(result.get("success", false)), "90° 合法位置必须建造成功")
	var building := manager.get_building_by_id(str(result.get("building_id", "")))
	assert_true(building != null)
	# 业务数据：基础尺寸不改写，方向保存为离散索引
	assert_eq(building.rotation_index, 1, "建筑必须保存 rotation_index")
	assert_eq(building.footprint_size, Vector2i(3, 4), "BuildingData 保存基础占地尺寸")
	assert_eq(building.get_rotated_footprint_size(), Vector2i(4, 3), "旋转后占地为 4×3")
	assert_eq(building.occupied_cells.size(), 12, "旋转后必须占用 12 格")
	assert_eq(building.owner_faction_id, DemoPlayerContext.FactionId.FOREST, "旋转不影响阵营归属")
	var snapshot: Dictionary = result.get("snapshot", {})
	assert_eq(int(snapshot.get("rotation_index", -1)), 1, "快照必须携带方向")
	assert_eq(snapshot.get("footprint_size", Vector2i.ZERO), Vector2i(4, 3), "快照占地为旋转后尺寸")
	# 视觉节点：网格按基础尺寸构建，节点按方向旋转，中心对齐旋转后占地中心
	var node := manager._building_nodes.get(building.building_id) as MeshInstance3D
	assert_true(node != null)
	if node != null:
		var mesh := node.mesh as BoxMesh
		assert_eq(mesh.size, definition.get_world_size(data.cell_size), "网格保持基础 3×4 尺寸")
		assert_true(is_equal_approx(node.rotation.y, PI * 0.5), "节点必须按 rotation_index 旋转")
		var expected_center := MapBuildingDefinition.compute_footprint_center(origin, Vector2i(4, 3))
		var expected_world := data.grid_to_world_continuous(
			expected_center, building.foundation_height + mesh.size.y * 0.5
		)
		assert_true(is_equal_approx(node.position.x, expected_world.x), "建筑中心 X 对齐 4×3 占地中心")
		assert_true(is_equal_approx(node.position.z, expected_world.z), "建筑中心 Z 对齐 4×3 占地中心")


func test_delete_rotated_building_releases_all_cells() -> void:
	var manager := _make_manager()
	var definition := MapBuildingDefinition.create_test_building_b()
	var origin := _find_flat_buildable_origin_for(manager, definition, 1)
	assert_ne(origin, INVALID_ORIGIN)
	var placed := manager.place_building(definition, origin, DemoPlayerContext.FactionId.FOREST, 1)
	assert_true(bool(placed.get("success", false)))
	var building_id := str(placed.get("building_id", ""))
	var occupied: Array = manager.get_building_by_id(building_id).occupied_cells.duplicate()
	assert_eq(occupied.size(), 12)
	var deleted := manager.request_delete_building(building_id, DemoPlayerContext.FactionId.FOREST)
	assert_true(bool(deleted.get("success", false)))
	# 删除以保存的 occupied_cells 为准（不重新推导），12 格全部精确释放
	for cell in occupied:
		assert_false(manager.is_cell_occupied_by_building(cell), "旋转建筑删除必须释放格子：%s" % cell)
	var revalidated := manager.validate_placement(
		definition, origin, DemoPlayerContext.FactionId.FOREST, 1
	)
	assert_true(bool(revalidated.get("valid", false)), "删除后原位置原方向必须可重新建造")


func test_rotation_changes_validation_result() -> void:
	var manager := _make_manager()
	var definition_a := MapBuildingDefinition.create_test_building()
	var definition_b := MapBuildingDefinition.create_test_building_b()
	# 构造场景：A 位于 B 西侧 3 格。B 取 3×4（0°）时不重叠，旋转 90°（4×3）后与 A 重叠。
	var origin_b := INVALID_ORIGIN
	var origin_a := INVALID_ORIGIN
	for y in range(-60, 60):
		for x in range(-60, 60):
			var candidate := Vector2i(x, y)
			var neighbor := candidate + Vector2i(-3, 0)
			var rb0 := manager.validate_placement(
				definition_b, candidate, DemoPlayerContext.FactionId.FOREST, 0
			)
			var ra := manager.validate_placement(
				definition_a, neighbor, DemoPlayerContext.FactionId.FOREST
			)
			if bool(rb0.get("valid", false)) and bool(ra.get("valid", false)):
				origin_b = candidate
				origin_a = neighbor
				break
		if origin_b != INVALID_ORIGIN:
			break
	assert_ne(origin_b, INVALID_ORIGIN, "应能找到 B 0° 与 A 同时合法的位置")
	assert_true(
		bool(manager.place_building(definition_a, origin_a, DemoPlayerContext.FactionId.FOREST)
			.get("success", false))
	)
	var still_valid := manager.validate_placement(
		definition_b, origin_b, DemoPlayerContext.FactionId.FOREST, 0
	)
	assert_true(bool(still_valid.get("valid", false)), "0° 方向与既有建筑不重叠")
	var rotated := manager.validate_placement(
		definition_b, origin_b, DemoPlayerContext.FactionId.FOREST, 1
	)
	assert_false(bool(rotated.get("valid", true)), "旋转 90° 后与既有建筑重叠必须非法")
	assert_eq(str(rotated.get("reason", "")), "占地区域已被其他建筑占用")


func test_rotation_out_of_bounds_at_map_edge() -> void:
	var manager := _make_manager()
	var definition := MapBuildingDefinition.create_test_building_b()
	var data := _get_map_data()
	# 贴近地图角落：3×4（0°）占地在界内，旋转 90°（4×3）后西侧越界
	var origin := data.get_min_grid() + Vector2i(1, 2)
	var result_0 := manager.validate_placement(
		definition, origin, DemoPlayerContext.FactionId.FOREST, 0
	)
	assert_ne(
		str(result_0.get("reason", "")), "占地区域超出地图边界", "0° 方向占地不得越界"
	)
	var result_1 := manager.validate_placement(
		definition, origin, DemoPlayerContext.FactionId.FOREST, 1
	)
	assert_false(bool(result_1.get("valid", true)), "边缘旋转后越界必须非法")
	assert_eq(str(result_1.get("reason", "")), "占地区域超出地图边界")
