extends RefCounted
## Interaction math only; all visible limbs belong to complete exported sprites.
const Tools = preload("res://scripts/tool_sprites.gd")
const MAX_ARM := 17.95
const CONTACT_EPSILON := 0.05
static var TOOL_LENGTHS := Tools.reach_lengths()
const ANCHORS := {
	&"down": [Vector2(-8.577319,-19.94845),Vector2(8.247422,-19.94845)],
	&"down_right": [Vector2(-7.42268,-19.94845),Vector2(7.257732,-19.94845)],
	&"right": [Vector2(-2.782609,-20.31969),Vector2(-5.074169,-20.31969)],
	&"up_right": [Vector2(-8.577319,-20.27835),Vector2(6.762887,-20.27835)],
	&"up": [Vector2(-9.094737,-20.72632),Vector2(8.421053,-20.72632)],
	&"up_left": [Vector2(-3.666667,-20.33333),Vector2(7.666667,-20.33333)],
	&"left": [Vector2(4.020942,-20.86387),Vector2(2.848168,-20.86387)],
	&"down_left": [Vector2(-8.712042,-20.5288),Vector2(11.05759,-20.5288)]
}
static func contact(player: Vector2, aim: Vector2, item: StringName, facing_override: StringName = &"") -> Dictionary:
	var facing: StringName = preload("res://scripts/turn_motion.gd").facing_at((aim-player).angle())
	if facing_override != &"":
		facing = facing_override
	var anchors: Array = ANCHORS[facing]
	var index := 0 if facing in [&"left",&"up_left",&"down_left"] else 1
	var shoulder: Vector2 = player+anchors[index]
	var direction := shoulder.direction_to(aim)
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN
	var tool_length: float = TOOL_LENGTHS.get(item,0.0)
	var distance := clampf(shoulder.distance_to(aim),tool_length+5.0,tool_length+MAX_ARM)
	var hand := shoulder+direction*(distance-tool_length)
	if item in [&"axe", &"pickaxe"]:
		hand = constrain_grip(player,facing,index,hand,direction,item)
	var tip := hand+direction*tool_length
	return {"facing": facing,"index": index,"shoulder": shoulder,"hand": hand,"tip": tip,"direction": direction,"length": tool_length,"reachable": tip.distance_to(aim) <= CONTACT_EPSILON}

static func constrain_grip(player: Vector2, facing: StringName, active: int, requested: Vector2, direction: Vector2, item: StringName) -> Vector2:
	var anchors: Array = ANCHORS[facing]
	var support := Tools.support_offset(item,direction,active == 0)
	# Intersection of the two arms' reach disks: translate the entire rigid
	# tool, never pull either hand off its handle or stretch a limb.
	var centers := [player+anchors[active],player+anchors[1-active]-support]
	var grip := requested
	for iteration in 32:
		for center in centers:
			var offset: Vector2 = grip-center
			if offset.length() > MAX_ARM-0.25:
				grip = center+offset.normalized()*(MAX_ARM-0.25)
	return grip
