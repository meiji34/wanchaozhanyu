class_name MockPlayerData
extends RefCounted

var resources: Dictionary = {
	"银两": 1000,
	"粮食": 900,
	"木材": 600,
	"石料": 500,
	"兵力": 10000,
}

var statuses: Dictionary = {
	"城防": "50 / 100",
	"士气": "70 / 100",
	"补给": "80 / 100",
	"民心": "55 / 100",
	"情报": "0 / 5",
	"联盟贡献": "0",
	"赛季推进": "0%",
	"名将状态": "完好",
}


func apply_demo_update() -> Dictionary:
	var changes := {
		"银两": 120,
		"粮食": -80,
		"木材": 60,
		"石料": 40,
		"兵力": 500,
	}
	for key in changes:
		resources[key] = maxi(0, int(resources[key]) + int(changes[key]))
	statuses["士气"] = "75 / 100"
	statuses["补给"] = "72 / 100"
	return changes


func reset() -> void:
	resources = {
		"银两": 1000,
		"粮食": 900,
		"木材": 600,
		"石料": 500,
		"兵力": 10000,
	}
	statuses["士气"] = "70 / 100"
	statuses["补给"] = "80 / 100"

