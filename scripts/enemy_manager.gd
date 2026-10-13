extends RefCounted
const Enemy = preload("res://scripts/enemy.gd")
const Parry = preload("res://scripts/parry.gd")
const NAV_STEP := 32.0
var game
var enemy
var defeated := false
var parry = Parry.new()
var navigation := AStarGrid2D.new()
var navigation_revision := -1
var path := PackedVector2Array()
var path_goal := Vector2.INF
var path_updated := -1.0
func configure(owner_game) -> void: game = owner_game
func reset() -> void:
	if is_instance_valid(enemy): enemy.free()
	enemy = null; defeated = false; parry.reset()
	navigation_revision = -1; path.clear(); path_goal = Vector2.INF
	if not Enemy.artwork_ready(): return
	enemy = Enemy.new(); game.add_child(enemy); enemy.configure(game,self)
	var best := Vector2.ZERO
	var score := INF
	for cell in game.world.reachable:
		var point: Vector2 = game.world.center(cell)
		if point.distance_to(Vector2.ZERO) < 280 or not game.world.walkable(point,9): continue
		var distance: float = point.distance_squared_to(Vector2(360,0))
		if distance < score: score = distance; best = point
	enemy.position = best; enemy.update_sprite()
func activate_parry() -> bool:
	if game.progression.health <= 0 or not parry.activate(): return false
	game.combat_effects.flash(game.player+Vector2(0,-22),Vector2.from_angle(game.movement.heading),true)
	game.feedback = "Parry · recupera en 4 s"; game.feedback_time = 1
	return true
func advance(delta: float) -> void:
	var steps := maxi(1,ceili(delta/0.05))
	var step := maxf(delta,0)/steps
	for i in steps:
		for hit in parry.advance(step): game.take_damage(hit.damage)
		if is_instance_valid(enemy): enemy.advance(step)
	if is_instance_valid(enemy): enemy.update_sprite()
func refresh_navigation() -> void:
	if navigation_revision == game.world.navigation_revision: return
	var bounds: Rect2 = game.world.bounds
	navigation.region = Rect2i(Vector2i(bounds.position/NAV_STEP),Vector2i(bounds.size/NAV_STEP))
	navigation.cell_size = Vector2.ONE*NAV_STEP; navigation.offset = Vector2.ONE*NAV_STEP/2
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	for y in range(navigation.region.position.y,navigation.region.end.y):
		for x in range(navigation.region.position.x,navigation.region.end.x):
			var cell := Vector2i(x,y)
			navigation.set_point_solid(cell,not game.world.walkable(navigation.get_point_position(cell),9))
	navigation_revision = game.world.navigation_revision; path.clear(); path_goal = Vector2.INF
func closest_cell(point: Vector2) -> Vector2i:
	var center := Vector2i(floori(point.x/NAV_STEP),floori(point.y/NAV_STEP))
	var nearest := Vector2i(99999,99999)
	var best := INF
	for y in range(center.y-2,center.y+3):
		for x in range(center.x-2,center.x+3):
			var cell := Vector2i(x,y)
			if not navigation.region.has_point(cell) or navigation.is_point_solid(cell): continue
			var distance := point.distance_squared_to(navigation.get_point_position(cell))
			if distance < best: best = distance; nearest = cell
	return nearest
func chase_direction(origin: Vector2, target: Vector2) -> Vector2:
	if game.clear_combat_path(origin): return origin.direction_to(target)
	refresh_navigation()
	if path.is_empty() or target.distance_to(path_goal) > 24 or parry.time-path_updated > 0.25:
		var first := closest_cell(origin); var last := closest_cell(target)
		if first == Vector2i(99999,99999) or last == Vector2i(99999,99999): return Vector2.ZERO
		path = navigation.get_point_path(first,last); path_goal = target; path_updated = parry.time
	while not path.is_empty() and origin.distance_to(path[0]) < 8: path.remove_at(0)
	return origin.direction_to(path[0]) if not path.is_empty() else Vector2.ZERO

func capture_state() -> Dictionary:
	var creature := {}
	if is_instance_valid(enemy) and not defeated and enemy.health > 0:
		for key in ["position","heading","health","attack_elapsed","impact_done","punch_left","stun_remaining","walk_phase","state","standing","entering_attack","lower_elapsed"]: creature[key] = enemy.get(key)
	var hits := []
	for hit in parry.pending: hits.append({"damage":hit.damage,"impact":hit.impact})
	return {"defeated":defeated,"enemy":creature,"time":parry.time,"last_activation":parry.last_activation,"used":parry.used,"pending":hits}

static func valid_state(data) -> bool:
	if not data is Dictionary: return false
	if data.is_empty(): return true # A save from before combat was introduced.
	for key in ["defeated","used"]:
		if not data.get(key) is bool: return false
	for key in ["time","last_activation"]:
		if not (data.get(key) is float or data.get(key) is int) or not is_finite(float(data[key])): return false
	if data.time < 0 or data.last_activation < -4 or data.last_activation > data.time: return false
	if not data.get("pending") is Array or data.pending.size() > 1 or not data.get("enemy") is Dictionary: return false
	for hit in data.pending:
		if not hit is Dictionary or hit.get("damage") != Enemy.DAMAGE or not (hit.get("impact") is float or hit.get("impact") is int): return false
		if not is_finite(float(hit.impact)) or hit.impact < 0 or hit.impact > data.time or data.time-hit.impact > Parry.DAMAGE_DELAY: return false
	var creature: Dictionary = data.enemy
	if data.defeated: return creature.is_empty()
	if creature.is_empty(): return true
	if not creature.get("position") is Vector2 or not creature.position.is_finite(): return false
	for key in ["heading","health","attack_elapsed","stun_remaining","walk_phase"]:
		if not (creature.get(key) is float or creature.get(key) is int) or not is_finite(float(creature[key])): return false
	if creature.health <= 0 or creature.health > Enemy.MAX_HEALTH or creature.attack_elapsed < -1 or creature.attack_elapsed >= Enemy.ATTACK_PERIOD: return false
	if creature.stun_remaining < 0 or creature.stun_remaining > Parry.STUN_SECONDS or creature.walk_phase < 0 or creature.walk_phase >= 1: return false
	if not creature.get("impact_done") is bool or not creature.get("punch_left") is bool: return false
	if creature.has("standing") and not creature.standing is bool: return false
	if creature.has("entering_attack") and not creature.entering_attack is bool: return false
	if creature.has("lower_elapsed") and (not creature.lower_elapsed is float or not is_finite(creature.lower_elapsed) or creature.lower_elapsed < -1 or creature.lower_elapsed > 0.18): return false
	return creature.get("state") in [&"idle",&"walk",&"attack"]

func restore_state(data: Dictionary) -> void:
	if data.is_empty(): return
	defeated = data.defeated
	if defeated and is_instance_valid(enemy): enemy.free(); enemy = null
	if is_instance_valid(enemy) and not data.enemy.is_empty():
		for key in data.enemy: enemy.set(key,data.enemy[key])
		if not data.enemy.has("standing"): enemy.standing = enemy.state == &"attack"
		enemy.update_sprite()
	parry.time = data.time; parry.last_activation = data.last_activation; parry.used = data.used; parry.pending.clear()
	for hit in data.pending: parry.pending.append({"attacker":enemy,"damage":hit.damage,"impact":hit.impact})
