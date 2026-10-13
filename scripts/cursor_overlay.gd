extends CanvasLayer
## Native cursor follows the OS pointer in every game window and popup.
var native_cursor := false
func _ready() -> void:
	layer = 4096
	native_cursor = DisplayServer.get_name() != "headless"
	if native_cursor:
		var picture: Image = load("res://assets/ui/cursor.png").get_image()
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/cursor.json"))
		var hotspot := Vector2(data.hotspot[0],data.hotspot[1])
		for shape in range(Input.CURSOR_ARROW,Input.CURSOR_HELP+1): Input.set_custom_mouse_cursor(picture,shape,hotspot)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		add_child(preload("res://scripts/aim_cursor.gd").new())
func _exit_tree() -> void:
	if native_cursor:
		for shape in range(Input.CURSOR_ARROW,Input.CURSOR_HELP+1): Input.set_custom_mouse_cursor(null,shape)
