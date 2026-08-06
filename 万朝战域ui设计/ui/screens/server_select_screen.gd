extends Control

var _selected_id: String = ""
var _server_buttons: Dictionary = {}
var _confirm_button: Button
var _selection_label: Label


func _ready() -> void:
	_selected_id = str(MockData.get_selected_server().get("id", "S1"))
	_build_ui()
	_refresh_selection()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("11100f")
	add_child(background)
	var safe := SafeAreaContainer.new()
	add_child(safe)
	var content := VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UIBuilder.set_box_spacing(content, 18)
	safe.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var back := UIBuilder.make_button("返回", 120)
	back.pressed.connect(func() -> void: NavigationManager.go_back("start"))
	header.add_child(back)
	var title := UIBuilder.make_title("选择服务器", 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)
	var balance := Control.new()
	balance.custom_minimum_size.x = 120
	header.add_child(balance)
	content.add_child(UIBuilder.make_label("维护中的服务器不可确认。最近登录与推荐状态来自本地 Mock 数据。", 17, UIBuilder.COLOR_MUTED, true))

	var server_row := HBoxContainer.new()
	server_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UIBuilder.set_box_spacing(server_row, 18)
	content.add_child(server_row)
	var group := ButtonGroup.new()
	for server in MockData.get_servers():
		var button := UIBuilder.make_button(_server_text(server))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_group = group
		button.disabled = server["status"] == "维护"
		button.tooltip_text = "维护中的服务器暂不可选择" if button.disabled else "选择 %s" % server["name"]
		button.pressed.connect(_select_server.bind(str(server["id"])))
		server_row.add_child(button)
		_server_buttons[server["id"]] = button

	var footer := HBoxContainer.new()
	UIBuilder.set_box_spacing(footer, 14)
	content.add_child(footer)
	_selection_label = UIBuilder.make_label("", 18, UIBuilder.COLOR_ACCENT)
	_selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selection_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_selection_label)
	_confirm_button = UIBuilder.make_primary_button("确认选择", 220)
	_confirm_button.pressed.connect(_confirm_selection)
	footer.add_child(_confirm_button)


func _server_text(server: Dictionary) -> String:
	var tags: Array[String] = []
	if bool(server.get("recent", false)):
		tags.append("最近登录")
	if bool(server.get("recommended", false)):
		tags.append("推荐")
	var tag_text := "\n" + " · ".join(tags) if not tags.is_empty() else ""
	return "%s\n%s\n状态：%s%s" % [server["id"], server["name"], server["status"], tag_text]


func _select_server(server_id: String) -> void:
	_selected_id = server_id
	_refresh_selection()


func _refresh_selection() -> void:
	for server_id in _server_buttons:
		var button := _server_buttons[server_id] as Button
		button.button_pressed = server_id == _selected_id
	var selected: Dictionary = MockData.servers.get_server(_selected_id)
	_confirm_button.disabled = selected.is_empty() or str(selected.get("status", "维护")) == "维护"
	_selection_label.text = "当前选择：%s %s · %s" % [selected.get("id", "--"), selected.get("name", "未选择"), selected.get("status", "未知")]
	_selection_label.add_theme_color_override("font_color", UIBuilder.status_color(str(selected.get("status", "未知"))))


func _confirm_selection() -> void:
	if not MockData.select_server(_selected_id):
		NavigationManager.show_error("无法选择服务器", "该服务器正在维护，请选择其他服务器。")
		return
	NavigationManager.go_back("start")
