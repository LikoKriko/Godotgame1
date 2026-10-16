extends Control
## Draw the same unobtrusive white point at the camera ray's exact viewport
## center. A font glyph has asymmetric metrics/minimum size and can drift.
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 resized.connect(queue_redraw)
func _draw() -> void:
 draw_circle(size*.5,1.5,Color.WHITE)
