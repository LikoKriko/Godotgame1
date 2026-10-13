extends RefCounted
# Use the engine's client coordinates. Desktop coordinates minus a window origin
# are not client coordinates on decorated Windows windows, and applying the
# render transform a second time offsets the pointer when the viewport scales.
static func viewport_position(viewport: Viewport) -> Vector2:
	return viewport.get_mouse_position()
