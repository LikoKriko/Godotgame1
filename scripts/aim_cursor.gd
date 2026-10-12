extends Control
var game

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	var menu: bool = game.is_paused()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if menu else Input.MOUSE_MODE_HIDDEN
	queue_redraw()

func _draw() -> void:
	if game.is_paused():
		return
	var point := get_viewport().get_mouse_position()
	var tint := Color("ebe7d5")
	if game.resources.nodes.has(game.focused):
		var pose := preload("res://scripts/arm_rig.gd").contact(game.player, game.get_global_mouse_position(), game.bag.held_id())
		tint = Color("c6d5a3") if pose["reachable"] else Color("bca092")
	draw_circle(point, 3, Color(0.05, 0.06, 0.05, 0.7))
	draw_circle(point, 1.7, tint)
