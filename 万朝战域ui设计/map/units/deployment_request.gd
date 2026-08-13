class_name DeploymentRequest
extends RefCounted

var request_id: String = ""
var origin_city_id: StringName = &""
var origin_city_name: String = ""
var faction_id: int = DemoPlayerContext.FactionId.NONE
var unit_id: StringName = &""
var quantity: int = 0
var target_grid: Variant = null


func is_valid() -> bool:
	return origin_city_id != &"" and faction_id != DemoPlayerContext.FactionId.NONE and UnitCatalog.has_unit(unit_id) and quantity > 0


func to_dictionary() -> Dictionary:
	var payload: Dictionary = {
		"request_id": request_id,
		"origin_city_id": str(origin_city_id),
		"origin_city_name": origin_city_name,
		"faction_id": faction_id,
		"unit_id": str(unit_id),
		"quantity": quantity,
	}
	if target_grid is Vector2i:
		payload["target_grid"] = target_grid
	return payload
