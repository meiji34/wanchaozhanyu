extends Control

const RESOURCE_BAR_SCENE := preload("res://ui/components/resource_bar.tscn")
const TASK_PANEL_SCENE := preload("res://ui/components/task_panel.tscn")

var _resource_bar: ResourceBar
var _task_panel: TaskPanel


func _ready() -> void:
	_build_ui()
	_resource_bar.set_resources(MockData.get_resources())
	_task_panel.set_tasks(MockData.get_tasks())


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("11100f")
	add_child(background)
	var safe := SafeAreaContainer.new()
	safe.minimum_safe_padding = 18
	add_child(safe)
	var root_box := VBoxContainer.new()
	root_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UIBuilder.set_box_spacing(root_box, 12)
	safe.add_child(root_box)
	var header := HBoxContainer.new()
	root_box.add_child(header)
	var back := UIBuilder.make_button("返回 HUD", 150)
	back.pressed.connect(func() -> void: NavigationManager.go_back("main_hud"))
	header.add_child(back)
	var title := UIBuilder.make_title("UI 组件演示", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)
	var balance := Control.new()
	balance.custom_minimum_size.x = 150
	header.add_child(balance)

	_resource_bar = RESOURCE_BAR_SCENE.instantiate() as ResourceBar
	_resource_bar.show_demo_controls = true
	_resource_bar.demo_update_requested.connect(_demo_resources)
	_resource_bar.more_status_requested.connect(func() -> void: NavigationManager.show_message("组件状态", "更多状态面板已在 HUD 中实现。"))
	root_box.add_child(_resource_bar)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UIBuilder.set_box_spacing(columns, 14)
	root_box.add_child(columns)
	_task_panel = TASK_PANEL_SCENE.instantiate() as TaskPanel
	_task_panel.show_demo_controls = true
	_task_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_task_panel.tracking_toggled.connect(_toggle_tracking)
	_task_panel.demo_advance_requested.connect(_advance_task)
	_task_panel.task_details_requested.connect(func(task: Dictionary) -> void: NavigationManager.show_message(str(task.get("title", "任务")), str(task.get("description", ""))))
	columns.add_child(_task_panel)

	var states := UIBuilder.make_panel()
	states.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(states)
	var state_box := VBoxContainer.new()
	UIBuilder.set_box_spacing(state_box, 12)
	states.add_child(state_box)
	state_box.add_child(UIBuilder.make_label("按钮与弹窗状态", 22, UIBuilder.COLOR_ACCENT))
	state_box.add_child(UIBuilder.make_primary_button("主要按钮"))
	state_box.add_child(UIBuilder.make_button("普通按钮"))
	var selected := UIBuilder.make_button("选中按钮")
	selected.toggle_mode = true
	selected.button_pressed = true
	state_box.add_child(selected)
	var disabled := UIBuilder.make_button("禁用按钮")
	disabled.disabled = true
	state_box.add_child(disabled)
	var dialog_row := HBoxContainer.new()
	UIBuilder.set_box_spacing(dialog_row, 8)
	state_box.add_child(dialog_row)
	var confirm := UIBuilder.make_button("确认弹窗")
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.pressed.connect(func() -> void: NavigationManager.show_confirm("确认弹窗", "用于验证确认和取消信号。", func() -> void: NavigationManager.show_message("已确认", "确认信号已收到。")))
	dialog_row.add_child(confirm)
	var error := UIBuilder.make_danger_button("错误弹窗")
	error.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	error.pressed.connect(func() -> void: NavigationManager.show_error("演示错误", "这是可恢复的通用错误弹窗。"))
	dialog_row.add_child(error)
	var loading := UIBuilder.make_button("加载遮罩")
	loading.pressed.connect(_demo_loading)
	state_box.add_child(loading)


func _demo_resources() -> void:
	MockData.apply_demo_resource_update()
	_resource_bar.set_resources(MockData.get_resources())


func _toggle_tracking(task_id: String) -> void:
	MockData.toggle_task_tracking(task_id)
	_task_panel.set_tasks(MockData.get_tasks())


func _advance_task() -> void:
	MockData.advance_demo_task()
	_task_panel.set_tasks(MockData.get_tasks())


func _demo_loading() -> void:
	NavigationManager.show_loading_overlay("正在验证加载遮罩…")
	await get_tree().create_timer(0.9).timeout
	NavigationManager.hide_loading_overlay()
