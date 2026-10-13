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
	# Drawing happens in this Control's local space, not viewport or world space.
	var point := get_global_transform_with_canvas().affine_inverse()*preload("res://scripts/pointer_coordinates.gd").viewport_position(get_viewport())
	var tint := Color("ebe7d5")
	if game.resources.nodes.has(game.focused):
		tint = Color("c6d5a3") if game.resources.can_reach(game.focused,game.player) else Color("bca092")
	draw_circle(point, 3, Color(0.05, 0.06, 0.05, 0.7))
	draw_circle(point, 1.7, tint)
