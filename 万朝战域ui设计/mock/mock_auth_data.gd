class_name MockAuthData
extends RefCounted

var is_logged_in: bool = false
var is_guest: bool = false
var display_name: String = ""
var remembered_account: String = ""


func login(account: String, remember_account: bool, guest: bool = false) -> bool:
	if not guest and account.strip_edges().is_empty():
		return false
	is_logged_in = true
	is_guest = guest
	display_name = "游客执棋者" if guest else account.strip_edges()
	remembered_account = account.strip_edges() if remember_account and not guest else ""
	return true


func logout() -> void:
	is_logged_in = false
	is_guest = false
	display_name = ""
