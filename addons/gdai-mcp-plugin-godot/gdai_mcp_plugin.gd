@tool
extends EditorPlugin


func _enter_tree():
	add_autoload_singleton("GDAIMCPRuntime", "res://addons/gdai-mcp-plugin-godot/gdai_mcp_runtime.gd")


func _exit_tree():
	remove_autoload_singleton("GDAIMCPRuntime")
