extends SceneTree

## 建造模式端到端集成测试（真实 MapWorld 场景，无窗口运行）。
## 覆盖：进入/退出建造模式、预览吸附与红绿状态、确认建造、重复放置拦截、
## 取消无残留、反复进入退出无泄漏、建造模式下侦察屏蔽、建筑选中信号。
##
## 运行方式：
##   godot --headless --path <project> --script res://tests/run_construction_integration.gd

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
	else:
		_failures.append(message)
		print("[FAIL] %s" % message)


func _run() -> void:
	var packed := load("res://map/map_world.tscn") as PackedScene
	_check(packed != null, "map_world.tscn 可加载")
	if packed == null:
		_finish()
		return
	var world := packed.instantiate() as MapWorld
	root.add_child(world)
	# 等待初始化完成（init_state 在 _ready 末尾置为 READY）
	var frames := 0
	while world.init_state != MapWorld.MapInitState.READY and frames < 120:
		await process_frame
		frames += 1
	_check(world.init_state == MapWorld.MapInitState.READY, "MapWorld 初始化完成")
	_check(world.building_manager != null, "BuildingManager 已挂载")
	_check(world.get_construction_controller() != null, "ConstructionController 已挂载")

	var player_context := DemoPlayerContext.new()
	world.set_player_context(player_context)
	var construction := world.get_construction_controller()
	var manager := world.building_manager
	var map_data := world.map_controller.map_data
	_check(map_data != null, "地图数据已生成")
	_check(map_data.fog_data != null, "迷雾数据已初始化")

	# ——— 1. 进入建造模式 ———
	world.enter_build_mode()
	_check(world.is_build_mode_active(), "进入建造模式")
	_check(construction._preview != null, "Preview 已创建一次")
	_check(not construction._preview.visible, "首次选点前 Preview 保持隐藏")
	# 重复进入不得产生第二个 Preview
	var first_preview := construction._preview
	world.enter_build_mode()
	_check(construction._preview == first_preview, "重复进入不产生重复 Preview")

	# ——— 2. 寻找合法位置并点击选点 ———
	# MapController 先初始化迷雾再聚焦主城，开局 VISIBLE 圆心在地图中心 (0,0)
	var origin := _find_valid_origin(manager, Vector2i.ZERO)
	_check(origin != Vector2i(999999, 999999), "在当前视野内找到合法 3×3 平整区域 %s" % origin)
	construction.handle_map_click(origin)
	var result := construction.get_last_result()
	_check(bool(result.get("valid", false)), "合法位置校验通过")
	_check(construction._preview.visible, "选点后 Preview 显示")
	_check(
		construction._preview.mesh.material == construction._preview_valid_material,
		"合法位置 Preview 为绿色材质"
	)
	# 预览吸附与高度：中心对齐中间格，底面贴合阶梯顶部
	var expected_center := map_data.grid_to_world(origin)
	var world_size := MapBuildingDefinition.create_test_building().get_world_size(map_data.cell_size)
	var foundation := float(result.get("foundation_height", 0.0))
	_check(is_equal_approx(construction._preview.position.x, expected_center.x), "Preview X 无半格偏移")
	_check(is_equal_approx(construction._preview.position.z, expected_center.z), "Preview Z 无半格偏移")
	_check(
		is_equal_approx(construction._preview.position.y, foundation + world_size.y * 0.5),
		"Preview 底面贴合阶梯表面"
	)

	# ——— 3. 非法位置：越界 → 红色、确认被拒绝 ———
	construction.handle_map_click(map_data.get_min_grid())
	var corner_result := construction.get_last_result()
	_check(not bool(corner_result.get("valid", true)), "越界位置校验失败")
	_check(
		construction._preview.mesh.material == construction._preview_invalid_material,
		"非法位置 Preview 为红色材质"
	)
	var confirm_fail := world.confirm_build_mode()
	_check(not bool(confirm_fail.get("success", true)), "非法位置确认被拒绝")
	_check(world.is_build_mode_active(), "确认失败后仍在建造模式")
	_check(manager.get_building_count() == 0, "非法确认不产生建筑")

	# ——— 4. 回到合法位置确认建造 ———
	construction.handle_map_click(origin)
	var placed := world.confirm_build_mode()
	_check(bool(placed.get("success", false)), "合法位置确认建造成功")
	_check(not world.is_build_mode_active(), "确认后自动退出建造模式")
	_check(construction._preview == null, "退出建造模式后 Preview 已释放")
	_check(manager.get_building_count() == 1, "建筑已注册")
	var building := manager.get_building_at_grid(origin)
	_check(building != null, "占地格子可反查建筑")
	if building != null:
		_check(
			building.owner_faction_id == player_context.current_faction_id,
			"建筑归属当前玩家阵营（森林）"
		)
		_check(building.occupied_cells.size() == 9, "9 格全部锁定")

	# ——— 5. 重复放置拦截 + 取消无残留 ———
	world.enter_build_mode()
	construction.handle_map_click(origin)
	_check(
		not bool(construction.get_last_result().get("valid", true)),
		"已建建筑区域再次放置被拒绝"
	)
	world.exit_build_mode()
	_check(not world.is_build_mode_active(), "取消后退出建造模式")
	_check(construction._preview == null, "取消后 Preview 无残留")
	_check(manager.get_building_count() == 1, "取消不产生占用数据")

	# ——— 6. 反复进入/退出稳定性（信号不重复、节点不残留） ———
	for i in range(3):
		world.enter_build_mode()
		world.exit_build_mode()
	_check(manager.get_building_count() == 1, "反复进出建造模式不产生额外建筑")
	_check(construction._preview == null, "反复进出后无 Preview 残留")
	var preview_count := 0
	for child in construction.get_children():
		if child is MeshInstance3D:
			preview_count += 1
	_check(preview_count == 0, "建造控制器下无残留预览节点")

	# ——— 7. 建造模式下侦察请求被屏蔽 ———
	var scout_count := {"count": 0}
	world.scout_requested.connect(func(_tile: Vector2i) -> void: scout_count["count"] += 1)
	world.enter_build_mode()
	world.request_scout_at_viewport_position(Vector2(100, 100))
	_check(int(scout_count["count"]) == 0, "建造模式下长按/右键不触发侦察")
	world.exit_build_mode()

	# ——— 8. 建筑选中信号 ———
	var selected_id := {"id": ""}
	world.building_selected.connect(func(bid: String, _tid: Vector2i) -> void: selected_id["id"] = bid)
	if building != null:
		world._select_building(building)
		_check(selected_id["id"] == building.building_id, "点击建筑触发 building_selected 信号")

	# ——— 9. 删除建筑：权限、释放、事件、重建 ———
	var building_id: String = building.building_id
	# 9a. 切换阵营后强制删除：业务层必须拒绝（不依赖 UI 按钮显隐）
	player_context.set_current_faction_by_id(DemoPlayerContext.FactionId.MOUNTAIN)
	var denied := world.request_delete_building(building_id)
	_check(not bool(denied.get("success", true)), "非己方阵营强制删除被业务层拒绝")
	_check(manager.get_building_count() == 1, "越权删除后建筑数据不变")
	_check(manager.is_cell_occupied_by_building(origin), "越权删除后占用格不变")
	player_context.set_current_faction_by_id(DemoPlayerContext.FactionId.FOREST)
	# 9b. 己方删除：完整业务闭环
	var removed_event := {"id": ""}
	manager.building_removed.connect(func(bid: String) -> void: removed_event["id"] = bid)
	var deleted := world.request_delete_building(building_id)
	_check(bool(deleted.get("success", false)), "己方删除成功")
	_check(removed_event["id"] == building_id, "building_removed 事件发出")
	_check(manager.get_building_count() == 0, "删除后注册表无建筑")
	_check(not manager.is_cell_occupied_by_building(origin), "删除后 9 格占用释放")
	_check(world._selected_building_id == "", "删除后选中状态自动清理")
	_check(manager.get_building_by_id(building_id) == null, "删除后无法查到建筑数据")
	# 9c. 重复删除安全
	var deleted_again := world.request_delete_building(building_id)
	_check(
		not bool(deleted_again.get("success", true)) and str(deleted_again.get("reason", "")) == "建筑不存在",
		"重复删除安全返回建筑不存在"
	)
	# 9d. 删除后原位置重新通过校验并可再次建造
	var revalidated := manager.validate_placement(
		MapBuildingDefinition.create_test_building(), origin, DemoPlayerContext.FactionId.FOREST
	)
	_check(bool(revalidated.get("valid", false)), "删除后原位置校验恢复合法")
	world.enter_build_mode()
	construction.handle_map_click(origin)
	_check(bool(construction.get_last_result().get("valid", false)), "删除后建造 Preview 恢复绿色")
	var rebuilt := world.confirm_build_mode()
	_check(bool(rebuilt.get("success", false)), "删除后原位置可重新建造")
	_check(manager.get_building_count() == 1, "重建后建筑数恢复为 1")
	_check(
		str(rebuilt.get("building_id", "")) != building_id,
		"重建建筑获得新 building_id，不复用旧 ID"
	)

	# ——— 10. 预览跟随鼠标悬停 ———
	var hover_emits := {"n": 0}
	construction.placement_state_changed.connect(func(_r: Dictionary) -> void: hover_emits["n"] += 1)
	world.enter_build_mode()
	# 悬停非法格（越界）：实时转红并通知 UI
	construction.hover_at_grid(map_data.get_min_grid())
	_check(not bool(construction.get_last_result().get("valid", true)), "悬停非法格实时校验为非法")
	_check(
		construction._preview.mesh.material == construction._preview_invalid_material,
		"悬停非法格 Preview 转红"
	)
	# 悬停合法空格：实时转绿（此时 origin 已被重建建筑占用，扫描会取到下一个合法格）
	var hover_target := _find_valid_origin(manager, Vector2i.ZERO)
	_check(hover_target != origin, "悬停目标为未占用新位置")
	construction.hover_at_grid(hover_target)
	_check(bool(construction.get_last_result().get("valid", false)), "悬停合格格实时校验为合法")
	_check(
		construction._preview.mesh.material == construction._preview_valid_material,
		"悬停合法格 Preview 转绿"
	)
	_check(hover_emits["n"] == 2, "两次异格悬停各通知一次 UI")
	# 同格重复悬停去重：不再重复校验与发信号
	construction.hover_at_grid(hover_target)
	_check(hover_emits["n"] == 2, "同格重复悬停被去重")
	# 仅悬停未锁定：确认被拒绝
	var hover_only := world.confirm_build_mode()
	_check(not bool(hover_only.get("success", true)), "仅悬停未锁定时确认被拒绝")
	_check(str(hover_only.get("reason", "")) == "尚未锁定建造位置", "拒绝原因明确为未锁定")
	# 左键点击 = 锁定位置（不直接生成建筑）
	construction.handle_map_click(hover_target)
	_check(construction.is_position_locked(), "左键点击后进入锁定状态")
	_check(bool(construction.get_last_result().get("locked", false)), "锁定结果携带 locked 标记")
	# 锁定后悬停其他格子：Preview 固定、目标格不变
	var locked_pos: Vector3 = construction._preview.position
	var away := hover_target + Vector2i(6, 0)
	construction.hover_at_grid(away)
	_check(construction._preview.position == locked_pos, "锁定后鼠标移动 Preview 固定不动")
	_check(construction._last_origin == hover_target, "锁定后目标格不被悬停覆盖")
	# 确认建造必须落在锁定格而非鼠标当前悬停格
	var locked_confirm := world.confirm_build_mode()
	_check(bool(locked_confirm.get("success", false)), "锁定后确认建造成功")
	_check(manager.get_building_at_grid(hover_target) != null, "建筑生成在锁定格")
	_check(manager.get_building_at_grid(away) == null, "建筑未生成在鼠标移开的格子")
	# 重新进入建造模式：从预览状态开始，悬停恢复跟随
	world.enter_build_mode()
	_check(not construction.is_position_locked(), "重新进入建造模式从预览状态开始")
	var corner := map_data.get_min_grid()
	construction.hover_at_grid(corner)
	_check(construction._last_origin == corner, "重新进入后悬停恢复更新")
	# 非法位置允许锁定（红色固定）但确认被拒绝、不产生建筑
	construction.handle_map_click(corner)
	_check(construction.is_position_locked(), "非法位置允许锁定")
	var illegal_confirm := world.confirm_build_mode()
	_check(not bool(illegal_confirm.get("success", true)), "非法锁定位置确认被拒绝")
	world.exit_build_mode()
	_check(manager.get_building_count() == 2, "非法确认不产生建筑")

	# ——— 11. 开局初始视野数据：三阵营共享视野均为 VISIBLE ———
	var fog := map_data.fog_data
	var faction_ids: Array[int] = [
		DemoPlayerContext.FactionId.FOREST,
		DemoPlayerContext.FactionId.WETLAND,
		DemoPlayerContext.FactionId.MOUNTAIN,
	]
	var capital_by_faction := {
		DemoPlayerContext.FactionId.FOREST: MapGenerationConfig.FOREST_CAPITAL,
		DemoPlayerContext.FactionId.WETLAND: MapGenerationConfig.WETLAND_CAPITAL,
		DemoPlayerContext.FactionId.MOUNTAIN: MapGenerationConfig.MOUNTAIN_CAPITAL,
	}
	for faction_id in faction_ids:
		_check(fog.get_visible_count(faction_id) > 0, "阵营%d 开局存在 VISIBLE 视野数据" % faction_id)
		for city_id in ["forest_capital", "wetland_capital", "mountain_capital", "central_capital"]:
			var city := map_data.get_city_by_id(city_id)
			_check(
				fog.is_visible(city.grid_position, faction_id),
				"阵营%d 共享主城 %s 为 VISIBLE" % [faction_id, city_id]
			)
			_check(
				fog.is_revealed(city.grid_position, faction_id),
				"阵营%d 共享主城 %s 已探索（VISIBLE 蕴含已探索）" % [faction_id, city_id]
			)
	# 三个阵营在各自主城初始视野内都能找到合法建造位置（开局即可建造）
	for faction_id in faction_ids:
		var home := _find_valid_origin_for(manager, faction_id, capital_by_faction[faction_id])
		_check(
			home != Vector2i(999999, 999999),
			"阵营%d 在己方主城初始视野内可找到合法建造位置" % faction_id
		)

	# ——— 12. 视野语义与隔离：未知 / 已探索不可见 / 当前可见 ———
	var far := _find_far_flat_origin(manager)
	_check(far != Vector2i(999999, 999999), "找到远离初始视野的平整区域 %s" % far)
	if far != Vector2i(999999, 999999):
		var definition := MapBuildingDefinition.create_test_building()
		# 完全未探索：三阵营均禁止
		for faction_id in faction_ids:
			var unknown_check := manager.validate_placement(definition, far, faction_id)
			_check(
				not bool(unknown_check.get("valid", true))
				and str(unknown_check.get("reason", "")) == "占地区域尚未探索",
				"阵营%d 未探索区域禁止建造" % faction_id
			)
		# 森林侦察获得当前视野 → 允许建造
		fog.update_visibility(far, 5, DemoPlayerContext.FactionId.FOREST)
		var forest_visible := manager.validate_placement(definition, far, DemoPlayerContext.FactionId.FOREST)
		_check(bool(forest_visible.get("valid", false)), "森林侦察后的当前可见区域允许建造")
		# 山地仍完全未知 → 禁止（数据隔离）
		var mountain_check := manager.validate_placement(definition, far, DemoPlayerContext.FactionId.MOUNTAIN)
		_check(
			not bool(mountain_check.get("valid", true))
			and str(mountain_check.get("reason", "")) == "占地区域尚未探索",
			"山地不因森林的侦察而获得建造权限"
		)
		# 湿地仅被 reveal_circle 标记为已探索但当前不可见 → 禁止
		fog.reveal_circle(far, 5, DemoPlayerContext.FactionId.WETLAND)
		var wetland_check := manager.validate_placement(definition, far, DemoPlayerContext.FactionId.WETLAND)
		_check(
			not bool(wetland_check.get("valid", true))
			and str(wetland_check.get("reason", "")) == "占地区域不在当前视野内",
			"湿地已探索但当前不可见区域禁止建造"
		)

	# ——— 13. 调试“揭示格子”链路：数据 → 视觉 → 建造一致 ———
	var reveal_target := _find_far_flat_origin(manager)
	_check(reveal_target != Vector2i(999999, 999999), "找到未揭示的平整区域 %s" % reveal_target)
	if reveal_target != Vector2i(999999, 999999):
		var definition := MapBuildingDefinition.create_test_building()
		var before_reveal := manager.validate_placement(
			definition, reveal_target, DemoPlayerContext.FactionId.FOREST
		)
		_check(not bool(before_reveal.get("valid", true)), "揭示前该区域禁止建造")
		# 走调试面板同一路径：MapWorld.reveal_at_cursor → MapController.reveal_area
		world.reveal_at_cursor(reveal_target, 5)
		_check(
			fog.is_visible(reveal_target, DemoPlayerContext.FactionId.FOREST),
			"揭示后写入 VISIBLE"
		)
		_check(
			fog.is_revealed(reveal_target, DemoPlayerContext.FactionId.FOREST),
			"揭示后写入 EXPLORED"
		)
		_check(
			fog.is_unknown(reveal_target, DemoPlayerContext.FactionId.MOUNTAIN),
			"揭示不污染山地阵营视野"
		)
		_check(
			fog.is_unknown(reveal_target, DemoPlayerContext.FactionId.WETLAND),
			"揭示不污染湿地阵营视野"
		)
		var after_reveal := manager.validate_placement(
			definition, reveal_target, DemoPlayerContext.FactionId.FOREST
		)
		_check(bool(after_reveal.get("valid", false)), "揭示区域校验通过（绿色 Preview）")
		# 完整链路：进入建造 → 左键锁定 → 悬停不移位 → 确认生成在锁定格 → 删除 → 可重建
		world.enter_build_mode()
		construction.handle_map_click(reveal_target)
		_check(construction.is_position_locked(), "揭示区域左键锁定成功")
		construction.hover_at_grid(reveal_target + Vector2i(8, 0))
		_check(construction._last_origin == reveal_target, "揭示区域锁定后悬停不移位")
		var reveal_build := world.confirm_build_mode()
		_check(bool(reveal_build.get("success", false)), "揭示区域确认建造成功")
		_check(manager.get_building_at_grid(reveal_target) != null, "建筑生成在揭示区域锁定格")
		var reveal_building_id := str(reveal_build.get("building_id", ""))
		var reveal_delete := world.request_delete_building(reveal_building_id)
		_check(bool(reveal_delete.get("success", false)), "揭示区域建筑可删除")
		var reveal_revalidate := manager.validate_placement(
			definition, reveal_target, DemoPlayerContext.FactionId.FOREST
		)
		_check(bool(reveal_revalidate.get("valid", false)), "删除后揭示区域可重新建造")

	world.queue_free()
	_finish()


func _find_valid_origin(manager: MapBuildingManager, center: Vector2i) -> Vector2i:
	return _find_valid_origin_for(manager, DemoPlayerContext.FactionId.FOREST, center)


func _find_valid_origin_for(
	manager: MapBuildingManager,
	faction_id: int,
	center: Vector2i
) -> Vector2i:
	var definition := MapBuildingDefinition.create_test_building()
	for radius in range(8, 34):
		for y in range(center.y - radius, center.y + radius + 1):
			for x in range(center.x - radius, center.x + radius + 1):
				var origin := Vector2i(x, y)
				var result := manager.validate_placement(definition, origin, faction_id)
				if bool(result.get("valid", false)):
					return origin
	return Vector2i(999999, 999999)


## 寻找一处远离全部初始视野、其他条件均合法的平整区域（三阵营均为 UNKNOWN）
func _find_far_flat_origin(manager: MapBuildingManager) -> Vector2i:
	var definition := MapBuildingDefinition.create_test_building()
	var map_data := manager.get_map_data()
	var fog := map_data.fog_data
	var faction_ids: Array[int] = [
		DemoPlayerContext.FactionId.FOREST,
		DemoPlayerContext.FactionId.WETLAND,
		DemoPlayerContext.FactionId.MOUNTAIN,
	]
	for y in range(30, 150):
		for x in range(30, 150):
			var origin := Vector2i(x, y)
			var cells := definition.get_footprint_cells(origin)
			var ok := true
			for cell in cells:
				if not map_data.is_valid_grid(cell) or not map_data.is_buildable_at(cell):
					ok = false
					break
				if not is_equal_approx(
					map_data.get_surface_height_at_grid(cell),
					map_data.get_surface_height_at_grid(origin)
				):
					ok = false
					break
				if map_data.get_city_at_grid(cell) != null or map_data.get_resource_at_grid(cell) != null:
					ok = false
					break
				for faction_id in faction_ids:
					if not fog.is_unknown(cell, faction_id):
						ok = false
						break
				if not ok:
					break
			if ok:
				return origin
	return Vector2i(999999, 999999)


func _finish() -> void:
	if _failures.is_empty():
		print("CONSTRUCTION_INTEGRATION: ALL PASSED")
	else:
		print("CONSTRUCTION_INTEGRATION: %d FAILED" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
