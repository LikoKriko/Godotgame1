extends Node2D
## Two rigid bones per arm, with a live target and a fixed anatomical reach.
const UPPER := 12.0
const FOREARM := 11.0
const CONTACT_EPSILON := 0.05
const MAX_ARM := UPPER + FOREARM - 0.05
const TOOL_LENGTHS := {&"": 0.0, &"axe": 25.0, &"pickaxe": 28.0, &"sword": 30.0, &"bow": 12.0}
const ANCHORS := {
	&"down": [Vector2(-9.5,-25), Vector2(9.5,-25)],
	&"down_right": [Vector2(-6,-25), Vector2(7.5,-25)],
	&"right": [Vector2(-3,-26), Vector2(4,-25)],
	&"up_right": [Vector2(-5.5,-25), Vector2(6.5,-25)],
	&"up": [Vector2(-9,-25), Vector2(9,-25)],
	&"up_left": [Vector2(-6.5,-25), Vector2(5.5,-25)],
	&"left": [Vector2(-4,-25), Vector2(3,-26)],
	&"down_left": [Vector2(-7.5,-25), Vector2(6,-25)]
}
var layers: Array[Node2D] = []
var state: Dictionary = {}

class Limb:
	extends Node2D
	var shoulder := Vector2.ZERO
	var elbow := Vector2.ZERO
	var hand := Vector2.ZERO
	var tip := Vector2.ZERO
	var tool: StringName = &""
	func _draw() -> void:
		var outline := Color("69442f")
		var skin := Color("e2a065")
		for pair in [[shoulder, elbow], [elbow, hand]]:
			draw_line(pair[0], pair[1], outline, 7, false)
			draw_line(pair[0], pair[1], skin, 5, false)
		draw_circle(elbow, 3.0, skin)
		draw_rect(Rect2(hand - Vector2(3,3), Vector2(6,6)), outline)
		draw_rect(Rect2(hand - Vector2(2,2), Vector2(4,4)), Color("efb279"))
		if tool == &"":
			return
		var direction := hand.direction_to(tip)
		var cross := direction.orthogonal()
		draw_line(hand, tip - direction * 3, Color("5e422c"), 4, false)
		draw_line(hand, tip - direction * 3, Color("a77946"), 2, false)
		if tool == &"axe":
			var points := PackedVector2Array([tip-direction*7-cross*7, tip-cross*6, tip+cross*7, tip-direction*5+cross*6])
			draw_colored_polygon(points, Color("a3a5a0"))
			draw_line(tip-cross*6, tip+cross*7, Color("d4d3c7"), 2, false)
		elif tool == &"pickaxe":
			draw_polyline(PackedVector2Array([tip-direction*5-cross*11, tip, tip-direction*5+cross*11]), Color("bdc0b7"), 3, false)
		elif tool == &"sword":
			draw_line(hand, tip, Color("c5c9c3"), 4, false)
			draw_line(hand-cross*5, hand+cross*5, Color("a89a5b"), 3, false)
		else:
			draw_polyline(PackedVector2Array([tip-cross*11, tip+direction*4, tip+cross*11]), Color("9b7649"), 3, false)
			draw_line(tip-cross*11, tip+cross*11, Color("c2bfa7"), 1, false)

func _ready() -> void:
	for i in 2:
		var limb := Limb.new()
		limb.z_as_relative = false
		limb.z_index = 2
		add_child(limb)
		layers.append(limb)
	hide()

static func solve(shoulder: Vector2, requested: Vector2, bend: float) -> Dictionary:
	var offset := requested - shoulder
	var distance := clampf(offset.length(), absf(UPPER - FOREARM) + 0.05, MAX_ARM)
	var direction := offset.normalized() if offset.length() > 0.001 else Vector2.DOWN
	var hand := shoulder + direction * distance
	var along := (UPPER * UPPER - FOREARM * FOREARM + distance * distance) / (2 * distance)
	var height := sqrt(maxf(0, UPPER * UPPER - along * along))
	var elbow := shoulder + direction * along + direction.orthogonal() * height * bend
	return {"shoulder": shoulder, "elbow": elbow, "hand": hand}

static func contact(player: Vector2, aim: Vector2, item: StringName) -> Dictionary:
	var facing: StringName = preload("res://scripts/turn_motion.gd").facing_at((aim - player).angle())
	var anchors: Array = ANCHORS[facing]
	var index := 0 if (player + anchors[0]).distance_squared_to(aim) < (player + anchors[1]).distance_squared_to(aim) else 1
	var shoulder: Vector2 = player + anchors[index]
	var direction := shoulder.direction_to(aim)
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN
	var tool_length: float = TOOL_LENGTHS.get(item, 0.0)
	var distance := clampf(shoulder.distance_to(aim), tool_length + 1.05, tool_length + MAX_ARM)
	var hand := shoulder + direction * (distance - tool_length)
	var tip := hand + direction * tool_length
	return {"facing": facing, "index": index, "shoulder": shoulder, "hand": hand, "tip": tip, "direction": direction, "length": tool_length, "reachable": tip.distance_to(aim) <= CONTACT_EPSILON}

func animate(player: Vector2, aim: Vector2, item: StringName, phase: float) -> Dictionary:
	state = contact(player, aim, item)
	position = player
	var anchors: Array = ANCHORS[state["facing"]]
	var active: int = state["index"]
	var amount := 0.0
	if phase < 0.20:
		amount = -0.20 * sin(phase / 0.20 * PI / 2)
	elif phase <= 0.50:
		amount = lerpf(-0.20, 1.0, smoothstep(0.20, 0.50, phase))
	else:
		amount = 1.0 - smoothstep(0.50, 1.0, phase)
	for i in 2:
		var shoulder: Vector2 = player + anchors[i]
		var rest := shoulder + Vector2(-2 if i == 0 else 2, 19)
		var request: Vector2 = rest
		if i == active:
			request = rest.lerp(state["hand"], amount)
		elif item in [&"axe", &"pickaxe", &"bow"]:
			request = rest.lerp(state["hand"] - state["direction"] * 7, maxf(0, amount) * 0.75)
		var joints := solve(shoulder, request, -1.0 if i == 0 else 1.0)
		var limb = layers[i]
		limb.shoulder = joints["shoulder"] - player
		limb.elbow = joints["elbow"] - player
		limb.hand = joints["hand"] - player
		limb.tip = limb.hand + state["direction"] * state["length"]
		limb.tool = item if i == active else &""
		limb.z_index = 2 if i == active else -1
		limb.queue_redraw()
	show()
	return state
