extends SceneTree
const Pointer = preload("res://scripts/pointer_coordinates.gd")
var failures := 0
var checks := 0
class CursorGame:
	extends RefCounted
	var focused := Vector2i.ZERO
	var resources := {"nodes":{}}
	func is_paused() -> bool: return false
func _initialize() -> void: call_deferred("run")
func require(value: bool,message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func settle() -> void:
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	if DisplayServer.get_name() != "X11": quit(1); return
	var layer := CanvasLayer.new(); root.add_child(layer)
	var cursor = preload("res://scripts/aim_cursor.gd").new()
	cursor.game = CursorGame.new(); layer.add_child(cursor)
	var camera := Camera2D.new(); camera.position = Vector2(107,-63); camera.zoom = Vector2(1.3,1.3); root.add_child(camera)
	for mode in [Window.CONTENT_SCALE_MODE_VIEWPORT,Window.CONTENT_SCALE_MODE_CANVAS_ITEMS]:
		for dimensions in [Vector2i(1280,720),Vector2i(1600,1000)]:
			root.size = dimensions; root.position = Vector2i(23,17)
			root.content_scale_mode = mode; root.content_scale_size = Vector2i(1920,1080)
			root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
			await settle()
			# Deliberately transform the cursor's CanvasLayer to catch local/viewport confusion.
			layer.transform = Transform2D(0,Vector2(1.07,1.07),0,Vector2(11,9))
			for fraction in [Vector2(0.1,0.1),Vector2(0.5,0.5),Vector2(0.9,0.9)]:
				var target: Vector2 = root.get_visible_rect().size*fraction
				var client: Vector2 = root.get_final_transform()*target
				var screen: Vector2 = client+Vector2(root.position)
				var args := PackedStringArray([ProjectSettings.globalize_path("res://tests/native_pointer.py"),str(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)),str(roundi(screen.x)),str(roundi(screen.y))])
				require(OS.execute("python3",args) == 0,"Native movement delivered")
				await settle()
				var actual := Pointer.viewport_position(root)
				require(actual.distance_to(target) <= 1.6,"Pointer agrees with native rendered position: requested=%s actual=%s" % [target,actual])
				var image := root.get_texture().get_image()
				# The captured canvas excludes native-window letterbox bars.
				var pixel := Vector2i(client-root.get_final_transform().origin)
				# Viewport mode captures logical pixels; canvas-items captures physical pixels.
				if mode == Window.CONTENT_SCALE_MODE_VIEWPORT: pixel = Vector2i(target)
				var found := false
				for y in range(pixel.y-2,pixel.y+3):
					for x in range(pixel.x-2,pixel.x+3):
						if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
							var color := image.get_pixel(x,y)
							if color.r > 0.8 and color.g > 0.8: found = true
				require(found,"The visible dot is centered at the native mouse, including layer scaling and letterboxing")
	print("%s: %d cursor alignment checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(1 if failures else 0)
