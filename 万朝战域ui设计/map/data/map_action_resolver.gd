class_name MapActionResolver
extends RefCounted

## ——— 行动解析器 ———
## 职责：根据目标交互上下文 + 玩家阵营，生成当前可用的行动列表。
## 不负责执行战斗、开采、占领等正式玩法逻辑。

## Demo 模式（所有目标视为已发现/可见，方便演示）
var _demo_mode_enabled: bool = true

## 玩家上下文（由 HUD 注入）
var _player_context: DemoPlayerContext = null


func set_player_context(ctx: DemoPlayerContext) -> void:
	_player_context = ctx


func set_demo_mode(enabled: bool) -> void:
	_demo_mode_enabled = enabled


func get_player_faction() -> StringName:
	return _player_context.current_faction if _player_context != null else &"森林"


## 主入口：返回指定上下文下的可用行动列表
func get_available_actions(context: MapInteractionContext) -> Array[MapInteractionAction]:
	var actions: Array[MapInteractionAction] = []
	if context == null or not context.is_selectable:
		return actions

	match context.target_type:
		MapActionConstants.TargetType.CITY:
			actions = _actions_for_city(context)
		MapActionConstants.TargetType.RESOURCE:
			actions = _actions_for_resource(context)
		MapActionConstants.TargetType.IRON_MINE:
			actions = _actions_for_iron_mine(context)
		MapActionConstants.TargetType.BRIDGE, MapActionConstants.TargetType.FORD:
			actions = _actions_for_landmark(context)
		MapActionConstants.TargetType.ROAD:
			actions = _actions_for_road(context)
		MapActionConstants.TargetType.HIDDEN_PATH:
			actions = _actions_for_hidden_path(context)
		MapActionConstants.TargetType.HIGH_GROUND:
			actions = _actions_for_landmark(context)
		MapActionConstants.TargetType.BUILDING:
			actions = _actions_for_building(context)
		MapActionConstants.TargetType.TILE:
			actions = _actions_for_tile(context)
		_:
			actions = _actions_for_tile(context)

	return actions


func _get_relation(ctx: MapInteractionContext) -> int:
	if _player_context == null:
		return DemoPlayerContext.FactionRelation.NEUTRAL
	# 优先使用 faction_id 判断（更精确，不依赖文本）
	if ctx.faction_id != DemoPlayerContext.FactionId.NONE:
		return _player_context.get_faction_relation_by_id(ctx.faction_id)
	# 回退到 StringName 比较（向后兼容旧快照）
	if ctx.faction == "":
		return DemoPlayerContext.FactionRelation.NEUTRAL
	return _player_context.get_faction_relation(ctx.faction)


## ——— 城池行动 ———
## 根据城池角色（阵营主城/中央主城）和阵营关系生成不同操作集合：
## - 己方阵营主城：查看 + 升级
## - 敌方阵营主城：攻打 + 查看
## - 中央主城（中立/敌对）：查看 + 夺取
func _actions_for_city(ctx: MapInteractionContext) -> Array[MapInteractionAction]:
	var actions: Array[MapInteractionAction] = []
	var rel := _get_relation(ctx)
	var is_central := ctx.city_role == MapCityData.Role.CENTRAL_CAPITAL

	if is_central:
		# 中央主城：无论归属关系，均提供"查看"
		actions.append(_make(MapActionConstants.ACTION_VIEW, ctx))
		if rel == DemoPlayerContext.FactionRelation.FRIENDLY:
			# 己方控制中央主城：可升级
			actions.append(_make(MapActionConstants.ACTION_UPGRADE, ctx))
		else:
			# 非己方控制中央主城：可夺取（独立于资源点占领）
			actions.append(_make(MapActionConstants.ACTION_CAPTURE_CAPITAL, ctx))
	else:
		# 阵营主城
		match rel:
			DemoPlayerContext.FactionRelation.FRIENDLY:
				# 己方主城：查看 + 升级
				actions.append(_make(MapActionConstants.ACTION_VIEW, ctx))
				actions.append(_make(MapActionConstants.ACTION_UPGRADE, ctx))
			_:
				# 敌方/中立主城：攻打 + 查看（不显示占领/侦察/升级）
				actions.append(_make(MapActionConstants.ACTION_ATTACK, ctx))
				actions.append(_make(MapActionConstants.ACTION_VIEW, ctx))

	# 城池交互不需要二次确认（攻打和夺取由执行层处理）
	for act in actions:
		act.requires_confirmation = false

	return actions


## ——— 基础资源点行动（木材/石料/粮食） ———
func _actions_for_resource(ctx: MapInteractionContext) -> Array[MapInteractionAction]:
	var actions: Array[MapInteractionAction] = []
	actions.append(_make(MapActionConstants.ACTION_VIEW, ctx))

	if not ctx.is_discovered and not _demo_mode_enabled:
		actions.append(_make(MapActionConstants.ACTION_SCOUT, ctx))
		return actions

	var rel := _get_relation(ctx)
	if rel == DemoPlayerContext.FactionRelation.FRIENDLY:
		# 己方资源点：可开采，不显示占领
		actions.append(_make(MapActionConstants.ACTION_HARVEST, ctx))
	elif rel == DemoPlayerContext.FactionRelation.HOSTILE:
		# 敌方资源点：可侦察和占领，不允许直接开采
		actions.append(_make(MapActionConstants.ACTION_SCOUT, ctx))
		actions.append(_make(MapActionConstants.ACTION_OCCUPY, ctx, true))
	else:
		# 中立资源点：可开采
		actions.append(_make(MapActionConstants.ACTION_HARVEST, ctx))

	return actions


## ——— 铁矿行动 ———
func _actions_for_iron_mine(ctx: MapInteractionContext) -> Array[MapInteractionAction]:
	var actions: Array[MapInteractionAction] = []
	actions.append(_make(MapActionConstants.ACTION_VIEW, ctx))

	if not (_demo_mode_enabled or ctx.is_discovered):
		actions.append(_make(MapActionConstants.ACTION_SCOUT, ctx))
		return actions

	var rel := _get_relation(ctx)
	if rel == DemoPlayerContext.FactionRelation.FRIENDLY:
		# 己方已控制铁矿：可开采
		actions.append(_make(MapActionConstants.ACTION_HARVEST, ctx))
	else:
		# 敌方或中立铁矿：可侦察和占领
		actions.append(_make(MapActionConstants.ACTION_SCOUT, ctx))
		actions.append(_make(MapActionConstants.ACTION_OCCUPY, ctx, true))

	return actions


## ——— 空白地块 ———
func _actions_for_tile(ctx: MapInteractionContext) -> Array[MapInteractionAction]:
	var actions: Array[MapInteractionAction] = []
	actions.append(_make(MapActionConstants.ACTION_VIEW, ctx))
	actions.append(_make(MapActionConstants.ACTION_SCOUT, ctx))
	return actions


## ——— 建筑（第一版建造系统占位建筑） ———
## 己方建筑：查看 + 删除；非己方建筑：仅查看（不新增敌方建筑攻击功能）。
## 阵营关系基于 owner_faction_id 与当前阵营实时计算，切换阵营后刷新即生效。
func _actions_for_building(ctx: MapInteractionContext) -> Array[MapInteractionAction]:
	var actions: Array[MapInteractionAction] = []
	actions.append(_make(MapActionConstants.ACTION_VIEW, ctx))
	if _get_relation(ctx) == DemoPlayerContext.FactionRelation.FRIENDLY:
		actions.append(_make(MapActionConstants.ACTION_DELETE_BUILDING, ctx))
	return actions


## ——— 道路 ———
func _actions_for_road(ctx: MapInteractionContext) -> Array[MapInteractionAction]:
	var actions: Array[MapInteractionAction] = []
	actions.append(_make(MapActionConstants.ACTION_VIEW, ctx))
	actions.append(_make(MapActionConstants.ACTION_MARK, ctx))
	actions.append(_make(MapActionConstants.ACTION_ROUTE_PREVIEW, ctx))
	return actions


## ——— 隐藏小径 ———
func _actions_for_hidden_path(ctx: MapInteractionContext) -> Array[MapInteractionAction]:
	var actions: Array[MapInteractionAction] = []
	if ctx.is_discovered or _demo_mode_enabled:
		actions.append(_make(MapActionConstants.ACTION_VIEW, ctx))
		actions.append(_make(MapActionConstants.ACTION_MARK, ctx))
		actions.append(_make(MapActionConstants.ACTION_ROUTE_PREVIEW, ctx))
	else:
		actions.append(_make(MapActionConstants.ACTION_SCOUT, ctx))
	return actions


## ——— 地标（桥梁/浅滩/关隘/高地） ———
func _actions_for_landmark(ctx: MapInteractionContext) -> Array[MapInteractionAction]:
	var actions: Array[MapInteractionAction] = []
	actions.append(_make(MapActionConstants.ACTION_VIEW, ctx))
	if _demo_mode_enabled or ctx.is_discovered:
		actions.append(_make(MapActionConstants.ACTION_SCOUT, ctx))
		actions.append(_make(MapActionConstants.ACTION_MARK, ctx))
	else:
		actions.append(_make(MapActionConstants.ACTION_SCOUT, ctx))
	return actions


## ——— 辅助 ———

func _make(
	action_id: StringName,
	ctx: MapInteractionContext,
	enabled: bool = true,
	disabled_reason: String = ""
) -> MapInteractionAction:
	return MapInteractionAction.new(
		action_id,
		MapActionConstants.get_action_display_name(action_id),
		ctx.target_id,
		ctx.target_type,
		ctx.grid_position,
		enabled,
		disabled_reason,
		_requires_confirmation(action_id),
		_build_metadata(action_id, ctx)
	)


func _requires_confirmation(action_id: StringName) -> bool:
	return action_id in [MapActionConstants.ACTION_ATTACK, MapActionConstants.ACTION_OCCUPY, MapActionConstants.ACTION_CAPTURE_CAPITAL, MapActionConstants.ACTION_DELETE_BUILDING]


func _build_metadata(action_id: StringName, ctx: MapInteractionContext) -> Dictionary:
	var meta: Dictionary = {
		"raw_snapshot": ctx.raw_snapshot,
		"requesting_faction": get_player_faction(),
	}
	if ctx.faction != "":
		meta["target_faction"] = ctx.faction
	if action_id in [MapActionConstants.ACTION_ATTACK, MapActionConstants.ACTION_OCCUPY, MapActionConstants.ACTION_CAPTURE_CAPITAL]:
		meta["requires_validation"] = true
	# 标记建筑类型，供执行层区分处理
	if ctx.target_type == MapActionConstants.TargetType.CITY:
		meta["city_role"] = ctx.city_role
		meta["is_central_capital"] = ctx.city_role == MapCityData.Role.CENTRAL_CAPITAL
	return meta
