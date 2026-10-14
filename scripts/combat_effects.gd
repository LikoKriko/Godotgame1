extends Node2D
const Style = preload("res://scripts/visual_style.gd")
var game
var flashes: Array[Dictionary] = []
var had_sword := false
var trail: Array[Dictionary] = []
var trail_owner_uid := -1
var trail_layer: Node2D
func _ready() -> void:
	trail_layer = Node2D.new(); add_child(trail_layer); trail_layer.draw.connect(draw_sword_trail)
func flash(point: Vector2, direction: Vector2, parried: bool = false) -> void:
	flashes.append({"point":point,"direction":direction,"left":0.22,"parry":parried})
	queue_redraw()
func advance(delta: float) -> void:
	var dirty := not flashes.is_empty()
	for effect in flashes.duplicate():
		effect.left -= delta
		if effect.left <= 0: flashes.erase(effect)
	var had_trail := not trail.is_empty()
	for sample in trail.duplicate():
		sample.left -= delta
		if sample.left <= 0: trail.erase(sample)
	var sword: bool = game != null and game.working and game.bag.held_category() == &"sword"
	if sword:
		var phase: float = game.work_elapsed/game.work_duration
		var tip: Vector2 = game.full_avatar.held_tip()
		var uid: int = game.bag.held_item().get("uid",-1)
		if uid != trail_owner_uid or phase < 0.18: trail.clear()
		trail_owner_uid = uid
		if phase >= 0.18 and phase <= 0.60 and tip.is_finite():
			if trail.is_empty() or trail.back().point.distance_to(tip) > 0.05: trail.append({"point":tip,"left":0.09})
		trail_layer.z_as_relative = false
		trail_layer.z_index = preload("res://scripts/world_depth.gd").layer(game.player.y+17)+(-1 if sin(game.movement.heading) <= 0 else 1)
	if trail_layer != null and (had_trail or not trail.is_empty() or sword or had_sword): trail_layer.queue_redraw()
	if dirty or sword or had_sword: queue_redraw()
	had_sword = sword
func _draw() -> void:
	if game == null: return
	var width := 1.0/Style.PIXELS_PER_WORLD
	for effect in flashes:
		var alpha: float = effect.left/0.22
		var color := Color(0.83,0.91,0.72,alpha) if effect.parry else Color(0.95,0.85,0.64,alpha)
		var size: float = 3+(1-alpha)*5
		var direction: Vector2 = effect.direction.normalized()
		if direction.is_zero_approx(): direction = Vector2.RIGHT
		for angle in [-1.2,-0.4,0.4,1.2]:
			var axis := direction.rotated(angle)
			draw_line(effect.point+axis*size*0.45,effect.point+axis*size,color,width,false)

func draw_sword_trail() -> void:
	if trail.size() < 2: return
	for i in range(1,trail.size()):
		var alpha: float = minf(trail[i-1].left,trail[i].left)/0.09
		trail_layer.draw_line(trail[i-1].point,trail[i].point,Color(0.90,0.89,0.77,alpha*0.60),1.0/Style.PIXELS_PER_WORLD,false)
