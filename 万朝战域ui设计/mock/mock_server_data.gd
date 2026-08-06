class_name MockServerData
extends RefCounted

const SERVERS: Array[Dictionary] = [
	{
		"id": "S1",
		"name": "桃园结义",
		"status": "流畅",
		"recent": true,
		"recommended": true,
	},
	{
		"id": "S2",
		"name": "群雄逐鹿",
		"status": "繁忙",
		"recent": false,
		"recommended": false,
	},
	{
		"id": "S3",
		"name": "官渡之战",
		"status": "维护",
		"recent": false,
		"recommended": false,
	},
]

var selected_server_id: String = "S1"


func get_servers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for server in SERVERS:
		result.append(server.duplicate(true))
	return result


func get_selected_server() -> Dictionary:
	return get_server(selected_server_id)


func get_server(server_id: String) -> Dictionary:
	for server in SERVERS:
		if server["id"] == server_id:
			return server.duplicate(true)
	return {}


func select_server(server_id: String) -> bool:
	var server := get_server(server_id)
	if server.is_empty() or server["status"] == "维护":
		return false
	selected_server_id = server_id
	return true

