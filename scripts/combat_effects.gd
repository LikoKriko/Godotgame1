extends Node2D
const Style = preload("res://scripts/visual_style.gd")
var game
var flashes: Array[Dictionary] = []
var had_sword := false
func flash(point: Vector2, direction: Vector2, parried: bool = false) -> void:
	flashes.append({"point":point,"direction":direction,"left":0.22,"parry":parried})
	queue_redraw()
func advance(delta: float) -> void:
	var dirty := not flashes.is_empty()
	for effect in flashes.duplicate():
		effect.left -= delta
		if effect.left <= 0: flashes.erase(effect)
	var sword: bool = game != null and game.working and game.bag.held_category() == &"sword"
	if dirty or sword or had_sword: queue_redraw()
	had_sword = sword
func _draw() -> void:
	if game == null: return
	var width := 1.0/Style.PIXELS_PER_WORLD
	if game.working and game.bag.held_category() == &"sword":
		var phase: float = game.work_elapsed/game.work_duration
		if phase >= 0.18 and phase <= 0.60:
			var center: Vector2 = game.player+Vector2(0,-25)
			var angle: float = game.movement.heading
			var progress := clampf((phase-0.18)/0.32,0,1)
			var end := angle-0.75+progress*1.5
			var arc := PackedVector2Array()
			for i in 8: arc.append(center+Vector2.from_angle(end-0.40+i*0.40/7)*28)
			draw_polyline(arc,Color(0.90,0.89,0.77,0.65*(1-smoothstep(0.50,0.60,phase))),width,false)
	for effect in flashes:
		var alpha: float = effect.left/0.22
		var color := Color(0.83,0.91,0.72,alpha) if effect.parry else Color(0.95,0.85,0.64,alpha)
		var size: float = 3+(1-alpha)*5
		var direction: Vector2 = effect.direction.normalized()
		if direction.is_zero_approx(): direction = Vector2.RIGHT
		for angle in [-1.2,-0.4,0.4,1.2]:
			var axis := direction.rotated(angle)
			draw_line(effect.point+axis*size*0.45,effect.point+axis*size,color,width,false)
