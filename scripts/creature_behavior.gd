extends RefCounted
## Reusable state decisions: species profiles select habitat, pace and reactions.
const NONE := Vector2i(99999,99999)
var actor
var profile
var rng := RandomNumberGenerator.new()
var initialized := false
var mode: StringName = &"idle"
var elapsed := 0.0
var remaining := 0.0
var goal := Vector2.ZERO
var target_tree := NONE
var rise_remaining := 0.0
func configure(creature, personality) -> void:
	actor = creature; profile = personality
func seed_if_needed() -> void:
	if initialized: return
	rng.seed = actor.game.world.seed_value ^ hash(Vector2i(actor.position))
	initialized = true; goal = actor.position
func advance(delta: float) -> StringName:
	seed_if_needed(); elapsed += delta; remaining = maxf(0,remaining-delta)
	rise_remaining = maxf(0,rise_remaining-delta)
	if profile.aggressive_to_player and actor.position.distance_to(actor.game.player) <= profile.alert_radius:
		if mode in [&"sit_down",&"sit",&"sit_up"]: rise_remaining = profile.posture_seconds
		if mode != &"chase": elapsed = 0
		mode = &"chase"; target_tree = NONE; return mode
	if mode == &"chase": mode = &"idle"; elapsed = 0
	if mode == &"feed" and actor.game.world.props.get(target_tree) != 2:
		mode = &"idle"; remaining = 0
	if mode == &"sit_down" and remaining <= 0:
		set_mode(&"sit",rng.randf_range(profile.resting_seconds.x,profile.resting_seconds.y))
	elif mode == &"sit" and remaining <= 0: set_mode(&"sit_up",profile.posture_seconds)
	elif mode in [&"feed",&"sit_up"] and remaining <= 0: set_mode(&"idle",0)
	if mode == &"walk" and (remaining <= 0 or actor.position.distance_to(goal) < 8):
		if actor.game.world.props.get(target_tree) == 2 and actor.position.distance_to(goal) < 12:
			set_mode(&"feed",rng.randf_range(profile.feeding_seconds.x,profile.feeding_seconds.y))
		else: set_mode(&"idle",0)
	if mode == &"idle": choose_activity()
	return mode
func set_mode(next: StringName, seconds: float) -> void:
	mode = next; remaining = seconds; elapsed = 0
func choose_activity() -> void:
	if rng.randf() < 0.25:
		set_mode(&"sit_down",profile.posture_seconds); return
	var world = actor.game.world
	var trees: Array = []
	if profile.tree_habitat:
		for cell in world.props:
			if world.props[cell] == 2: trees.append(cell)
	var choices: Array[Dictionary] = []
	for cell in trees:
		var center: Vector2 = world.prop_collisions[cell].get_center()
		if center.distance_to(actor.position) > 640: continue
		var density := 0
		for other in trees:
			if world.prop_collisions[other].get_center().distance_squared_to(center) < 192*192: density += 1
		choices.append({"cell":cell,"score":density*45-center.distance_to(actor.position)*0.08+rng.randf()*40})
	choices.sort_custom(func(a,b): return a.score > b.score)
	for choice in choices:
		var rect: Rect2 = world.prop_collisions[choice.cell]
		for attempt in 12:
			var point := rect.get_center()+Vector2.from_angle(rng.randf()*TAU)*(maxf(rect.size.x,rect.size.y)/2+24)
			if not world.walkable(point,9): continue
			goal = point; target_tree = choice.cell; set_mode(&"walk",12); return
	# Future different species can attract this curious creature outside combat.
	if profile.curious:
		for other in actor.get_tree().get_nodes_in_group("creatures"):
			if other == actor or not other.has_meta("species_id") or other.get_meta("species_id") == profile.species_id: continue
			var point: Vector2 = actor.position.move_toward(other.position,80)
			if world.walkable(point,9): goal = point; target_tree = NONE; set_mode(&"walk",5); return
	for attempt in 12:
		var point: Vector2 = actor.position+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(40,100)
		if world.walkable(point,9): goal = point; target_tree = NONE; set_mode(&"walk",5); return
	set_mode(&"sit_down",profile.posture_seconds)
func snapshot() -> Dictionary:
	return {"mode":mode,"elapsed":elapsed,"remaining":remaining,"goal":goal,"target_tree":target_tree,"rise_remaining":rise_remaining,"initialized":initialized,"rng_state":rng.state,"rng_seed":rng.seed}
static func valid_snapshot(data) -> bool:
	if not data is Dictionary: return false
	if data.get("mode") not in [&"idle",&"walk",&"chase",&"feed",&"sit_down",&"sit",&"sit_up"]: return false
	for key in ["elapsed","remaining","rise_remaining"]:
		if not data.get(key) is float or not is_finite(data[key]) or data[key] < 0: return false
	return data.get("goal") is Vector2 and data.goal.is_finite() and data.get("target_tree") is Vector2i and data.get("initialized") is bool and data.get("rng_state") is int and data.get("rng_seed") is int
func restore(data: Dictionary) -> void:
	mode = data.mode; elapsed = data.elapsed; remaining = data.remaining
	goal = data.goal; target_tree = data.target_tree; rise_remaining = data.rise_remaining
	initialized = data.initialized; rng.seed = data.rng_seed; rng.state = data.rng_state
