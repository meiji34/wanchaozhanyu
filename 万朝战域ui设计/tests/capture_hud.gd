extends SceneTree


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var output_path := "user://hud_capture.png"
	for index in range(args.size() - 1):
		if args[index] == "--output":
			output_path = args[index + 1]
	var hud_scene := load("res://ui/hud/main_hud.tscn") as PackedScene
	if hud_scene == null:
		push_error("HUD 场景无法加载")
		quit(1)
		return
	var hud := hud_scene.instantiate() as Control
	root.add_child(hud)
	for frame in range(60):
		await process_frame
	if args.has("--selection"):
		hud.call("_on_map_selection_changed", {
			"kind": "city",
			"id": "city_demo",
			"tile_id": Vector2i(12, -8),
			"name": "洛阳",
			"level": 7,
			"faction": "中立",
		})
		await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(output_path)
	if error != OK:
		push_error("HUD 截图保存失败：%s" % error_string(error))
		quit(1)
		return
	print("HUD_CAPTURE=", output_path, " SIZE=", image.get_size())
	quit()
