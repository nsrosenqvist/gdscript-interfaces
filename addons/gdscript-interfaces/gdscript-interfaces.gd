@tool
extends EditorPlugin

const AUTOLOAD_NAME = "Interfaces"

func _enter_tree() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, "res://addons/gdscript-interfaces/Interfaces.gd")


func _exit_tree() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
