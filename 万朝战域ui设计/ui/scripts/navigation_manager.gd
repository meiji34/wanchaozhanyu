extends Node

const ROUTES: Dictionary = {
	"login": "res://ui/screens/login_screen.tscn",
	"loading": "res://ui/screens/loading_screen.tscn",
	"start": "res://ui/screens/start_screen.tscn",
	"server_select": "res://ui/screens/server_select_screen.tscn",
	"main_hud": "res://ui/hud/main_hud.tscn",
	"settings": "res://ui/placeholders/settings_placeholder_screen.tscn",
	"city": "res://ui/placeholders/city_placeholder_screen.tscn",
	"generals": "res://ui/placeholders/generals_placeholder_screen.tscn",
	"alliance": "res://ui/placeholders/alliance_placeholder_screen.tscn",
	"route": "res://ui/placeholders/route_placeholder_screen.tscn",
	"battle": "res://ui/placeholders/battle_placeholder_screen.tscn",
	"npc": "res://ui/placeholders/npc_placeholder_screen.tscn",
	"world_event": "res://ui/placeholders/world_event_placeholder_screen.tscn",
	"season": "res://ui/placeholders/season_placeholder_screen.tscn",
	"exile": "res://ui/placeholders/exile_placeholder_screen.tscn",
	"revival": "res://ui/placeholders/revival_placeholder_screen.tscn",
	"counterattack": "res://ui/placeholders/counterattack_placeholder_screen.tscn",
	"ui_demo": "res://ui/screens/ui_demo_screen.tscn",
}

const CONFIRM_DIALOG_PATH := "res://ui/dialogs/confirm_dialog.tscn"
const MESSAGE_DIALOG_PATH := "res://ui/dialogs/message_dialog.tscn"
const ERROR_DIALOG_PATH := "res://ui/dialogs/error_dialog.tscn"
const LOADING_OVERLAY_PATH := "res://ui/dialogs/loading_overlay.tscn"

var _screen_layer: Control
var _dialog_layer: Control
var _overlay_layer: Control
var _current_route: String = ""
var _current_params: Dictionary = {}
var _history: Array[Dictionary] = []


func register_layers(screen_layer: Control, dialog_layer: Control, overlay_layer: Control) -> void:
	_screen_layer = screen_layer
	_dialog_layer = dialog_layer
	_overlay_layer = overlay_layer


func replace_screen(route: String, params: Dictionary = {}, clear_history: bool = false) -> void:
	if clear_history:
		_history.clear()
	_navigate(route, params)


func open_screen(route: String, params: Dictionary = {}) -> void:
	if route == _current_route:
		return
	if not _current_route.is_empty():
		_history.append({"route": _current_route, "params": _current_params.duplicate(true)})
	_navigate(route, params)


func go_back(fallback_route: String = "main_hud") -> void:
	if _history.is_empty():
		_navigate(fallback_route, {})
		return
	var previous: Dictionary = _history.pop_back()
	_navigate(previous["route"], previous.get("params", {}))


func _navigate(route: String, params: Dictionary) -> void:
	if _screen_layer == null:
		push_error("导航层尚未注册。")
		return
	var path: String = ROUTES.get(route, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		show_message("功能暂不可用", "目标页面缺失，已保留当前页面。")
		return
	var packed := load(path) as PackedScene
	if packed == null:
		show_error("页面加载失败", "无法读取目标页面：%s" % route)
		return
	_clear_layer(_screen_layer)
	var next_screen := packed.instantiate()
	_screen_layer.add_child(next_screen)
	_current_route = route
	_current_params = params.duplicate(true)
	if next_screen.has_method("configure"):
		next_screen.call("configure", params)


func show_confirm(
	title: String,
	message: String,
	on_confirm: Callable,
	on_cancel: Callable = Callable(),
	confirm_text: String = "确认",
	cancel_text: String = "取消"
) -> void:
	if _dialog_layer == null or _dialog_layer.get_child_count() > 0:
		return
	var dialog := _instantiate_scene(CONFIRM_DIALOG_PATH)
	if dialog == null:
		return
	_dialog_layer.add_child(dialog)
	dialog.call("configure", title, message, confirm_text, cancel_text)
	dialog.connect("confirmed", _on_confirmed.bind(dialog, on_confirm), CONNECT_ONE_SHOT)
	dialog.connect("cancelled", _on_cancelled.bind(dialog, on_cancel), CONNECT_ONE_SHOT)


func show_message(title: String, message: String, button_text: String = "知道了") -> void:
	_show_notice(MESSAGE_DIALOG_PATH, title, message, button_text)


func show_error(title: String, message: String, button_text: String = "返回") -> void:
	_show_notice(ERROR_DIALOG_PATH, title, message, button_text)


func _show_notice(path: String, title: String, message: String, button_text: String) -> void:
	if _dialog_layer == null or _dialog_layer.get_child_count() > 0:
		return
	var dialog := _instantiate_scene(path)
	if dialog == null:
		return
	_dialog_layer.add_child(dialog)
	dialog.call("configure", title, message, button_text)
	dialog.connect("closed", _on_notice_closed.bind(dialog), CONNECT_ONE_SHOT)


func show_loading_overlay(message: String = "处理中…") -> void:
	if _overlay_layer == null or _overlay_layer.get_child_count() > 0:
		return
	var overlay := _instantiate_scene(LOADING_OVERLAY_PATH)
	if overlay == null:
		return
	_overlay_layer.add_child(overlay)
	overlay.call("configure", message)


func hide_loading_overlay() -> void:
	if _overlay_layer != null:
		_clear_layer(_overlay_layer)


func _instantiate_scene(path: String) -> Node:
	if not ResourceLoader.exists(path):
		push_warning("可选 UI 资源缺失：%s" % path)
		return null
	var packed := load(path) as PackedScene
	return packed.instantiate() if packed != null else null


func _on_confirmed(dialog: Node, callback: Callable) -> void:
	if is_instance_valid(dialog):
		dialog.queue_free()
	if callback.is_valid():
		callback.call()


func _on_cancelled(dialog: Node, callback: Callable) -> void:
	if is_instance_valid(dialog):
		dialog.queue_free()
	if callback.is_valid():
		callback.call()


func _on_notice_closed(dialog: Node) -> void:
	if is_instance_valid(dialog):
		dialog.queue_free()


func _clear_layer(layer: Node) -> void:
	for child in layer.get_children():
		child.queue_free()
