extends RefCounted
const Enemy = preload("res://scripts/enemy.gd")
const Parry = preload("res://scripts/parry.gd")
const NAV_STEP := 32.0
var game
var enemy
var defeated := false
var additional: Array = []
var parry = Parry.new()
var navigation := AStarGrid2D.new()
var navigation_revision := -1
var path := PackedVector2Array()
var path_goal := Vector2.INF
var path_updated := -1.0
func configure(owner_game) -> void: game = owner_game
func reset() -> void:
	for child in additional:
		if is_instance_valid(child.enemy): child.enemy.free()
	additional.clear()
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
	for child in additional: child.parry.activate()
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
	for child in additional: child.advance(delta)
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
	var clear := true
	for step in range(1,maxi(1,ceili(origin.distance_to(target)/8))):
		if not game.world.walkable(origin.move_toward(target,step*8),9): clear = false; break
	if clear: return origin.direction_to(target)
	refresh_navigation()
	if path.is_empty() or target.distance_to(path_goal) > 24 or parry.time-path_updated > 0.25:
		var first := closest_cell(origin); var last := closest_cell(target)
		if first == Vector2i(99999,99999) or last == Vector2i(99999,99999): return Vector2.ZERO
		path = navigation.get_point_path(first,last); path_goal = target; path_updated = parry.time
	while not path.is_empty() and origin.distance_to(path[0]) < 8: path.remove_at(0)
	return origin.direction_to(path[0]) if not path.is_empty() else Vector2.ZERO

func capture_state() -> Dictionary:
	var creature := {}
	if is_instance_valid(enemy):
		for key in ["position","heading","health","attack_elapsed","impact_done","punch_left","stun_remaining","walk_phase","state","standing","entering_attack","lower_elapsed"]: creature[key] = enemy.get(key)
		creature["death_elapsed"] = enemy.death_elapsed
		creature["corpse_expires"] = enemy.corpse_expires
		creature["loot_slots"] = enemy.loot_slots.duplicate(true)
		creature["effects"] = enemy.effects.active.duplicate(true)
		creature["stun_clip"] = enemy.stun_clip
		creature["behavior"] = enemy.behavior.snapshot()
	var hits := []
	for hit in parry.pending: hits.append({"damage":hit.damage,"impact":hit.impact})
	var result := {"defeated":defeated,"enemy":creature,"time":parry.time,"last_activation":parry.last_activation,"used":parry.used,"pending":hits}
	if not additional.is_empty():
		result["additional"] = []
		for child in additional: result.additional.append(child.capture_state())
	return result

static func valid_state(data) -> bool:
	if not data is Dictionary: return false
	if data.is_empty(): return true # A save from before combat was introduced.
	if data.has("additional"):
		if not data.additional is Array or data.additional.size() > 128: return false
		for child in data.additional:
			if not child is Dictionary or child.has("additional") or not valid_state(child): return false
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
	if data.defeated and creature.is_empty(): return true
	if data.defeated:
		if creature.get("health") != 0 or not creature.get("position") is Vector2 or not creature.position.is_finite(): return false
		if not creature.get("death_elapsed") is float or creature.death_elapsed < 0 or creature.death_elapsed > 2: return false
		if not creature.get("corpse_expires") is float or not is_finite(creature.corpse_expires): return false
		if not creature.get("loot_slots") is Array or creature.loot_slots.size() != 8: return false
		var uids := {}
		for item in creature.loot_slots:
			if not preload("res://scripts/save_game.gd").valid_item(item,uids): return false
	if creature.is_empty(): return true
	if not creature.get("position") is Vector2 or not creature.position.is_finite(): return false
	for key in ["heading","health","attack_elapsed","stun_remaining","walk_phase"]:
		if not (creature.get(key) is float or creature.get(key) is int) or not is_finite(float(creature[key])): return false
	if creature.health < 0 or (creature.health == 0 and not data.defeated) or creature.health > Enemy.MAX_HEALTH or creature.attack_elapsed < -1 or creature.attack_elapsed >= Enemy.ATTACK_PERIOD: return false
	if creature.stun_remaining < 0 or creature.stun_remaining > Parry.STUN_SECONDS or creature.walk_phase < 0 or creature.walk_phase >= 1: return false
	if not creature.get("impact_done") is bool or not creature.get("punch_left") is bool: return false
	if creature.has("standing") and not creature.standing is bool: return false
	if creature.has("entering_attack") and not creature.entering_attack is bool: return false
	if creature.has("lower_elapsed") and (not creature.lower_elapsed is float or not is_finite(creature.lower_elapsed) or creature.lower_elapsed < -1 or creature.lower_elapsed > 0.18): return false
	if creature.has("effects"):
		if not preload("res://scripts/status_effects.gd").valid_snapshot(creature.effects): return false
		if absf(creature.effects.get(&"stun",{}).get("remaining",0)-creature.stun_remaining) > 0.00001: return false
	if creature.has("stun_clip") and creature.stun_clip not in ["stun_fall","stun_fall_left","stun_fall_right"]: return false
	if creature.has("behavior") and not preload("res://scripts/creature_behavior.gd").valid_snapshot(creature.behavior): return false
	return creature.get("state") in [&"idle",&"walk",&"run",&"attack",&"feed",&"sit_down",&"sit",&"sit_up",&"death",&"corpse"]

func restore_state(data: Dictionary) -> void:
	if data.is_empty(): return
	for child in additional:
		if is_instance_valid(child.enemy): child.enemy.free()
	additional.clear()
	for saved in data.get("additional",[]):
		var child = get_script().new(); child.configure(game)
		if not saved.defeated or not saved.enemy.is_empty():
			child.enemy = Enemy.new(); game.add_child(child.enemy); child.enemy.configure(game,child)
		child.restore_state(saved); additional.append(child)
		if is_instance_valid(child.enemy): game.solar_lighting.shadows.add_enemy_projection(child.enemy)
	defeated = data.defeated
	if defeated and data.enemy.is_empty() and is_instance_valid(enemy): enemy.free(); enemy = null
	if is_instance_valid(enemy) and not data.enemy.is_empty():
		for key in data.enemy:
			if key == "loot_slots": enemy.loot_slots.assign(data.enemy[key])
			elif key not in ["effects","behavior"]: enemy.set(key,data.enemy[key])
		if data.enemy.has("effects"): enemy.effects.active = data.enemy.effects.duplicate(true)
		if data.enemy.has("behavior"): enemy.behavior.restore(data.enemy.behavior)
		if not data.enemy.has("standing"): enemy.standing = enemy.state == &"attack"
		if defeated: enemy.remove_from_group("damageable")
		enemy.update_sprite()
	parry.time = data.time; parry.last_activation = data.last_activation; parry.used = data.used; parry.pending.clear()
	for hit in data.pending: parry.pending.append({"attacker":enemy,"damage":hit.damage,"impact":hit.impact})

func spawn_debug_enemy() -> bool:
	if game.hut != null and game.hut.inside: return false
	if additional.size() >= 128: return false
	var point := Vector2.INF
	for radius in [128.0,160.0,96.0]:
		for i in 16:
			var candidate: Vector2 = game.player+Vector2.from_angle(game.movement.heading+i*TAU/16)*radius
			if not game.world.walkable(candidate,9): continue
			if is_instance_valid(enemy) and candidate.distance_to(enemy.position) < 32: continue
			var clear := true
			for child in additional:
				if is_instance_valid(child.enemy) and candidate.distance_to(child.enemy.position) < 32: clear = false
			if clear: point = candidate; break
		if point.is_finite(): break
	if not point.is_finite(): return false
	var child = get_script().new(); child.configure(game)
	child.parry.time = parry.time; child.parry.last_activation = parry.last_activation; child.parry.used = parry.used
	child.enemy = Enemy.new(); game.add_child(child.enemy); child.enemy.configure(game,child)
	child.enemy.position = point; child.enemy.update_sprite(); additional.append(child)
	game.solar_lighting.shadows.add_enemy_projection(child.enemy)
	return true
