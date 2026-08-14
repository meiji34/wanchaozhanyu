class_name DemoDeploymentService
extends RefCounted

## 正式玩法接入时只需替换两个 Callable，UI 与请求协议保持不变。
var _resource_provider: Callable
var _submit_handler: Callable
var _faction_provider: Callable
var _request_sequence: int = 0


func configure(resource_provider: Callable, submit_handler: Callable, faction_provider: Callable = Callable()) -> void:
	_resource_provider = resource_provider
	_submit_handler = submit_handler
	_faction_provider = faction_provider


func get_units() -> Array[Dictionary]:
	return UnitCatalog.get_all()


func get_available_resources() -> Dictionary:
	if not _resource_provider.is_valid():
		return {}
	var resources: Variant = _resource_provider.call()
	return (resources as Dictionary).duplicate(true) if resources is Dictionary else {}


func get_cost(unit_id: StringName, quantity: int) -> Dictionary:
	var unit := UnitCatalog.get_by_id(unit_id)
	if unit.is_empty() or quantity <= 0:
		return {"兵力": 0, "粮食": 0}
	return {
		"兵力": quantity,
		"粮食": quantity * int(unit.get("food_per_unit", 1)),
	}


func can_submit(request: DeploymentRequest) -> Dictionary:
	if request == null or not request.is_valid():
		return _result(false, "出兵请求不完整")
	if _faction_provider.is_valid() and request.faction_id != int(_faction_provider.call()):
		return _result(false, "只能从己方城池出兵")
	var resources := get_available_resources()
	if resources.is_empty():
		return _result(false, "资源服务不可用")
	var cost := get_cost(request.unit_id, request.quantity)
	for resource_name: String in cost:
		if int(resources.get(resource_name, 0)) < int(cost[resource_name]):
			return _result(false, "%s不足" % resource_name)
	return _result(true, "可以出兵")


func submit(request: DeploymentRequest) -> Dictionary:
	var validation := can_submit(request)
	if not bool(validation.get("success", false)):
		return validation
	if not _submit_handler.is_valid():
		return _result(false, "出兵接口尚未连接")
	_request_sequence += 1
	request.request_id = "deploy_%d_%d" % [Time.get_unix_time_from_system(), _request_sequence]
	var result: Variant = _submit_handler.call(request.to_dictionary())
	if result is Dictionary:
		return result as Dictionary
	return _result(false, "出兵接口返回了无效结果")


func _result(success: bool, message: String) -> Dictionary:
	return {"success": success, "message": message, "source": "DemoDeploymentService"}
