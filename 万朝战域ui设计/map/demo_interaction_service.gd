class_name DemoInteractionService
extends RefCounted

## ——— Demo 玩法桥接层 ———
## 接收地图模块的行动请求，返回 Demo 模拟结果。
## 正式版本由玩法模块（战斗/经济/资源）替换本层。
## 所有 Mock 行为必须标注为 Demo。

## 删除建筑真实处理器（非 Mock）：由 HUD 在初始化时注入 MapArea.request_delete_building。
## 业务校验与执行全部在 MapBuildingManager 内完成，本层只转发。
var _delete_building_handler: Callable


## 注入删除建筑处理器（签名为 func(building_id: String) -> Dictionary）
func set_delete_building_handler(handler: Callable) -> void:
	_delete_building_handler = handler


## 执行行动并返回模拟结果
func execute(action: MapInteractionAction) -> Dictionary:
	if action == null:
		return _result(false, "无效行动")

	match action.action_id:
		MapActionConstants.ACTION_DELETE_BUILDING:
			return _request_delete_building(action)
		MapActionConstants.ACTION_HARVEST:
			return _mock_harvest(action)
		MapActionConstants.ACTION_ATTACK:
			return _mock_attack(action)
		MapActionConstants.ACTION_SCOUT:
			return _mock_scout(action)
		MapActionConstants.ACTION_MARK:
			return _mock_mark(action)
		MapActionConstants.ACTION_ROUTE_PREVIEW:
			return _mock_route_preview(action)
		MapActionConstants.ACTION_INVESTIGATE:
			return _mock_investigate(action)
		MapActionConstants.ACTION_OCCUPY:
			return _mock_occupy_resource_point(action)
		MapActionConstants.ACTION_CAPTURE_CAPITAL:
			return _mock_capture_capital(action)
		MapActionConstants.ACTION_RETURN_TO_CITY:
			return _mock_return_to_city(action)
		MapActionConstants.ACTION_UPGRADE:
			return _mock_upgrade(action)
		MapActionConstants.ACTION_VIEW:
			return _mock_view(action)
		_:
			return _result(false, "Demo 桥接层未识别行动：%s" % action.action_id)


## ——— Mock 实现 ———

## 删除建筑（真实业务操作，非 Mock）：通过注入的处理器转发到建造系统。
## target_id 即 building_id；权限与数据清理由 MapBuildingManager 保证。
func _request_delete_building(action: MapInteractionAction) -> Dictionary:
	if not _delete_building_handler.is_valid():
		return _result(false, "建造系统不可用，无法删除建筑")
	var result: Variant = _delete_building_handler.call(action.target_id)
	if result is Dictionary:
		return result as Dictionary
	return _result(false, "删除建筑失败")


func _mock_harvest(action: MapInteractionAction) -> Dictionary:
	var resource_type_name: String = str(action.metadata.get("raw_snapshot", {}).get("resource_name", "资源"))
	return _result(true, "[Demo] 已提交%s开采请求（资源 ID：%s）。正式资源结算系统尚未接入。" % [
		resource_type_name, action.target_id
	])


func _mock_attack(action: MapInteractionAction) -> Dictionary:
	var target_name: String = str(action.metadata.get("raw_snapshot", {}).get("name", "目标"))
	return _result(true, "[Demo] 已提交对「%s」的攻打请求（目标 ID：%s）。正式战斗系统尚未接入。" % [
		target_name, action.target_id
	])


func _mock_scout(action: MapInteractionAction) -> Dictionary:
	return _result(true, "[Demo] 侦察请求已创建（目标格子：%s）。正式侦察兵和寻路系统尚未接入。" % action.grid_position)


func _mock_mark(action: MapInteractionAction) -> Dictionary:
	return _result(true, "[Demo] 已标记位置（%s）。标记系统和战术面板尚未接入。" % action.grid_position)


func _mock_route_preview(action: MapInteractionAction) -> Dictionary:
	return _result(true, "[Demo] 路线预览已展示（起点/途经点：%s）。正式寻路和行军系统尚未接入。" % action.grid_position)


func _mock_investigate(_action: MapInteractionAction) -> Dictionary:
	return _result(true, "[Demo] 此处为史局事件预留点，正式事件系统尚未接入。")


func _mock_occupy_resource_point(action: MapInteractionAction) -> Dictionary:
	var resource_name: String = str(action.metadata.get("raw_snapshot", {}).get("resource_name", "资源点"))
	return _result(true, "[Demo] 已提交%s占领请求（资源 ID：%s）。正式占领结算系统尚未接入。" % [
		resource_name, action.target_id
	])


## 中央主城夺取流程（独立于资源点占领）
func _mock_capture_capital(action: MapInteractionAction) -> Dictionary:
	var target_name: String = str(action.metadata.get("raw_snapshot", {}).get("name", "中央主城"))
	return _result(true, "[Demo] 已提交对「%s」的夺取请求（目标 ID：%s）。中央主城控制权、驻军战斗和全局事件尚未接入。" % [
		target_name, action.target_id
	])


func _mock_return_to_city(_action: MapInteractionAction) -> Dictionary:
	return _result(true, "[Demo] 回城功能预留入口。正式行军营和回城系统尚未接入。")


func _mock_upgrade(_action: MapInteractionAction) -> Dictionary:
	return _result(true, "[Demo] 升级请求已提交。正式资源消耗、升级时间和等级变化尚未接入。")


func _mock_view(action: MapInteractionAction) -> Dictionary:
	var ctx_name: String = str(action.metadata.get("raw_snapshot", {}).get("name", "目标"))
	return _result(true, "[Demo] 正在查看「%s」的详细信息。" % ctx_name)


func _result(success: bool, message: String) -> Dictionary:
	return {"success": success, "message": message, "source": "DemoInteractionService"}
