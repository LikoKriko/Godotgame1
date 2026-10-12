extends Node2D
## Skin comes from the character atlas; shoulders match each work pose.
const SKIN = preload("res://assets/characters/survivor_idle_8dir.png")
const Tools = preload("res://scripts/tool_sprites.gd")
const UPPER := 10.0
const FOREARM := 9.0
const CONTACT_EPSILON := 0.05
const HAND_DEPTH := 6.0
const MAX_ARM := 17.95
const TOOL_LENGTHS := {&"": 0.0, &"axe": 25.0, &"pickaxe": 28.0, &"sword": 30.0, &"bow": 12.0}
const ANCHORS := {
	&"down": [Vector2(-8,-20.5),Vector2(8,-20.5)],
	&"down_right": [Vector2(-6.9,-20.5),Vector2(6.9,-20.5)],
	&"right": [Vector2(-3,-21),Vector2(-5.5,-20.7)],
	&"up_right": [Vector2(-9,-20.5),Vector2(5.5,-21.1)],
	&"up": [Vector2(-8.3,-20.6),Vector2(8.2,-21)],
	&"up_left": [Vector2(-3.7,-20.4),Vector2(9.5,-21.2)],
	&"left": [Vector2(5.9,-21.1),Vector2(3,-21)],
	&"down_left": [Vector2(-7.2,-20.5),Vector2(10,-20.7)],
}
# These polygons isolate the original arm pixels at runtime; no flat-color skin.
const SOURCE := [
	{"shoulder": Vector2(190,215),"elbow": Vector2(178,269),"hand": Vector2(169,319),
	"upper": [Vector2(178,210),Vector2(190,199),Vector2(200,205),Vector2(203,222),Vector2(196,247),Vector2(191,269),Vector2(171,273),Vector2(170,257),Vector2(177,232)],
	"lower": [Vector2(171,261),Vector2(190,267),Vector2(187,286),Vector2(184,304),Vector2(188,318),Vector2(178,333),Vector2(159,333),Vector2(151,319),Vector2(156,302),Vector2(161,281)]},
	{"shoulder": Vector2(292,215),"elbow": Vector2(306,269),"hand": Vector2(313,319),
	"upper": [Vector2(281,205),Vector2(292,199),Vector2(300,206),Vector2(306,224),Vector2(310,245),Vector2(318,269),Vector2(299,275),Vector2(291,257),Vector2(284,232)],
	"lower": [Vector2(298,261),Vector2(317,263),Vector2(320,285),Vector2(325,302),Vector2(333,317),Vector2(326,330),Vector2(310,334),Vector2(297,325),Vector2(295,312),Vector2(302,294)]},
]
var layers: Array[Node2D] = []
var state: Dictionary = {}

class Limb:
	extends Node2D
	var shoulder := Vector2.ZERO
	var elbow := Vector2.ZERO
	var hand := Vector2.ZERO
	var tip := Vector2.ZERO
	var tool: StringName = &""
	var source_index := 0
	var depth := 0.0
	var hand_depth := 0.0
	var upper: Polygon2D
	var lower: Polygon2D
	func _ready() -> void:
		upper = Polygon2D.new()
		lower = Polygon2D.new()
		for part in [upper,lower]:
			part.texture = SKIN
			part.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			part.z_index = 0
			add_child(part)
	func update_skin() -> void:
		var source: Dictionary = SOURCE[source_index]
		map_part(upper,shoulder,elbow,source["shoulder"],source["elbow"],source["upper"])
		map_part(lower,elbow,hand,source["elbow"],source["hand"],source["lower"])
	func map_part(part: Polygon2D, a: Vector2, b: Vector2, source_a: Vector2, source_b: Vector2, pixels: Array) -> void:
		var source_direction := source_a.direction_to(source_b)
		var direction := a.direction_to(b)
		var along_scale := a.distance_to(b)/source_a.distance_to(source_b)
		var width_scale := (UPPER if part == upper else FOREARM)/source_a.distance_to(source_b)
		var vertices := PackedVector2Array()
		for point in pixels:
			var offset: Vector2 = point-source_a
			vertices.append(a+direction*offset.dot(source_direction)*along_scale+direction.orthogonal()*offset.dot(source_direction.orthogonal())*width_scale)
		part.polygon = vertices
		part.uv = PackedVector2Array(pixels)
	func _draw() -> void:
		if tool != &"":
			Tools.draw(self,tool,hand,tip,source_index == 0)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i in 2:
		var limb := Limb.new()
		limb.source_index = i
		add_child(limb)
		layers.append(limb)
	hide()

static func solve(shoulder: Vector2, requested: Vector2, bend: float) -> Dictionary:
	var offset := requested-shoulder
	if offset.length() > MAX_ARM:
		offset = offset.normalized()*MAX_ARM
	# Solve in 3D: hands work in front of the chest, with elbows pointing
	# down/outward. This remains continuous even directly over a shoulder.
	var target := Vector3(offset.x,offset.y,HAND_DEPTH)
	var distance := target.length()
	var direction := target/distance
	var pole := Vector3(bend*0.45,1.0,0.0)
	var perpendicular := (pole-direction*pole.dot(direction)).normalized()
	var along := (UPPER*UPPER-FOREARM*FOREARM+distance*distance)/(2*distance)
	var height := sqrt(maxf(0,UPPER*UPPER-along*along))
	var elbow := direction*along+perpendicular*height
	return {"shoulder": shoulder,"elbow": shoulder+Vector2(elbow.x,elbow.y),"hand": shoulder+offset,"depth": elbow.z,"hand_depth": HAND_DEPTH}

static func contact(player: Vector2, aim: Vector2, item: StringName) -> Dictionary:
	var facing: StringName = preload("res://scripts/turn_motion.gd").facing_at((aim-player).angle())
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

func set_limb(index: int, shoulder: Vector2, request: Vector2, player: Vector2, item: StringName, tool_direction: Vector2, near: bool) -> void:
	# Anatomical elbow preference remains stable throughout the gesture.
	# A stable elbow plane preserves an actual bend instead of collapsing
	# both segments into a line at shoulder height.
	var pole := -1.0 if index == 0 else 1.0
	if state.get("facing", &"down") in [&"right", &"up_right"]:
		pole = -1.0
	elif state.get("facing", &"down") in [&"left", &"up_left"]:
		pole = 1.0
	var joints := solve(shoulder,request,pole)
	var limb = layers[index]
	limb.depth = joints["depth"]
	limb.hand_depth = joints["hand_depth"]
	limb.shoulder = joints["shoulder"]-player
	limb.elbow = joints["elbow"]-player
	limb.hand = joints["hand"]-player
	limb.tip = limb.hand+tool_direction*TOOL_LENGTHS.get(item,0.0)
	limb.tool = item
	limb.z_index = 0 if near else -1
	limb.update_skin()
	limb.queue_redraw()

static func rest_direction(facing: StringName, item: StringName) -> Vector2:
	var direction := Vector2(0.995,0.1).normalized() if item == &"pickaxe" else Vector2(0.8,-0.6)
	if facing in [&"left",&"up_left",&"down_left"]:
		direction.x = -direction.x
	return direction

static func idle_hand(facing: StringName) -> Vector2:
	var frames = preload("res://scripts/survivor_frames.gd")
	var regions = preload("res://assets/characters/survivor_regions.gd")
	var index: int = frames.DIRECTIONS.find(facing)
	var region: Array = regions.IDLE[index]
	var point: Array = regions.HAND_IDLE[index]
	var factor: float = 64.0/region[3]
	return Vector2((point[0]-region[4])*factor,17+(point[1]-region[1]-region[3])*factor)

static func blend_direction(from: Vector2, to: Vector2, amount: float) -> Vector2:
	return Vector2.from_angle(from.angle()+wrapf(to.angle()-from.angle(),-PI,PI)*amount)

static func blend_hand(root: Vector2, from: Vector2, to: Vector2, amount: float) -> Vector2:
	var start := from-root
	var finish := to-root
	var direction := blend_direction(start.normalized(),finish.normalized(),amount)
	return root+direction*lerpf(start.length(),finish.length(),amount)

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

static func ready_grip(player: Vector2, facing: StringName, active: int, item: StringName) -> Vector2:
	var side := -1.0 if active == 0 else 1.0
	return constrain_grip(player,facing,active,player+Vector2(side*5,-8),rest_direction(facing,item),item)

func two_handed(player: Vector2, facing: StringName, item: StringName, request: Vector2, direction: Vector2) -> void:
	var active := 0 if facing in [&"left",&"up_left",&"down_left"] else 1
	var grip := constrain_grip(player,facing,active,request,direction,item)
	var support := Tools.support_offset(item,direction,active == 0)
	for i in 2:
		var root: Vector2 = player+ANCHORS[facing][i]
		set_limb(i,root,grip if i == active else grip+support,player,item if i == active else &"",direction,i == active or facing in [&"down",&"down_right",&"down_left",&"left",&"right"])

func ready_pose(player: Vector2, facing: StringName, item: StringName) -> void:
	position = player
	state = {"facing": facing}
	var active := 0 if facing in [&"left",&"up_left",&"down_left"] else 1
	two_handed(player,facing,item,ready_grip(player,facing,active,item),rest_direction(facing,item))
	show()

func animate(player: Vector2, aim: Vector2, item: StringName, phase: float) -> Dictionary:
	state = contact(player,aim,item)
	position = player
	var anchors: Array = ANCHORS[state["facing"]]
	var active: int = state["index"]
	var forward: Vector2 = state["direction"]
	var shoulder: Vector2 = state["shoulder"]
	var rest := ready_grip(player,state["facing"],active,item) if item in [&"axe",&"pickaxe"] else player+idle_hand(state["facing"])
	var windup := shoulder+Vector2(3 if active == 0 else -3,8)
	var held_direction := rest_direction(state["facing"],item)
	var windup_direction := forward
	if item == &"axe":
		var side := 1.0 if active == 0 else -1.0
		windup = player+Vector2(-side*3,-22)
		windup_direction = forward.rotated(side*1.35)
	elif item == &"pickaxe":
		var lift_x := 8.0 if state["facing"] in [&"right",&"up_right"] else (-8.0 if state["facing"] in [&"left",&"up_left"] else (8.0 if active == 0 else -8.0))
		windup = player+Vector2(lift_x*0.25,-28)
		windup_direction = Vector2.UP
	var request := rest
	var tool_direction := held_direction
	if phase < 0.22:
		var blend := smoothstep(0,0.22,phase)
		request = rest.lerp(windup,blend) if item in [&"axe",&"pickaxe"] else blend_hand(shoulder,rest,windup,blend)
		tool_direction = blend_direction(held_direction,windup_direction,blend)
	elif phase <= 0.5:
		var blend := smoothstep(0.22,0.5,phase)
		request = windup.lerp(state["hand"],blend) if item in [&"axe",&"pickaxe"] else blend_hand(shoulder,windup,state["hand"],blend)
		tool_direction = blend_direction(windup_direction,forward,blend)
	else:
		var blend := smoothstep(0.5,1,phase)
		request = state["hand"].lerp(rest,blend) if item in [&"axe",&"pickaxe"] else blend_hand(shoulder,state["hand"],rest,blend)
		tool_direction = blend_direction(forward,held_direction,blend)
	if item in [&"axe",&"pickaxe"]:
		two_handed(player,state["facing"],item,request,tool_direction)
		show()
		return state
	for i in 2:
		var root: Vector2 = player+anchors[i]
		var target := root+Vector2(-3.6 if i == 0 else 3.6,16.8)
		if i == active:
			target = request
		else:
			var guard := root+Vector2(4 if i == 0 else -4,5 if item == &"pickaxe" else 9)
			target = target.lerp(guard,maxf(0,sin(phase*PI))*0.5)
		set_limb(i,root,target,player,item if i == active else &"",tool_direction,i == active or state["facing"] in [&"down",&"down_right",&"down_left",&"right",&"left"])
	show()
	return state

func equip(player: Vector2, facing: StringName, item: StringName, phase: float, desired_hand: Vector2 = Vector2(INF,INF)) -> void:
	position = player
	state = {"facing": facing}
	var anchors: Array = ANCHORS[facing]
	var active := 0 if facing in [&"left",&"up_left",&"down_left"] else 1
	if item in [&"axe",&"pickaxe"]:
		var shoulder: Vector2 = player+anchors[active]
		var final_grip := ready_grip(player,facing,active,item)
		var lift := shoulder+Vector2(-5 if active == 0 else 5,-4 if item == &"pickaxe" else 6)
		var start := player+Vector2(-5 if active == 0 else 5,-2)
		var request := blend_hand(shoulder,start,lift,smoothstep(0,0.45,phase)) if phase < 0.45 else blend_hand(shoulder,lift,final_grip,smoothstep(0.45,1,phase))
		var rotation := (0.85 if item == &"pickaxe" else -0.6)*sin(phase*PI)
		two_handed(player,facing,item,request,rest_direction(facing,item).rotated(rotation))
		show()
		return
	var sweep := smoothstep(0,1,phase)
	var forward := rest_direction(facing,item)
	for i in 2:
		var shoulder: Vector2 = player+anchors[i]
		var rest := shoulder+Vector2(-3.6 if i == 0 else 3.6,16.8)
		var request := rest
		var rotation := 0.0
		if i == active:
			var belt := shoulder+Vector2(-3 if i == 1 else 3,13)
			var held := player+desired_hand if desired_hand.is_finite() else shoulder+Vector2(4 if i == 1 else -4,16)
			var lifted := shoulder+(Vector2(3 if i == 1 else -3,-4) if item == &"pickaxe" else Vector2(6 if i == 1 else -6,9))
			request = blend_hand(shoulder,belt,lifted,smoothstep(0,0.5,phase)) if phase < 0.5 else blend_hand(shoulder,lifted,held,smoothstep(0.5,1,phase))
			rotation = (1.5 if item == &"axe" else 2.1)*(1-sweep)*(1 if active == 1 else -1)
		set_limb(i,shoulder,request,player,item if i == active else &"",forward.rotated(rotation),i == active)
	show()
