extends Node2D
## True alternating stance/swing phases, using pixels of the original legs.
const SKIN = preload("res://assets/characters/survivor_idle_8dir.png")
const UPPER := 12.0
const LOWER := 11.0
const SOURCE := [
	{"hip": Vector2(210,297),"knee": Vector2(211,373),"ankle": Vector2(201,420),
	"upper": [Vector2(183,293),Vector2(237,293),Vector2(233,335),Vector2(228,361),Vector2(224,379),Vector2(187,379),Vector2(184,350)],
	"lower": [Vector2(188,366),Vector2(226,368),Vector2(225,394),Vector2(217,410),Vector2(187,410),Vector2(182,405),Vector2(190,389)]},
	{"hip": Vector2(274,297),"knee": Vector2(280,373),"ankle": Vector2(284,420),
	"upper": [Vector2(247,293),Vector2(302,294),Vector2(304,337),Vector2(299,358),Vector2(297,380),Vector2(261,380),Vector2(254,348)],
	"lower": [Vector2(262,367),Vector2(299,365),Vector2(302,390),Vector2(300,407),Vector2(301,410),Vector2(271,410),Vector2(263,404)]},
]
var thighs: Array[Polygon2D] = []
var shins: Array[Polygon2D] = []
var feet: Array[Polygon2D] = []
var joints: Array[Dictionary] = []
const FRONT_FEET := [
	[Vector2(192,413),Vector2(214,413),Vector2(217,422),Vector2(231,425),Vector2(239,432),Vector2(228,438),Vector2(177,438),Vector2(173,431),Vector2(180,423),Vector2(189,420)],
	[Vector2(272,413),Vector2(296,413),Vector2(302,420),Vector2(314,424),Vector2(322,433),Vector2(315,438),Vector2(260,438),Vector2(257,431),Vector2(267,423)],
]
const SIDE_FOOT := [Vector2(1045,405),Vector2(1069,405),Vector2(1073,413),Vector2(1090,417),Vector2(1107,423),Vector2(1113,433),Vector2(1104,439),Vector2(1045,439),Vector2(1036,432),Vector2(1034,419)]
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i in 2:
		var thigh := Polygon2D.new()
		var shin := Polygon2D.new()
		for part in [thigh,shin]:
			part.texture = SKIN
			add_child(part)
		thighs.append(thigh)
		shins.append(shin)
		var foot := Polygon2D.new()
		foot.texture = SKIN
		add_child(foot)
		feet.append(foot)

func map_part(part: Polygon2D, a: Vector2, b: Vector2, source_a: Vector2, source_b: Vector2, pixels: Array) -> void:
	var axis := source_a.direction_to(source_b)
	var direction := a.direction_to(b)
	var scale := a.distance_to(b)/source_a.distance_to(source_b)
	var vertices := PackedVector2Array()
	for pixel in pixels:
		var offset: Vector2 = pixel-source_a
		vertices.append(a+direction*offset.dot(axis)*scale+direction.orthogonal()*offset.dot(axis.orthogonal())*0.16)
	part.polygon = vertices
	part.uv = PackedVector2Array(pixels)

func pose(player: Vector2, facing: StringName, phase: float, amplitude: float = 1.0, bob: float = 0.0, heading: float = INF) -> void:
	position = player
	var direction := Vector2.from_angle(heading if is_finite(heading) else preload("res://scripts/turn_motion.gd").FACINGS.find(facing)*PI/4)
	var side_view := facing in [&"right",&"left"]
	var spacing := lerpf(4.6,1.8,smoothstep(0,1,absf(direction.x)))
	joints.clear()
	for i in 2:
		var cycle := phase+(0.5 if i == 1 else 0.0)
		cycle = fposmod(cycle,1.0)
		# Human gait: 60% support, 40% swing, with two brief double supports.
		var stance := cycle < 0.6
		var progress := cycle/0.6 if stance else (cycle-0.6)/0.4
		var swing := (lerpf(1,-1,progress) if stance else lerpf(-1,1,smoothstep(0,1,progress)))*amplitude
		var lift := 0.0 if stance else sin(progress*PI)*4.5*amplitude
		var hip := Vector2(-spacing if i == 0 else spacing,-5.0+bob)
		var ankle := Vector2(hip.x+direction.x*swing*8.5,16.0+direction.y*swing*2.5-lift)
		var offset := ankle-hip
		var distance := clampf(offset.length(),absf(UPPER-LOWER)+0.1,UPPER+LOWER-0.05)
		var axis := offset.normalized()
		ankle = hip+axis*distance
		var along := (UPPER*UPPER-LOWER*LOWER+distance*distance)/(2*distance)
		var height := sqrt(maxf(0,UPPER*UPPER-along*along))
		var bend := lerpf(-0.35 if i == 0 else 0.35,signf(direction.x),smoothstep(0.12,0.7,absf(direction.x)))
		var knee := hip+axis*along+axis.orthogonal()*height*bend
		var depth := height*sqrt(maxf(0,1-bend*bend))
		joints.append({"hip": hip,"knee": knee,"ankle": ankle,"depth": depth,"lift": lift})
		var source: Dictionary = SOURCE[i]
		map_part(thighs[i],hip,knee,source["hip"],source["knee"],source["upper"])
		map_part(shins[i],knee,ankle,source["knee"],source["ankle"],source["lower"])
		var pixels: Array = SIDE_FOOT if side_view else FRONT_FEET[i]
		var pivot := Vector2(1058,434) if side_view else Vector2(200 if i == 0 else 283,433)
		var vertices := PackedVector2Array()
		for pixel in pixels:
			var point: Vector2 = (pixel-pivot)*0.16
			if side_view and direction.x < 0:
				point.x = -point.x
			vertices.append(ankle+point)
		feet[i].polygon = vertices
		feet[i].uv = PackedVector2Array(pixels)
		var near := (i == 1 if direction.x >= 0 else i == 0)
		for part in [thighs[i],shins[i],feet[i]]:
			part.z_index = 0 if near else -1
