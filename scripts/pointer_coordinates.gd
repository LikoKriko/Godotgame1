extends Node
# Desktop UI uses the visible client pointer, transformed by the same viewport
# final transform as the renderer (including viewport scaling and letterboxing).
# This avoids stale/scaled event positions after changes
# of window mode, resolution or embedding. World aiming retains its own camera.
func _ready() -> void:
	add_to_group("pointer_coordinates")

static func client_to_viewport(viewport: Viewport, screen_point: Vector2, window_origin: Vector2) -> Vector2:
	return viewport.get_final_transform().affine_inverse()*(screen_point-window_origin)

static func viewport_position(viewport: Viewport) -> Vector2:
	if DisplayServer.get_name() not in ["Windows","X11"]: return viewport.get_mouse_position()
	var window := viewport.get_window()
	return client_to_viewport(viewport,Vector2(DisplayServer.mouse_get_position()),Vector2(DisplayServer.window_get_position(window.get_window_id())))

func _input(event: InputEvent) -> void:
	if not event is InputEventMouse or event.device == InputEvent.DEVICE_ID_EMULATION: return
	if DisplayServer.get_name() not in ["Windows","X11"]: return
	var point := viewport_position(get_viewport())
	# Preserve events from outside the client (e.g. releasing a drag off-window).
	if not Rect2(Vector2.ZERO,get_viewport().get_visible_rect().size).has_point(point): return
	if point.distance_to(event.position) > 1.5:
		# GUI dispatch caches its coordinates before _input. Cancel that dispatch
		# and submit a corrected local event, rather than mutating its stale cache.
		var corrected: InputEventMouse = event.duplicate()
		corrected.position = point
		corrected.global_position = point
		get_viewport().set_input_as_handled()
		get_viewport().call_deferred("push_input",corrected,true)
