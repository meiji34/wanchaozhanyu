extends Node

signal auth_changed
signal selected_server_changed(server: Dictionary)
signal resources_changed(resources: Dictionary, changes: Dictionary)
signal tasks_changed(tasks: Array[Dictionary])
signal deployment_created(deployment: Dictionary)

var auth := MockAuthData.new()
var servers := MockServerData.new()
var player := MockPlayerData.new()
var task_source := MockTaskData.new()


func login(account: String, password: String, remember_account: bool) -> bool:
	if account.strip_edges().is_empty() or password.is_empty():
		return false
	var succeeded := auth.login(account, remember_account, false)
	auth_changed.emit()
	return succeeded


func guest_login() -> void:
	auth.login("", false, true)
	auth_changed.emit()


func logout() -> void:
	auth.logout()
	auth_changed.emit()


func get_identity() -> String:
	return auth.display_name if auth.is_logged_in else "未登录"


func get_remembered_account() -> String:
	return auth.remembered_account


func get_servers() -> Array[Dictionary]:
	return servers.get_servers()


func get_selected_server() -> Dictionary:
	return servers.get_selected_server()


func select_server(server_id: String) -> bool:
	var succeeded := servers.select_server(server_id)
	if succeeded:
		selected_server_changed.emit(servers.get_selected_server())
	return succeeded


func get_resources() -> Dictionary:
	return player.resources.duplicate(true)


func get_statuses() -> Dictionary:
	return player.statuses.duplicate(true)


func apply_demo_resource_update() -> void:
	var changes := player.apply_demo_update()
	resources_changed.emit(get_resources(), changes)


func submit_deployment(request: Dictionary) -> Dictionary:
	var quantity := int(request.get("quantity", 0))
	var unit_id := StringName(request.get("unit_id", ""))
	var unit := UnitCatalog.get_by_id(unit_id)
	if quantity <= 0 or unit.is_empty():
		return {"success": false, "message": "出兵请求无效", "source": "MockData"}
	var troop_cost := quantity
	var food_cost := quantity * int(unit.get("food_per_unit", 1))
	if int(player.resources.get("兵力", 0)) < troop_cost:
		return {"success": false, "message": "兵力不足", "source": "MockData"}
	if int(player.resources.get("粮食", 0)) < food_cost:
		return {"success": false, "message": "粮食不足", "source": "MockData"}
	player.resources["兵力"] = int(player.resources["兵力"]) - troop_cost
	player.resources["粮食"] = int(player.resources["粮食"]) - food_cost
	var deployment := request.duplicate(true)
	deployment["unit_name"] = str(unit.get("name", "兵种"))
	deployment["status"] = "已出发"
	deployment["cost"] = {"兵力": troop_cost, "粮食": food_cost}
	resources_changed.emit(get_resources(), {"兵力": -troop_cost, "粮食": -food_cost})
	deployment_created.emit(deployment)
	return {
		"success": true,
		"message": "军令已下达：%d 名%s从「%s」出发" % [quantity, unit.get("name", "兵种"), request.get("origin_city_name", "城池")],
		"deployment": deployment,
		"source": "MockData",
	}


func get_tasks() -> Array[Dictionary]:
	return task_source.get_tasks()


func toggle_task_tracking(task_id: String) -> void:
	task_source.toggle_tracking(task_id)
	tasks_changed.emit(get_tasks())


func advance_demo_task() -> void:
	task_source.advance_demo_task()
	tasks_changed.emit(get_tasks())
