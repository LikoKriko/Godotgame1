extends Node2D
const Effects = preload("res://scripts/status_effects.gd")
const Style = preload("res://scripts/visual_style.gd")
const DIAMETER := 10.0
const GAP := 3.0
var effects
func configure(states) -> void:
	effects = states
	z_index = 3
func refresh(top: Vector2) -> void:
	position = top-Vector2(0,GAP+DIAMETER/2)
	visible = effects != null and not effects.active.is_empty()
	queue_redraw()
func _draw() -> void:
	if effects == null: return
	var offset := 0.0
	for id in effects.active:
		var center := Vector2(offset,0)
		var amount: float = effects.fraction(id)
		var radius := DIAMETER/2
		draw_circle(center,radius,Color(0.12,0.13,0.12,0.18))
		if amount >= 0.999999:
			draw_circle(center,radius,Effects.DEFINITIONS[id].color)
			draw_arc(center,radius,0,TAU,64,Color("252723"),1.0/Style.PIXELS_PER_WORLD,false)
			offset += DIAMETER+3
			continue
		var points := PackedVector2Array([center])
		var steps := maxi(2,ceili(64*amount))
		for step in steps+1:
			var angle := -PI/2+TAU*(1.0-amount+amount*step/steps)
			points.append(center+Vector2.from_angle(angle)*radius)
		draw_colored_polygon(points,Effects.DEFINITIONS[id].color)
		draw_arc(center,radius,0,TAU,64,Color("252723"),1.0/Style.PIXELS_PER_WORLD,false)
		offset += DIAMETER+3
