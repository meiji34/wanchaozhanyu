class_name MapInteractionAction
extends RefCounted

## 唯一行动 ID，对应 MapActionConstants 中的常量
var action_id: StringName = &""

## 界面显示名称（如"开采""攻打""侦察"）
var display_name: String = ""

## 所属目标 ID
var target_id: StringName = &""

## 目标类型（MapActionConstants.TargetType）
var target_type: int = MapActionConstants.TargetType.TILE

## 目标格子坐标
var grid_position: Vector2i = Vector2i.ZERO

## 是否可执行
var enabled: bool = true

## 不可执行原因（如"目标当前不可见"）
var disabled_reason: String = ""

## 是否需要二次确认
var requires_confirmation: bool = false

## 行动类别
var action_category: int = MapActionConstants.ActionCategory.INFO

## 附加数据（供桥接层使用）
var metadata: Dictionary = {}


func _init(
	p_action_id: StringName = &"",
	p_display_name: String = "",
	p_target_id: StringName = &"",
	p_target_type: int = MapActionConstants.TargetType.TILE,
	p_grid_position: Vector2i = Vector2i.ZERO,
	p_enabled: bool = true,
	p_disabled_reason: String = "",
	p_requires_confirmation: bool = false,
	p_metadata: Dictionary = {}
) -> void:
	action_id = p_action_id
	display_name = p_display_name
	target_id = p_target_id
	target_type = p_target_type
	grid_position = p_grid_position
	enabled = p_enabled
	disabled_reason = p_disabled_reason
	requires_confirmation = p_requires_confirmation
	action_category = MapActionConstants.get_action_category(action_id)
	metadata = p_metadata
