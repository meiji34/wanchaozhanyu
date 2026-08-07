class_name MapActionConstants
extends RefCounted

## ——— 行动 ID 常量 ———
## 按钮显示文本与行动 ID 分离，正式版本可替换文本/本地化而不影响业务判断。

const ACTION_VIEW: StringName = &"view"
const ACTION_HARVEST: StringName = &"harvest"
const ACTION_ATTACK: StringName = &"attack"
const ACTION_SCOUT: StringName = &"scout"
const ACTION_MARK: StringName = &"mark"
const ACTION_ROUTE_PREVIEW: StringName = &"route_preview"
const ACTION_INVESTIGATE: StringName = &"investigate"
const ACTION_RETURN_TO_CITY: StringName = &"return_to_city"
const ACTION_OCCUPY: StringName = &"occupy"            ## 资源点占领（铁矿/木材/石料/粮食）
const ACTION_CAPTURE_CAPITAL: StringName = &"capture_capital"  ## 中央主城夺取（独立于资源点占领）
const ACTION_UPGRADE: StringName = &"upgrade"
const ACTION_DELETE_BUILDING: StringName = &"delete_building"  ## 删除己方已建造建筑（仅普通玩家建筑）

enum ActionCategory {
	INFO,       ## 查看类
	RESOURCE,   ## 资源类
	COMBAT,     ## 战斗类
	STRATEGY,   ## 战略类
	NAVIGATION, ## 导航类
	EVENT,      ## 事件类
}

## ——— 目标类型枚举 ———
enum TargetType {
	NONE,
	TILE,
	CITY,
	RESOURCE,
	IRON_MINE,
	ROAD,
	BRIDGE,
	FORD,
	PASS,
	HIGH_GROUND,
	HIDDEN_PATH,
	BUILDING,
}


static func get_action_display_name(action_id: StringName) -> String:
	match action_id:
		ACTION_VIEW:
			return "查看"
		ACTION_HARVEST:
			return "开采"
		ACTION_ATTACK:
			return "攻打"
		ACTION_SCOUT:
			return "侦察"
		ACTION_MARK:
			return "标记"
		ACTION_ROUTE_PREVIEW:
			return "路线预览"
		ACTION_INVESTIGATE:
			return "调查"
		ACTION_RETURN_TO_CITY:
			return "回城"
		ACTION_OCCUPY:
			return "占领"
		ACTION_CAPTURE_CAPITAL:
			return "夺取"
		ACTION_UPGRADE:
			return "升级"
		ACTION_DELETE_BUILDING:
			return "删除"
		_:
			return str(action_id)


static func get_action_category(action_id: StringName) -> int:
	match action_id:
		ACTION_VIEW, ACTION_INVESTIGATE:
			return ActionCategory.INFO
		ACTION_HARVEST, ACTION_OCCUPY:
			return ActionCategory.RESOURCE
		ACTION_ATTACK, ACTION_CAPTURE_CAPITAL:
			return ActionCategory.COMBAT
		ACTION_SCOUT, ACTION_MARK, ACTION_RETURN_TO_CITY:
			return ActionCategory.STRATEGY
		ACTION_UPGRADE:
			return ActionCategory.RESOURCE
		ACTION_ROUTE_PREVIEW:
			return ActionCategory.NAVIGATION
		_:
			return ActionCategory.INFO
