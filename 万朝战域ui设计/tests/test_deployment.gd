@tool
extends McpTestSuite


func suite_name() -> String:
	return "deployment"


func test_catalog_matches_twelve_imported_unit_roles() -> void:
	var units := UnitCatalog.get_all()
	assert_eq(units.size(), 12)
	assert_eq(units[0].get("id"), &"01_worker")
	assert_eq(units[8].get("id"), &"09_archer")
	assert_eq(units[11].get("name"), "水军")


func test_only_friendly_city_exposes_deploy_action() -> void:
	var player_context := DemoPlayerContext.new()
	var resolver := MapActionResolver.new()
	resolver.set_player_context(player_context)
	var friendly := _city_context(DemoPlayerContext.FactionId.FOREST)
	var hostile := _city_context(DemoPlayerContext.FactionId.MOUNTAIN)
	assert_true(_has_action(resolver.get_available_actions(friendly), MapActionConstants.ACTION_DEPLOY))
	assert_false(_has_action(resolver.get_available_actions(hostile), MapActionConstants.ACTION_DEPLOY))


func test_service_builds_request_cost_and_forwards_payload() -> void:
	var submitted: Array[Dictionary] = []
	var service := DemoDeploymentService.new()
	service.configure(
		func() -> Dictionary: return {"兵力": 500, "粮食": 500},
		func(payload: Dictionary) -> Dictionary:
			submitted.append(payload)
			return {"success": true, "message": "ok"}
	)
	var request := DeploymentRequest.new()
	request.origin_city_id = &"forest_capital"
	request.origin_city_name = "青木城"
	request.faction_id = DemoPlayerContext.FactionId.FOREST
	request.unit_id = &"08_heavy_cavalry"
	request.quantity = 100
	assert_eq(service.get_cost(request.unit_id, request.quantity), {"兵力": 100, "粮食": 400})
	var result := service.submit(request)
	assert_true(bool(result.get("success", false)))
	assert_eq(submitted.size(), 1)
	assert_eq(submitted[0].get("origin_city_id"), "forest_capital")
	assert_eq(submitted[0].get("quantity"), 100)
	assert_true(not str(submitted[0].get("request_id", "")).is_empty())


func test_service_rejects_insufficient_food_without_submission() -> void:
	var submitted: Array[Dictionary] = []
	var service := DemoDeploymentService.new()
	service.configure(
		func() -> Dictionary: return {"兵力": 500, "粮食": 100},
		func(payload: Dictionary) -> Dictionary:
			submitted.append(payload)
			return {"success": true}
	)
	var request := DeploymentRequest.new()
	request.origin_city_id = &"forest_capital"
	request.faction_id = DemoPlayerContext.FactionId.FOREST
	request.unit_id = &"08_heavy_cavalry"
	request.quantity = 100
	var result := service.submit(request)
	assert_false(bool(result.get("success", true)))
	assert_contains(str(result.get("message", "")), "粮食不足")
	assert_eq(submitted.size(), 0)


func test_service_rejects_hostile_origin_faction() -> void:
	var service := DemoDeploymentService.new()
	service.configure(
		func() -> Dictionary: return {"兵力": 500, "粮食": 500},
		func(_payload: Dictionary) -> Dictionary: return {"success": true},
		func() -> int: return DemoPlayerContext.FactionId.FOREST
	)
	var request := DeploymentRequest.new()
	request.origin_city_id = &"mountain_capital"
	request.faction_id = DemoPlayerContext.FactionId.MOUNTAIN
	request.unit_id = &"02_sword_shield"
	request.quantity = 10
	var result := service.submit(request)
	assert_false(bool(result.get("success", true)))
	assert_contains(str(result.get("message", "")), "己方城池")


func test_mock_endpoint_deducts_troops_and_food() -> void:
	MockData.player.reset()
	var before := MockData.get_resources()
	var result := MockData.submit_deployment({
		"request_id": "deploy_test",
		"origin_city_id": "forest_capital",
		"origin_city_name": "青木城",
		"faction_id": DemoPlayerContext.FactionId.FOREST,
		"unit_id": "02_sword_shield",
		"quantity": 10,
	})
	var after := MockData.get_resources()
	assert_true(bool(result.get("success", false)))
	assert_eq(int(after.get("兵力", 0)), int(before.get("兵力", 0)) - 10)
	assert_eq(int(after.get("粮食", 0)), int(before.get("粮食", 0)) - 10)
	MockData.player.reset()


func test_deployment_panel_shows_all_units_and_valid_request() -> void:
	var service := DemoDeploymentService.new()
	service.configure(
		func() -> Dictionary: return {"兵力": 10000, "粮食": 10000},
		func(_payload: Dictionary) -> Dictionary: return {"success": true, "message": "ok"}
	)
	var panel := track(DeploymentPanel.new()) as DeploymentPanel
	panel.configure(service)
	(Engine.get_main_loop() as SceneTree).root.add_child(panel)
	panel.show_for_city(_city_context(DemoPlayerContext.FactionId.FOREST))
	assert_true(panel.visible)
	assert_eq(panel.get_unit_button_count(), 12)
	assert_true(UnitCatalog.has_unit(panel.get_selected_unit_id()))
	assert_eq(panel.get_quantity(), 100)


func _city_context(faction_id: int) -> MapInteractionContext:
	return MapInteractionContext.from_city_snapshot({
		"kind": "city",
		"id": "forest_capital",
		"name": "青木城",
		"tile_id": Vector2i(12, 8),
		"faction": DemoPlayerContext.get_faction_name_by_id(faction_id),
		"faction_id": faction_id,
		"city_role": MapCityData.Role.FACTION_CAPITAL,
	})


func _has_action(actions: Array[MapInteractionAction], action_id: StringName) -> bool:
	for action: MapInteractionAction in actions:
		if action.action_id == action_id:
			return true
	return false
