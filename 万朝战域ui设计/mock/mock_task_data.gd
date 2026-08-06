class_name MockTaskData
extends RefCounted

var tasks: Array[Dictionary] = [
	{
		"id": "task_rebuild",
		"title": "重整边城",
		"description": "完成一项无等待城建，恢复城池基础运转。",
		"current": 1,
		"target": 3,
		"status": "进行中",
		"unread": true,
		"trackable": true,
		"tracked": true,
	},
	{
		"id": "task_scout",
		"title": "探查旧驿道",
		"description": "派遣斥候确认敌军粮队与道路情况。",
		"current": 2,
		"target": 2,
		"status": "已完成",
		"unread": true,
		"trackable": true,
		"tracked": false,
	},
	{
		"id": "task_alliance",
		"title": "联盟落点",
		"description": "选择加入强盟、小盟或暂时保持中立。",
		"current": 1,
		"target": 1,
		"status": "已领取",
		"unread": false,
		"trackable": false,
		"tracked": false,
	},
]


func get_tasks() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for task in tasks:
		result.append(task.duplicate(true))
	return result


func toggle_tracking(task_id: String) -> void:
	for task in tasks:
		if task["id"] == task_id and task["trackable"]:
			var next_state := not bool(task["tracked"])
			for other in tasks:
				other["tracked"] = false
			task["tracked"] = next_state
			task["unread"] = false
			return


func advance_demo_task() -> void:
	for task in tasks:
		if task["status"] == "进行中":
			task["current"] = mini(int(task["target"]), int(task["current"]) + 1)
			if task["current"] >= task["target"]:
				task["status"] = "已完成"
			task["unread"] = true
			return

