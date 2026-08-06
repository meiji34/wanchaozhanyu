extends Control

var _identity_label: Label
var _server_label: Label


func _ready() -> void:
	_build_ui()
	_refresh()
	if not MockData.selected_server_changed.is_connected(_on_server_changed):
		MockData.selected_server_changed.connect(_on_server_changed)


func _exit_tree() -> void:
	if MockData.selected_server_changed.is_connected(_on_server_changed):
		MockData.selected_server_changed.disconnect(_on_server_changed)


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("11100f")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var safe := SafeAreaContainer.new()
	add_child(safe)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	safe.add_child(center)
	var panel := UIBuilder.make_panel()
	panel.custom_minimum_size = Vector2(720, 0)
	center.add_child(panel)
	var content := VBoxContainer.new()
	UIBuilder.set_box_spacing(content, 18)
	panel.add_child(content)
	var title := UIBuilder.make_title("整军待发", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	_identity_label = UIBuilder.make_label("当前身份：", 20, UIBuilder.COLOR_TEXT)
	content.add_child(_identity_label)
	_server_label = UIBuilder.make_label("当前服务器：", 20, UIBuilder.COLOR_ACCENT)
	content.add_child(_server_label)
	var select_button := UIBuilder.make_button("选择服务器")
	select_button.pressed.connect(func() -> void: NavigationManager.open_screen("server_select"))
	content.add_child(select_button)
	var enter_button := UIBuilder.make_primary_button("进入游戏主界面")
	enter_button.pressed.connect(_enter_game)
	content.add_child(enter_button)
	var logout_button := UIBuilder.make_danger_button("退出登录")
	logout_button.pressed.connect(_confirm_logout)
	content.add_child(logout_button)
	content.add_child(UIBuilder.make_label("当前演示将进入 UI HUD，不加载正式地图与玩法系统。", 16, UIBuilder.COLOR_MUTED, true))


func _refresh() -> void:
	_identity_label.text = "当前身份：%s" % MockData.get_identity()
	var server := MockData.get_selected_server()
	_server_label.text = "当前服务器：%s %s · %s" % [server.get("id", "--"), server.get("name", "未选择"), server.get("status", "未知")]


func _on_server_changed(_server: Dictionary) -> void:
	_refresh()


func _enter_game() -> void:
	var server := MockData.get_selected_server()
	if server.is_empty() or server.get("status", "维护") == "维护":
		NavigationManager.show_error("服务器不可用", "请选择非维护状态的服务器后再进入。")
		return
	NavigationManager.replace_screen("loading", {"target": "main_hud", "message": "正在部署指挥界面", "duration": 1.0}, true)


func _confirm_logout() -> void:
	NavigationManager.show_confirm(
		"退出登录",
		"将清除本次 Mock 登录状态与密码，是否继续？",
		_logout,
		Callable(),
		"退出登录",
		"继续游戏"
	)


func _logout() -> void:
	MockData.logout()
	NavigationManager.replace_screen("login", {}, true)

