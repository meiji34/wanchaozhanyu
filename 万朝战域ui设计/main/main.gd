extends Control

@onready var screen_layer: Control = %ScreenLayer
@onready var dialog_layer: Control = %DialogLayer
@onready var overlay_layer: Control = %OverlayLayer


func _ready() -> void:
	NavigationManager.register_layers(screen_layer, dialog_layer, overlay_layer)
	NavigationManager.call_deferred("replace_screen", "login", {}, true)
