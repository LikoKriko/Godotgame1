extends Node2D
## True alternating stance/swing phases, using pixels of the original legs.
const SKIN = preload("res://assets/characters/survivor_idle_8dir.png")
const UPPER := 12.0
const LOWER := 11.0
var thighs: Array[Polygon2D] = []
var shins: Array[Polygon2D] = []
var feet: Array[Polygon2D] = []
var joints: Array[Dictionary] = []
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i in 2:
		var thigh := Polygon2D.new()
		var shin := Polygon2D.new()
		for part in [thigh,shin]:
			part.texture = SKIN
			add_child(part)
		# Shorts near the lateral hand need the clean body source, without arm pixels.
		thigh.texture = preload("res://assets/characters/survivor_body_8dir.png")
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

func pose(player: Vector2, facing: StringName, phase: float, amplitude: float = 1.0, bob: float = 0.0, heading: float = INF, hip_transform: Transform2D = Transform2D.IDENTITY, foot_raise: float = 0.0) -> void:
	position = player
	var direction := Vector2.from_angle(heading if is_finite(heading) else preload("res://scripts/turn_motion.gd").FACINGS.find(facing)*PI/4)
	var view_index: int = preload("res://scripts/survivor_frames.gd").DIRECTIONS.find(facing)
	var region: Array = preload("res://assets/characters/survivor_regions.gd").IDLE[view_index]
	var factor: float = 64.0/region[3]
	joints.clear()
	for i in 2:
		var cycle := phase+(0.5 if i == 1 else 0.0)
		cycle = fposmod(cycle,1.0)
		# Human gait: 60% support, 40% swing, with two brief double supports.
		var stance := cycle < 0.6
		var progress := cycle/0.6 if stance else (cycle-0.6)/0.4
		var swing := (lerpf(1,-1,progress) if stance else lerpf(-1,1,smoothstep(0,1,progress)))*amplitude
		var lift := 0.0 if stance else sin(progress*PI)*4.5*amplitude
		var source: Dictionary = preload("res://scripts/character_parts.gd").leg(view_index,i)
		var hip := Vector2((source["hip"].x-region[4])*factor,-47+(source["hip"].y-region[1])*factor+bob)
		var foot_x := hip.x
		hip = hip_transform*(player+hip)-player
		var ankle := Vector2(foot_x+direction.x*swing*8.5,16.0+direction.y*swing*2.5-lift-foot_raise)
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
		map_part(thighs[i],hip,knee,source["hip"],source["knee"],source["upper"])
		map_part(shins[i],knee,ankle,source["knee"],source["ankle"],source["lower"])
		var foot_rect: Rect2 = preload("res://scripts/character_parts.gd").FEET[view_index][i]
		var pixels: Array = [foot_rect.position,foot_rect.position+Vector2(foot_rect.size.x,0),foot_rect.end,foot_rect.position+Vector2(0,foot_rect.size.y)]
		var pivot := Vector2(source["ankle"].x,foot_rect.end.y-4)
		var vertices := PackedVector2Array()
		for pixel in pixels:
			var point: Vector2 = (pixel-pivot)*0.16
			vertices.append(ankle+point)
		feet[i].polygon = vertices
		feet[i].uv = PackedVector2Array(pixels)
		var near := (i == 1 if direction.x >= 0 else i == 0)
		for part in [thighs[i],shins[i],feet[i]]:
			part.z_index = 0 if near else -1
