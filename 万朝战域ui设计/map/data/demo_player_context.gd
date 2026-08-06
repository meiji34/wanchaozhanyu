class_name DemoPlayerContext
extends RefCounted

## ——— Demo 玩家上下文 ———
## 管理当前玩家的阵营身份。第一版 Demo 只支持单阵营视角。
## 正式版本可由会话/存档系统替换。

## ——— 阵营整数 ID 枚举（稳定，用于数据存储和业务逻辑） ———
enum FactionId {
	NONE    = -1,  ## 无阵营 / 中立格子
	FOREST  = 0,   ## 森林阵营
	WETLAND = 1,   ## 湿地阵营
	MOUNTAIN = 2,  ## 山地阵营
}

## ——— 阵营配置字典（阵营 ID -> 配置数据） ———
const FACTION_CONFIGS: Dictionary = {
	FactionId.FOREST: {
		"name": "森林",
		"display_color": Color(0.18, 0.65, 0.28, 0.35),
	},
	FactionId.WETLAND: {
		"name": "湿地",
		"display_color": Color(0.18, 0.42, 0.78, 0.35),
	},
	FactionId.MOUNTAIN: {
		"name": "山地",
		"display_color": Color(0.78, 0.45, 0.18, 0.35),
	},
}

signal faction_changed(previous_faction: StringName, current_faction: StringName)
## 阵营 ID 变更信号（整数版本，供地图/迷雾/UI 使用）
signal faction_id_changed(previous_faction_id: int, current_faction_id: int)

## 三阵营阵营名常量（保留用于向后兼容和 UI 文本）
const FACTION_FOREST: StringName = &"森林"
const FACTION_MOUNTAIN: StringName = &"山地"
const FACTION_WETLAND: StringName = &"湿地"

## 阵营关系
enum FactionRelation {
	NONE,       ## 无阵营
	FRIENDLY,   ## 己方
	NEUTRAL,    ## 中立
	HOSTILE,    ## 敌方
}

## 当前玩家阵营（StringName 版本，保留向后兼容）
var current_faction: StringName = FACTION_FOREST

## 当前玩家阵营 ID（整数版本，权威数据来源）
var current_faction_id: int = FactionId.FOREST

## 所有可选阵营列表
static func get_available_factions() -> Array[StringName]:
	return [FACTION_FOREST, FACTION_MOUNTAIN, FACTION_WETLAND]


## 获取可选阵营 ID 列表
static func get_available_faction_ids() -> Array[int]:
	return [int(FactionId.FOREST), int(FactionId.WETLAND), int(FactionId.MOUNTAIN)]


## 获取阵营显示名称
static func get_faction_display_name(faction: StringName) -> String:
	match faction:
		FACTION_FOREST:
			return "森林"
		FACTION_MOUNTAIN:
			return "山地"
		FACTION_WETLAND:
			return "湿地"
		_:
			return str(faction)


## 根据阵营 ID 获取阵营名称
static func get_faction_name_by_id(faction_id: int) -> String:
	var raw_config: Variant = FACTION_CONFIGS.get(faction_id, {})
	if not raw_config is Dictionary:
		return "中立"
	var config: Dictionary = raw_config as Dictionary
	return str(config.get("name", "未知阵营"))


## 根据阵营 ID 获取显示颜色
static func get_faction_display_color(faction_id: int) -> Color:
	var raw_config: Variant = FACTION_CONFIGS.get(faction_id, {})
	if not raw_config is Dictionary:
		return Color.TRANSPARENT
	var config: Dictionary = raw_config as Dictionary
	var color_variant: Variant = config.get("display_color", Color.TRANSPARENT)
	if color_variant is Color:
		return color_variant
	return Color.TRANSPARENT


## 根据阵营 ID 获取对应的 StringName（用于向后兼容）
static func faction_id_to_string_name(faction_id: int) -> StringName:
	match faction_id:
		FactionId.FOREST:
			return FACTION_FOREST
		FactionId.WETLAND:
			return FACTION_WETLAND
		FactionId.MOUNTAIN:
			return FACTION_MOUNTAIN
		_:
			return &""


## 设置当前阵营（StringName 版本，保留向后兼容）
func set_current_faction(faction: StringName) -> void:
	var new_faction_id: int = _string_name_to_faction_id(faction)
	set_current_faction_by_id(new_faction_id)


## 设置当前阵营（整数 ID 版本，权威入口）
func set_current_faction_by_id(faction_id: int) -> void:
	if faction_id == current_faction_id:
		return
	var raw_config: Variant = FACTION_CONFIGS.get(faction_id, null)
	if raw_config == null:
		push_warning("无效阵营 ID：%d" % faction_id)
		return
	var previous_faction_id: int = current_faction_id
	var previous_faction: StringName = current_faction
	current_faction_id = faction_id
	current_faction = faction_id_to_string_name(faction_id)
	faction_changed.emit(previous_faction, current_faction)
	faction_id_changed.emit(previous_faction_id, current_faction_id)


## StringName -> int 转换
func _string_name_to_faction_id(faction: StringName) -> int:
	match faction:
		FACTION_FOREST:
			return FactionId.FOREST
		FACTION_WETLAND:
			return FactionId.WETLAND
		FACTION_MOUNTAIN:
			return FactionId.MOUNTAIN
		_:
			return FactionId.NONE


## 判断阵营关系（基于 int ID）
func get_faction_relation_by_id(target_faction_id: int) -> int:
	if target_faction_id == FactionId.NONE:
		return FactionRelation.NEUTRAL
	if target_faction_id == current_faction_id:
		return FactionRelation.FRIENDLY
	if target_faction_id in [FactionId.FOREST, FactionId.WETLAND, FactionId.MOUNTAIN]:
		return FactionRelation.HOSTILE
	return FactionRelation.NEUTRAL


## 判断阵营关系（StringName 版本，保留向后兼容）
func get_faction_relation(target_faction: StringName) -> int:
	if target_faction == "" or target_faction == "中立":
		return FactionRelation.NEUTRAL
	if target_faction == current_faction:
		return FactionRelation.FRIENDLY
	if target_faction in [FACTION_FOREST, FACTION_MOUNTAIN, FACTION_WETLAND]:
		return FactionRelation.HOSTILE
	return FactionRelation.NEUTRAL


## 是否为敌方（基于 int ID）
func is_hostile_by_id(target_faction_id: int) -> bool:
	return get_faction_relation_by_id(target_faction_id) == FactionRelation.HOSTILE


## 是否为敌方
func is_hostile(target_faction: StringName) -> bool:
	return get_faction_relation(target_faction) == FactionRelation.HOSTILE


## 是否为己方（基于 int ID）
func is_own_faction(target_faction_id: int) -> bool:
	return target_faction_id == current_faction_id and target_faction_id != FactionId.NONE


## 是否为中立
func is_neutral(target_faction: StringName) -> bool:
	return get_faction_relation(target_faction) == FactionRelation.NEUTRAL
