extends SceneTree

const TEST_SCRIPTS: Array[String] = [
	"res://tests/test_demo_map.gd",
	"res://tests/test_environment_models.gd",
	"res://tests/test_core_hud.gd",
	"res://tests/test_construction.gd",
	"res://tests/test_deployment.gd",
]


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var suites: Array = []
	for path in TEST_SCRIPTS:
		var script := load(path) as Script
		if script == null:
			push_error("测试脚本无法加载：%s" % path)
			quit(1)
			return
		suites.append(script.new())
	var runner := McpTestRunner.new()
	var results := runner.run_suites(suites, "", "", {}, true)
	print("HUD_TEST_RESULTS=", JSON.stringify(results))
	quit(0 if int(results.get("failed", 0)) == 0 else 1)
