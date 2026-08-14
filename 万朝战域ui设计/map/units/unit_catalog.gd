class_name UnitCatalog
extends RefCounted

## 出兵 UI 与玩法层共享的兵种目录。ID 与 Ya 分支交付的模型目录保持一致。
const UNITS: Array[Dictionary] = [
	{"id": &"01_worker", "name": "工人", "category": "生产", "food_per_unit": 1, "summary": "擅长采集与随军建设"},
	{"id": &"02_sword_shield", "name": "刀盾兵", "category": "步兵", "food_per_unit": 1, "summary": "近战防御稳定"},
	{"id": &"03_spearman", "name": "长枪兵", "category": "步兵", "food_per_unit": 1, "summary": "克制骑兵冲锋"},
	{"id": &"04_halberdier", "name": "戟兵", "category": "步兵", "food_per_unit": 2, "summary": "兼顾破甲与控线"},
	{"id": &"05_light_cavalry", "name": "轻骑兵", "category": "骑兵", "food_per_unit": 2, "summary": "高速机动与追击"},
	{"id": &"06_heavy_infantry", "name": "重装步兵", "category": "步兵", "food_per_unit": 2, "summary": "承受正面攻势"},
	{"id": &"07_horse_archer", "name": "弓骑兵", "category": "骑兵", "food_per_unit": 3, "summary": "机动远程压制"},
	{"id": &"08_heavy_cavalry", "name": "重骑兵", "category": "骑兵", "food_per_unit": 4, "summary": "强力正面冲击"},
	{"id": &"09_archer", "name": "弓兵", "category": "远程", "food_per_unit": 1, "summary": "持续远程输出"},
	{"id": &"10_crossbowman", "name": "弩兵", "category": "远程", "food_per_unit": 2, "summary": "高穿透齐射"},
	{"id": &"11_scout", "name": "斥候", "category": "侦察", "food_per_unit": 1, "summary": "高速侦察与探路"},
	{"id": &"12_marine", "name": "水军", "category": "水军", "food_per_unit": 2, "summary": "适应水域作战"},
]


static func get_all() -> Array[Dictionary]:
	return UNITS.duplicate(true)


static func get_by_id(unit_id: StringName) -> Dictionary:
	for unit: Dictionary in UNITS:
		if StringName(unit.get("id", &"")) == unit_id:
			return unit.duplicate(true)
	return {}


static func has_unit(unit_id: StringName) -> bool:
	return not get_by_id(unit_id).is_empty()
