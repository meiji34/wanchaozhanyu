extends SceneTree


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var script := load("res://tests/test_deployment.gd") as Script
	if script == null:
		push_error("出兵测试脚本无法加载")
		quit(1)
		return
	var runner := McpTestRunner.new()
	var results := runner.run_suites([script.new()], "", "", {}, true)
	print("DEPLOYMENT_TEST_RESULTS=", JSON.stringify(results))
	quit(0 if int(results.get("failed", 0)) == 0 else 1)
