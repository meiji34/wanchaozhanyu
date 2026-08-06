extends Node

signal auth_changed
signal selected_server_changed(server: Dictionary)
signal resources_changed(resources: Dictionary, changes: Dictionary)
signal tasks_changed(tasks: Array[Dictionary])

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


func get_tasks() -> Array[Dictionary]:
	return task_source.get_tasks()


func toggle_task_tracking(task_id: String) -> void:
	task_source.toggle_tracking(task_id)
	tasks_changed.emit(get_tasks())


func advance_demo_task() -> void:
	task_source.advance_demo_task()
	tasks_changed.emit(get_tasks())

