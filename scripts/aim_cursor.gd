extends Control
var game
var cursor: Texture2D
var hotspot := Vector2.ZERO
func _ready() -> void:
	# This canvas cursor must never capture GUI input or inherit the camera.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cursor = load("res://assets/ui/cursor.png")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/cursor.json"))
	hotspot = Vector2(data.hotspot[0],data.hotspot[1])
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
func _process(_delta: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	queue_redraw()
func _draw() -> void:
	if cursor == null: return
	if DisplayServer.get_name() != "headless" and not get_window().has_focus(): return
	var point := preload("res://scripts/pointer_coordinates.gd").viewport_position(get_viewport())
	if not get_viewport().get_visible_rect().has_point(point): return
	# Cancel any inherited canvas transform so cursor size and hotspot are
	# measured in viewport pixels, independently of camera/HUD scaling.
	draw_set_transform_matrix(get_global_transform_with_canvas().affine_inverse())
	var physical_scale := get_viewport().get_final_transform().get_scale().abs()
	physical_scale = physical_scale.max(Vector2(0.001,0.001))
	draw_texture_rect(cursor,Rect2(point-hotspot/physical_scale,cursor.get_size()/physical_scale),false)
