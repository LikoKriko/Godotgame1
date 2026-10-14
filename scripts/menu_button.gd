extends Button
const Frame = preload("res://scripts/ui_frame.gd")
@export var minimum_left_padding := 0.0
@export var icon_display_width := 0.0
@export var fit_horizontal := Control.SIZE_SHRINK_CENTER
## The visible rectangle is the complete hit area: no expansion or offset.
func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO,size).has_point(point)

func fit_text() -> void:
	if text.is_empty(): return
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	var padding := font.get_height(font_size)*0.15
	for state in ["normal","hover","pressed","disabled","focus"]:
		var style := get_theme_stylebox(state).duplicate()
		for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]: style.set_content_margin(side,padding)
		style.content_margin_left = maxf(padding,minimum_left_padding)
		if style is Frame: style.edge = padding
		add_theme_stylebox_override(state,style)
	var metrics := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	if icon != null:
		var width := minf(icon.get_width(),get_theme_constant("icon_max_width")) if get_theme_constant("icon_max_width") > 0 else float(icon.get_width())
		if icon_display_width > 0: width = icon_display_width
		metrics.x += width+get_theme_constant("h_separation")
		metrics.y = maxf(metrics.y,width*icon.get_height()/icon.get_width())
	custom_minimum_size = metrics+Vector2(maxf(padding,minimum_left_padding)+padding,padding*2)
	size = custom_minimum_size
	size_flags_horizontal = fit_horizontal
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
func _ready() -> void:
	call_deferred("fit_text")
