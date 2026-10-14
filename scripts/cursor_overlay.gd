extends CanvasLayer
## Windows uses the same viewport coordinates for the visible aim and GUI hits.
var native_cursor := false
static func use_native_cursor(platform: String, display: String) -> bool:
	return platform != "Windows" and display != "headless"
func _ready() -> void:
	layer = 4096
	native_cursor = use_native_cursor(OS.get_name(),DisplayServer.get_name())
	if native_cursor:
		var picture: Image = load("res://assets/ui/cursor.png").get_image()
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/cursor.json"))
		var hotspot := Vector2(data.hotspot[0],data.hotspot[1])
		for shape in range(Input.CURSOR_ARROW,Input.CURSOR_HELP+1): Input.set_custom_mouse_cursor(picture,shape,hotspot)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		enable_canvas_cursor()
func enable_canvas_cursor() -> void:
	native_cursor = false
	install_canvas_cursor(get_window())
	if not get_tree().node_added.is_connected(window_added): get_tree().node_added.connect(window_added)
	for node in get_tree().root.find_children("*","Window",true,false): install_canvas_cursor(node)
func window_added(node: Node) -> void:
	if node is Window: install_canvas_cursor.call_deferred(node)
func install_canvas_cursor(window: Window) -> void:
	if not is_instance_valid(window) or window.has_meta("day_zero_canvas_cursor"): return
	window.set_meta("day_zero_canvas_cursor",true)
	var overlay := CanvasLayer.new(); overlay.layer = 4096; window.add_child(overlay)
	overlay.add_child(preload("res://scripts/aim_cursor.gd").new())
func _exit_tree() -> void:
	if native_cursor:
		for shape in range(Input.CURSOR_ARROW,Input.CURSOR_HELP+1): Input.set_custom_mouse_cursor(null,shape)
