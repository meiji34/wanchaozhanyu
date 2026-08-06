extends Control

var _account_input: LineEdit
var _password_input: LineEdit
var _remember_check: CheckBox
var _error_label: Label
var _login_button: Button
var _guest_button: Button


func _ready() -> void:
	_build_ui()
	_account_input.text = MockData.get_remembered_account()
	_remember_check.button_pressed = not _account_input.text.is_empty()
	_account_input.grab_focus()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("0e0d0c")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var safe := SafeAreaContainer.new()
	add_child(safe)
	var layout := HBoxContainer.new()
	UIBuilder.set_box_spacing(layout, 56)
	safe.add_child(layout)

	var intro := VBoxContainer.new()
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro.alignment = BoxContainer.ALIGNMENT_CENTER
	UIBuilder.set_box_spacing(intro, 18)
	layout.add_child(intro)
	var eyebrow := UIBuilder.make_label("三国沙盘策略 · UI 演示", 18, UIBuilder.COLOR_ACCENT)
	intro.add_child(eyebrow)
	var title := UIBuilder.make_title("万朝战域", 54)
	intro.add_child(title)
	var subtitle := UIBuilder.make_label(
		"执天命，观万朝。登录后可体验选服、资源、任务、地图占位与页面导航流程。",
		21,
		UIBuilder.COLOR_MUTED,
		true
	)
	subtitle.custom_minimum_size.x = 460
	intro.add_child(subtitle)
	var note := UIBuilder.make_label("当前为本地 Mock 登录，不连接真实账号与服务器。", 16, UIBuilder.COLOR_INFO, true)
	intro.add_child(note)

	var panel := UIBuilder.make_panel()
	panel.custom_minimum_size = Vector2(590, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	layout.add_child(panel)
	var form := VBoxContainer.new()
	UIBuilder.set_box_spacing(form, 14)
	panel.add_child(form)
	form.add_child(UIBuilder.make_title("登录军府", 28))
	form.add_child(UIBuilder.make_label("输入任意非空账号与密码即可进入演示。", 17, UIBuilder.COLOR_MUTED, true))

	_account_input = LineEdit.new()
	_account_input.placeholder_text = "账号"
	_account_input.custom_minimum_size.y = 60
	_account_input.text_submitted.connect(func(_value: String) -> void: _password_input.grab_focus())
	form.add_child(_account_input)
	_password_input = LineEdit.new()
	_password_input.placeholder_text = "密码"
	_password_input.secret = true
	_password_input.custom_minimum_size.y = 60
	_password_input.text_submitted.connect(func(_value: String) -> void: _submit_login())
	form.add_child(_password_input)

	_remember_check = CheckBox.new()
	_remember_check.text = "记住账号（不会保存密码）"
	_remember_check.custom_minimum_size.y = 48
	form.add_child(_remember_check)
	_error_label = UIBuilder.make_label("", 16, UIBuilder.COLOR_ERROR, true)
	_error_label.visible = false
	form.add_child(_error_label)

	_login_button = UIBuilder.make_primary_button("登录并进入", 0)
	_login_button.pressed.connect(_submit_login)
	form.add_child(_login_button)
	_guest_button = UIBuilder.make_button("游客登录", 0)
	_guest_button.pressed.connect(_submit_guest_login)
	form.add_child(_guest_button)

	var legal := HBoxContainer.new()
	legal.alignment = BoxContainer.ALIGNMENT_CENTER
	UIBuilder.set_box_spacing(legal, 10)
	form.add_child(legal)
	var agreement := UIBuilder.make_button("用户协议", 120)
	agreement.custom_minimum_size.y = 46
	agreement.pressed.connect(func() -> void: NavigationManager.show_message("用户协议", "演示阶段仅展示协议入口，正式内容后续接入。"))
	legal.add_child(agreement)
	var privacy := UIBuilder.make_button("隐私政策", 120)
	privacy.custom_minimum_size.y = 46
	privacy.pressed.connect(func() -> void: NavigationManager.show_message("隐私政策", "演示阶段不采集、不上传账号或设备数据。"))
	legal.add_child(privacy)


func _submit_login() -> void:
	_error_label.visible = false
	if not MockData.login(_account_input.text, _password_input.text, _remember_check.button_pressed):
		_error_label.text = "请输入完整的账号与密码。"
		_error_label.visible = true
		NavigationManager.show_error("登录信息不完整", "账号和密码均不能为空，请检查后重试。")
		return
	await _show_login_state("正在验证本地 Mock 账号…")
	NavigationManager.replace_screen("loading", {"target": "start", "message": "正在进入军府"}, true)


func _submit_guest_login() -> void:
	MockData.guest_login()
	await _show_login_state("正在创建游客身份…")
	NavigationManager.replace_screen("loading", {"target": "start", "message": "正在进入军府"}, true)


func _show_login_state(message: String) -> void:
	_login_button.disabled = true
	_guest_button.disabled = true
	NavigationManager.show_loading_overlay(message)
	await get_tree().create_timer(0.35).timeout
	NavigationManager.hide_loading_overlay()

