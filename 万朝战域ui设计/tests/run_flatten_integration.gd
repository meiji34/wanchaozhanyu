extends SceneTree

## 土地平整端到端集成测试（真实 MapWorld 场景，无窗口运行）。
## 覆盖：进入/退出平整模式、与建造模式互斥、预览跟随与动态刷新、
## 预览不修改真实数据、确认后地形/Mesh 碰撞/射线拾取同步、迷雾数据不受影响、
## 平整后原建造校验自然通过并成功放置建筑、非法区域拦截、取消无残留。
##
## 运行方式：
##   godot --headless --path <project> --script res://tests/run_flatten_integration.gd

var _failures: Array[String] = []
const INVALID_CELL := Vector2i(999999, 999999)


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
	var frames := 0
	while world.init_state != MapWorld.MapInitState.READY and frames < 120:
		await process_frame
		frames += 1
	_check(world.init_state == MapWorld.MapInitState.READY, "MapWorld 初始化完成")

	var player_context := DemoPlayerContext.new()
	world.set_player_context(player_context)
	var flatten := world.get_terrain_flatten_controller()
	_check(flatten != null, "TerrainFlattenController 已挂载")
	var construction := world.get_construction_controller()
	var manager := world.building_manager
	var map_data := world.map_controller.map_data
	var fog := map_data.fog_data
	_check(fog != null, "迷雾数据已初始化")

	# ——— 0. 寻找高度不一致但可平整的 3×3 区域并揭示视野 ———
	var origin := _find_mixed_flattenable_region(map_data)
	_check(origin != INVALID_CELL, "找到高度不一致的可平整区域 %s" % origin)
	if origin == INVALID_CELL:
		world.queue_free()
		_finish()
		return
	world.reveal_at_cursor(origin, 6)
	var region := MapBuildingDefinition.compute_footprint_cells(origin, Vector2i(3, 3))
	var before_levels: Array[int] = []
	var target_level := 0
	for cell in region:
		var level := map_data.get_height_level_at_grid(cell)
		before_levels.append(level)
		target_level = maxi(target_level, level)
	_check(fog.is_visible(origin, DemoPlayerContext.FactionId.FOREST), "目标区域已揭示为可见")
	var explored_before := fog.get_explored_count(DemoPlayerContext.FactionId.FOREST)

	# ——— 1. 进入/退出与模式互斥 ———
	world.enter_flatten_mode()
	_check(world.is_flatten_mode_active(), "进入土地平整模式")
	_check(flatten._preview != null, "平整预览节点已创建")
	_check(not flatten._preview.visible, "首次选点前预览保持隐藏")
	world.enter_build_mode()
	_check(not world.is_flatten_mode_active(), "进入建造模式自动退出平整模式")
	_check(world.is_build_mode_active(), "建造模式已激活")
	world.enter_flatten_mode()
	_check(not world.is_build_mode_active(), "进入平整模式自动退出建造模式")
	_check(world.is_flatten_mode_active(), "平整模式已激活")

	# ——— 2. 预览跟随与动态刷新（不修改真实数据） ———
	flatten.hover_at_grid(origin)
	_check(flatten._preview.visible, "悬停后预览显示")
	_check(
		flatten._preview.multimesh.instance_count == 9,
		"3×3 范围预览 9 个格子实例"
	)
	flatten.adjust_region_width(1)
	_check(
		flatten._preview.multimesh.instance_count == 12,
		"宽度 +1 后预览立即刷新为 12 格"
	)
	flatten.adjust_region_width(-1)
	# 未锁定位置不得确认
	var unlocked_confirm := flatten.confirm()
	_check(
		not bool(unlocked_confirm.get("success", true)),
		"未锁定位置时确认被拒绝"
	)
	# 左键点击锁定位置：悬停不再移动预览，调整参数仍以锁定锚点重算
	flatten.handle_map_click(origin)
	_check(flatten.is_position_locked(), "左键点击后位置已锁定")
	flatten.hover_at_grid(origin + Vector2i(6, 0))
	_check(
		flatten.get_last_state().get("anchor_cell") == origin,
		"锁定后悬停预览保持固定"
	)
	flatten.adjust_region_width(1)
	_check(
		flatten.get_last_state().get("anchor_cell") == origin,
		"锁定后调整范围仍以锁定锚点重算"
	)
	flatten.adjust_region_width(-1)
	# 重新选择：解除锁定后悬停恢复跟随
	flatten.unlock_position()
	_check(not flatten.is_position_locked(), "重新选择解除锁定")
	flatten.hover_at_grid(origin + Vector2i(6, 0))
	_check(
		flatten.get_last_state().get("anchor_cell") == origin + Vector2i(6, 0),
		"解除锁定后预览恢复跟随鼠标"
	)
	flatten.hover_at_grid(origin)
	flatten.handle_map_click(origin)
	_check(flatten.is_position_locked(), "重新锁定回目标区域")
	var delta_to_target := target_level - flatten.get_target_height_level()
	flatten.adjust_target_height(delta_to_target)
	_check(
		flatten.get_target_height_level() == target_level,
		"目标高度等级调整到 %d" % target_level
	)
	var expected_y := (
		float(target_level) * MapGenerationConfig.HEIGHT_STEP
		+ MapTerrainFlattenController.PREVIEW_Y_OFFSET
	)
	# 无窗口 DummyRS 无法回读 MultiMesh 变换，改用控制器记录的预览变换核对
	var preview_transforms := flatten.get_preview_transforms()
	_check(preview_transforms.size() == 9, "预览变换记录与范围格数一致")
	if not preview_transforms.is_empty():
		var preview_y := preview_transforms[0].origin.y
		_check(
			is_equal_approx(preview_y, expected_y),
			"预览薄板位于目标高度（目标高度预览可见）"
		)
	for i in range(region.size()):
		_check(
			map_data.get_height_level_at_grid(region[i]) == before_levels[i],
			"预览阶段格子 %s 真实高度未变" % region[i]
		)
	var state := flatten.get_last_state()
	_check(bool(state.get("valid", false)), "混合高度区域平整校验通过")
	_check(int(state.get("changed_count", 0)) > 0, "存在需要改变高度的格子")
	_check(int(state.get("duration", -1)) == 0, "预计耗时为 0（测试阶段立即完成）")
	# 高度差规则：目标超出任意格子 ±2 级即非法，预览与确认共用同一校验。
	# 调整方向避开可选范围钳制：优先 +3，超出可选上限则 -3
	var max_selectable := int(flatten.get_last_state().get("max_height_level", 0))
	var over_delta := 3 if target_level + 3 <= max_selectable else -3
	flatten.adjust_target_height(over_delta)
	_check(
		not bool(flatten.get_last_state().get("valid", true)),
		"高度差超过 2 级时预览立即判定非法"
	)
	var denied_delta := flatten.confirm()
	_check(not bool(denied_delta.get("success", true)), "高度差超限时确认被拒绝")
	_check(
		str(denied_delta.get("reason", "")).contains("相差超过"),
		"高度差超限原因提示明确"
	)
	flatten.adjust_target_height(-over_delta)
	_check(
		bool(flatten.get_last_state().get("valid", false)),
		"高度差回到 <= 2 后恢复合法"
	)

	# ——— 3. 确认平整：真实数据、拾取、碰撞同步 ———
	var confirm_result := flatten.confirm()
	_check(bool(confirm_result.get("success", false)), "确认平整成功")
	_check(not world.is_flatten_mode_active(), "确认后自动退出平整模式")
	_check(flatten._preview == null, "退出后预览节点已释放")
	for cell in region:
		_check(
			map_data.get_height_level_at_grid(cell) == target_level,
			"格子 %s 真实高度等级变为 %d" % [cell, target_level]
		)
	_check(
		fog.get_explored_count(DemoPlayerContext.FactionId.FOREST) == explored_before,
		"平整不改变任何迷雾探索数据"
	)
	# 射线拾取必须命中新高度（拾取与显示地形一致）
	var pick_center := map_data.grid_to_world(origin, 50.0)
	var hit_variant: Variant = map_data.intersect_heightfield_ray(pick_center, Vector3.DOWN)
	_check(hit_variant != null, "平整后射线仍可命中该区域")
	if hit_variant != null:
		var hit := hit_variant as Vector3
		_check(
			is_equal_approx(hit.y, float(target_level) * MapGenerationConfig.HEIGHT_STEP),
			"射线拾取高度与平整后地形一致"
		)
	# 物理碰撞必须同步重建（Chunk 局部重建后的碰撞面包含目标高度）
	var chunk_coord := map_data.grid_to_chunk(origin)
	var chunk := world.map_controller.active_chunks.get(chunk_coord) as MapChunk
	if chunk == null:
		# Chunk 未加载时跳过碰撞面检查（重新加载时会读取最新数据重建）
		print("[SKIP] 目标 Chunk 未激活，跳过碰撞面顶点检查")
	else:
		var collision_shape := chunk.get_node_or_null(
			"TerrainCollision/TerrainCollisionShape"
		) as CollisionShape3D
		_check(collision_shape != null, "目标 Chunk 碰撞体存在")
		if collision_shape != null:
			var concave := collision_shape.shape as ConcavePolygonShape3D
			var faces := concave.get_faces()
			var found_target_height := false
			var local_origin := map_data.grid_to_world(
				origin, float(target_level) * MapGenerationConfig.HEIGHT_STEP
			) - chunk.global_position
			for vertex in faces:
				if (
					absf(vertex.y - local_origin.y) < 0.01
					and vertex.distance_to(local_origin) < map_data.cell_size * 2.0
				):
					found_target_height = true
					break
			_check(found_target_height, "碰撞面已同步到目标高度")

	# ——— 4. 平整后的土地参与原建造判断并成功建造；道路区域不可建 ———
	world.enter_build_mode()
	# 道路禁止建造：footprint 任一道路格即非法（预览与确认共用同一校验）
	var road_origin := _find_buildable_road_origin(map_data)
	_check(road_origin != INVALID_CELL, "找到前置校验可通过的道路建造位置")
	# 记录 footprint 中的真实道路格，用于流程结束后核对道路数据未丢失
	var road_witness := INVALID_CELL
	if road_origin != INVALID_CELL:
		for cell in MapBuildingDefinition.compute_footprint_cells(road_origin, Vector2i(3, 3)):
			if map_data.has_road_at(cell):
				road_witness = cell
				break
		world.reveal_at_cursor(road_origin, 5)
		construction.handle_map_click(road_origin)
		var road_state := construction.get_last_result()
		_check(
			not bool(road_state.get("valid", true)),
			"建筑预览在道路上立即显示非法"
		)
		_check(
			str(road_state.get("reason", "")) == "占地区域包含道路",
			"道路非法原因明确"
		)
		var road_denied := world.confirm_build_mode()
		_check(not bool(road_denied.get("success", true)), "道路上最终建造被拒绝")
		_check(
			manager.get_building_at_grid(road_origin) == null,
			"道路上未生成建筑"
		)
	construction.handle_map_click(origin)
	var build_state := construction.get_last_result()
	_check(
		bool(build_state.get("valid", false)),
		"平整区域建造校验自然通过（无 force_buildable 旁路）"
	)
	_check(
		is_equal_approx(
			float(build_state.get("foundation_height", 0.0)),
			float(target_level) * MapGenerationConfig.HEIGHT_STEP
		),
		"建造地基高度等于平整目标高度"
	)
	var placed := world.confirm_build_mode()
	_check(bool(placed.get("success", false)), "平整后土地成功建造建筑")
	_check(manager.get_building_at_grid(origin) != null, "建筑已生成在平整区域")
	if road_witness != INVALID_CELL:
		_check(map_data.has_road_at(road_witness), "平整与建造流程后道路数据未丢失")

	# ——— 4.5 格子信息快照提供逻辑高度等级 ———
	var snapshot := world.get_tile_snapshot(origin)
	_check(
		int(snapshot.get("height_level", -1)) == target_level,
		"格子信息快照读取逻辑高度等级（非世界 Y 值）"
	)

	# ——— 5. 非法区域拦截 ———
	world.enter_flatten_mode()
	flatten.hover_at_grid(MapGenerationConfig.FOREST_CAPITAL)
	_check(
		not bool(flatten.get_last_state().get("valid", true)),
		"主城占用区域禁止平整"
	)
	flatten.handle_map_click(MapGenerationConfig.FOREST_CAPITAL)
	var denied := flatten.confirm()
	_check(not bool(denied.get("success", true)), "非法区域确认被拒绝")
	_check(world.is_flatten_mode_active(), "确认失败后仍在平整模式")

	# ——— 6. 取消无残留、不修改数据 ———
	flatten.unlock_position()
	flatten.hover_at_grid(origin + Vector2i(10, 0))
	var cancel_watch := origin + Vector2i(10, 0)
	var level_before_cancel := (
		map_data.get_height_level_at_grid(cancel_watch)
		if map_data.is_valid_grid(cancel_watch)
		else -1
	)
	world.exit_flatten_mode()
	_check(not world.is_flatten_mode_active(), "取消后退出平整模式")
	_check(flatten._preview == null, "取消后预览无残留")
	if level_before_cancel >= 0:
		_check(
			map_data.get_height_level_at_grid(cancel_watch) == level_before_cancel,
			"取消后真实地形完全不变"
		)
	var preview_count := 0
	for child in flatten.get_children():
		if child is MultiMeshInstance3D:
			preview_count += 1
	_check(preview_count == 0, "平整控制器下无残留预览节点")

	# ——— 7. 山地 → 平整 → 建造（真实场景端到端） ———
	var mountain_origin := _find_mixed_mountain_region(map_data)
	_check(mountain_origin != INVALID_CELL, "找到可合法平整的山地区域 %s" % mountain_origin)
	if mountain_origin != INVALID_CELL:
		world.reveal_at_cursor(mountain_origin, 6)
		var mountain_cells := MapBuildingDefinition.compute_footprint_cells(
			mountain_origin, Vector2i(3, 3)
		)
		var mountain_target := 0
		for cell in mountain_cells:
			mountain_target = maxi(
				mountain_target, map_data.get_height_level_at_grid(cell)
			)
		# A：未经平整的山地不可建造
		world.enter_build_mode()
		construction.handle_map_click(mountain_origin)
		_check(
			not bool(construction.get_last_result().get("valid", true)),
			"未经平整的山地建筑预览判定非法"
		)
		# 合法平整山地
		world.enter_flatten_mode()
		flatten.handle_map_click(mountain_origin)
		flatten.adjust_target_height(
			mountain_target - flatten.get_target_height_level()
		)
		_check(
			bool(flatten.get_last_state().get("valid", false)),
			"山地区域满足高度差规则，平整校验通过"
		)
		var mountain_result := flatten.confirm()
		_check(bool(mountain_result.get("success", false)), "山地平整执行成功")
		_check(
			map_data.get_terrain_type_at(mountain_origin) == MapTileTypes.Terrain.MOUNTAIN,
			"平整后山地保留 MOUNTAIN 地形类型"
		)
		_check(
			map_data.is_buildable_at(mountain_origin),
			"平整后可建造标记已按真实坡度重算"
		)
		# B：平整后的山地预览合法且真实建造成功
		world.enter_build_mode()
		construction.handle_map_click(mountain_origin)
		_check(
			bool(construction.get_last_result().get("valid", false)),
			"平整后的山地建筑预览重新验证为合法"
		)
		var mountain_placed := world.confirm_build_mode()
		_check(bool(mountain_placed.get("success", false)), "平整后的山地成功生成建筑")
		_check(
			manager.get_building_at_grid(mountain_origin) != null,
			"建筑已生成在平整后的山地区域"
		)
		# E：其他未经平整的山地仍不可建造
		var steep_origin := _find_unflattened_mountain_origin(map_data)
		_check(steep_origin != INVALID_CELL, "找到未经平整的山地区域")
		if steep_origin != INVALID_CELL:
			world.reveal_at_cursor(steep_origin, 5)
			# 上一步建造成功后已自动退出建造模式，必须重新进入再选点
			world.enter_build_mode()
			construction.handle_map_click(steep_origin)
			_check(
				not bool(construction.get_last_result().get("valid", true)),
				"未经平整的山地仍然不可建造"
			)

	world.queue_free()
	_finish()


## 寻找一个 footprint 含道路且前置校验（边界/地形/高度一致）可通过的建造位置，
## 确保非法原因一定是道路本身
func _find_buildable_road_origin(map_data: DemoMapData) -> Vector2i:
	var definition := MapBuildingDefinition.create_test_building()
	for y in range(-140, 140):
		for x in range(-140, 140):
			var origin := Vector2i(x, y)
			var cells := definition.get_footprint_cells(origin, 0)
			var road_count := 0
			var preconditions_ok := true
			for cell in cells:
				if (
					not map_data.is_valid_grid(cell)
					or not map_data.is_buildable_at(cell)
					or map_data.get_city_at_grid(cell) != null
					or map_data.get_resource_at_grid(cell) != null
				):
					preconditions_ok = false
					break
				if map_data.has_road_at(cell):
					road_count += 1
			if not preconditions_ok or road_count == 0:
				continue
			var foundation := map_data.get_surface_height_at_grid(origin)
			var height_ok := true
			for cell in cells:
				if not is_equal_approx(
					map_data.get_surface_height_at_grid(cell), foundation
				):
					height_ok = false
					break
			if height_ok:
				return origin
	return INVALID_CELL


## 寻找一块 3×3 纯山地区域（高度不一致且极差 <= 平整允许差值，无道路/城池/资源点）。
## 不过滤 is_buildable_at——山地格子在修复前该标记恒为 false，正是被测对象。
## 额外精确模拟平整后的边缘坡度（中心差分合向量），保证平整后全部 9 格
## 满足既有 MAX_BUILDABLE_SLOPE 规则，避免紧邻悬崖的边缘格仍然不可建造。
func _find_mixed_mountain_region(map_data: DemoMapData) -> Vector2i:
	for y in range(-140, 140):
		for x in range(-140, 140):
			var origin := Vector2i(x, y)
			var cells := MapBuildingDefinition.compute_footprint_cells(origin, Vector2i(3, 3))
			var usable := true
			var mixed := false
			var min_level := 0
			var max_level := 0
			for i in range(cells.size()):
				var cell := cells[i]
				if (
					not map_data.is_valid_grid(cell)
					or map_data.get_terrain_type_at(cell) != MapTileTypes.Terrain.MOUNTAIN
					or map_data.has_road_at(cell)
					or map_data.get_city_at_grid(cell) != null
					or map_data.get_resource_at_grid(cell) != null
				):
					usable = false
					break
				var level := map_data.get_height_level_at_grid(cell)
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
				var left := _sim_level(map_data, cell + Vector2i.LEFT, cell_set, max_level)
				var right := _sim_level(map_data, cell + Vector2i.RIGHT, cell_set, max_level)
				var back := _sim_level(map_data, cell + Vector2i.UP, cell_set, max_level)
				var front := _sim_level(map_data, cell + Vector2i.DOWN, cell_set, max_level)
				var slope := Vector2(right - left, front - back).length() * (
					MapGenerationConfig.HEIGHT_STEP / (map_data.cell_size * 2.0)
				)
				if slope > MapGenerationConfig.MAX_BUILDABLE_SLOPE:
					slopes_ok = false
					break
			if slopes_ok:
				return origin
	return INVALID_CELL


## 模拟平整后的格子高度等级：区域内取目标等级，区域外取真实等级
func _sim_level(
	map_data: DemoMapData, cell: Vector2i, region_set: Dictionary, target_level: int
) -> float:
	if region_set.has(cell):
		return float(target_level)
	if not map_data.is_valid_grid(cell):
		return float(target_level)
	return float(map_data.get_height_level_at_grid(cell))


## 寻找一块未经平整（高度不一致）的 3×3 纯山地区域
func _find_unflattened_mountain_origin(map_data: DemoMapData) -> Vector2i:
	for y in range(-140, 140):
		for x in range(-140, 140):
			var origin := Vector2i(x, y)
			var cells := MapBuildingDefinition.compute_footprint_cells(origin, Vector2i(3, 3))
			var all_mountain := true
			var mixed := false
			var first_level := 0
			for i in range(cells.size()):
				var cell := cells[i]
				if (
					not map_data.is_valid_grid(cell)
					or map_data.get_terrain_type_at(cell) != MapTileTypes.Terrain.MOUNTAIN
					or map_data.has_road_at(cell)
					or map_data.get_city_at_grid(cell) != null
					or map_data.get_resource_at_grid(cell) != null
				):
					all_mountain = false
					break
				var level := map_data.get_height_level_at_grid(cell)
				if i == 0:
					first_level = level
				elif level != first_level:
					mixed = true
			if all_mountain and mixed:
				return origin
	return INVALID_CELL


## 寻找一块 3×3 高度不一致的可平整区域（普通陆地、无道路/城池/资源点）
func _find_mixed_flattenable_region(map_data: DemoMapData) -> Vector2i:
	for y in range(-100, 100):
		for x in range(-100, 100):
			var origin := Vector2i(x, y)
			var cells := MapBuildingDefinition.compute_footprint_cells(origin, Vector2i(3, 3))
			var usable := true
			var mixed := false
			var min_level := 0
			var max_level := 0
			for i in range(cells.size()):
				var cell := cells[i]
				if (
					not map_data.is_valid_grid(cell)
					or not map_data.is_buildable_at(cell)
					or map_data.get_terrain_type_at(cell) != MapTileTypes.Terrain.PLAIN
					or map_data.has_road_at(cell)
					or map_data.get_city_at_grid(cell) != null
					or map_data.get_resource_at_grid(cell) != null
				):
					usable = false
					break
				var level := map_data.get_height_level_at_grid(cell)
				if i == 0:
					min_level = level
					max_level = level
				else:
					min_level = mini(min_level, level)
					max_level = maxi(max_level, level)
					if level != min_level:
						mixed = true
			# 目标取区域最高等级时最大高度差 = 极差，要求 <= 平整允许差值
			if (
				usable and mixed
				and max_level - min_level <= MapTerrainFlattenController.MAX_FLATTEN_HEIGHT_DELTA
			):
				return origin
	return INVALID_CELL


func _finish() -> void:
	if _failures.is_empty():
		print("FLATTEN_INTEGRATION: ALL PASSED")
	else:
		print("FLATTEN_INTEGRATION: %d FAILED" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
