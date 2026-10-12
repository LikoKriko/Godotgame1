extends Control
var game
var clock: Label
var nutrition_label: Label
var hydration: ProgressBar
var hydration_label: Label
func configure(owner_game) -> void:
	game = owner_game
	custom_minimum_size = Vector2(330,190)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.show_behind_parent = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09,0.115,0.12,0.90)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	clock = make_label(Vector2(14,10),20)
	nutrition_label = make_label(Vector2(14,70),16)
	hydration_label = make_label(Vector2(14,125),16)
	hydration = ProgressBar.new()
	hydration.position = Vector2(14,156)
	hydration.size = Vector2(302,14)
	hydration.max_value = 2000
	hydration.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("719baa")
	fill.set_corner_radius_all(4)
	hydration.add_theme_stylebox_override("fill",fill)
	hydration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hydration)
	update_status()
func make_label(point: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = point
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",font_size)
	add_child(label)
	return label
func update_status() -> void:
	clock.text = game.day_cycle.clock_text()
	nutrition_label.text = "60 kg · %d / 1600 kcal hoy\nVelocidad: −%d%%" % [game.nutrition.calories_today,roundi(game.nutrition.speed_penalty()*100)]
	hydration_label.text = "Hidratación: %d / 2000 ml" % roundi(game.nutrition.hydration_ml)
	hydration.value = game.nutrition.hydration_ml
	queue_redraw()
func _draw() -> void:
	var state: Dictionary = game.day_cycle.sun_state()
	var points := PackedVector2Array()
	for i in 33:
		var t := i/32.0
		points.append(Vector2(30+270*t,58-sin(t*PI)*22))
	draw_polyline(points,Color(0.55,0.59,0.53,0.4),1)
	if state["visible"]:
		var t: float = state["progress"]
		var point := Vector2(30+270*t,58-sin(t*PI)*22)
		draw_circle(point,6,Color(1,0.82,0.42))
	else:
		draw_circle(Vector2(165,40),5,Color(0.63,0.71,0.85))
