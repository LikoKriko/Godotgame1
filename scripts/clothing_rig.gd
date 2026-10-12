extends Node2D
const Parts = preload("res://scripts/character_parts.gd")
const Regions = preload("res://assets/characters/survivor_regions.gd")
const Frames = preload("res://scripts/survivor_frames.gd")
const Poses = preload("res://scripts/clothing_poses.gd")
var waist: Polygon2D
var trousers: Array[Polygon2D] = []
var folds: Array[PackedVector2Array] = []
var state: StringName = &"idle"
var phase := 0.0
var pose: Dictionary = {}
var source_cache: Dictionary = {}
func _ready() -> void:
	waist = make_part()
	for limb in 2: trousers.append(make_part())
func make_part() -> Polygon2D:
	var part := Polygon2D.new()
	part.texture = Frames.BODY_SHEET
	part.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(part)
	return part
func sources(index: int) -> Dictionary:
	if source_cache.has(index): return source_cache[index]
	var left: Vector2 = Parts.LEG_JOINTS[index][0][0]
	var right: Vector2 = Parts.LEG_JOINTS[index][1][0]
	var center := (left+right)/2
	var minimum := minf(left.x,right.x)-23
	var maximum := maxf(left.x,right.x)+23
	var pixels := [Vector2(minimum+8,center.y-34),Vector2(maximum-8,center.y-34),Vector2(maximum,center.y+6),Vector2(maximum-19,center.y+24),Vector2(center.x+9,center.y+35),Vector2(center.x-9,center.y+35),Vector2(minimum+19,center.y+24),Vector2(minimum,center.y+6)]
	source_cache[index] = {"waist":pixels,"center":center,"left":left,"right":right}
	return source_cache[index]
func update_pose(game,gait) -> void:
	position = game.player
	state = &"walk" if gait.was_walking else &"idle"
	phase = gait.phase if gait.was_walking else fposmod(gait.idle_clock/4,1)
	if game.equipping:
		state = &"equip"
		phase = clampf(game.equip_elapsed/(0.5 if game.bag.held_id() == &"pickaxe" else 0.42),0,1)
	elif game.working:
		state = game.bag.held_id() if game.bag.held_id() in [&"axe",&"pickaxe"] else &"punch"
		phase = clampf(game.work_elapsed/game.work_duration,0,1)
	elif game.locomotion.airborne():
		state = &"jump"
		phase = game.locomotion.jump_elapsed/game.locomotion.JUMP_SECONDS
	elif game.locomotion.sliding():
		state = &"slide"
		phase = game.locomotion.slide_elapsed/game.locomotion.SLIDE_SECONDS
	elif game.locomotion.crouch > 0:
		state = &"crouch"
		phase = game.locomotion.crouch
	var index: int = Frames.DIRECTIONS.find(gait.facing)
	pose = Poses.sample(state,index,phase)
	var region: Array = Regions.IDLE[index]
	var factor: float = 64.0/region[3]
	var source := sources(index)
	var center_hip: Vector2 = (gait.legs.joints[0]["hip"]+gait.legs.joints[1]["hip"])/2
	var vertices := PackedVector2Array()
	for pixel in source["waist"]:
		var offset: Vector2 = (pixel-source["center"])*factor
		offset.x *= pose["depth"]
		var point := center_hip+offset.rotated(gait.torso.rotation)
		point.x += pose["twist"]*clampf((pixel.y-source["center"].y+34)/69,0,1)
		vertices.append(point)
	waist.polygon = vertices
	waist.uv = PackedVector2Array(source["waist"])
	folds.clear()
	for limb in 2:
		var data: Dictionary = Parts.leg(index,limb)
		var hip: Vector2 = gait.legs.joints[limb]["hip"]
		var knee: Vector2 = gait.legs.joints[limb]["knee"]
		var source_axis: Vector2 = data["hip"].direction_to(data["knee"])
		var axis := hip.direction_to(knee)
		var across := axis.orthogonal()
		var pixels := [data["hip"]+Vector2(-23,-12),data["hip"]+Vector2(23,-12),data["hip"]+Vector2(24,27),data["hip"]+Vector2(21,48),data["hip"]+Vector2(-21,48),data["hip"]+Vector2(-24,27)]
		var points := PackedVector2Array()
		for pixel in pixels:
			var offset: Vector2 = pixel-data["hip"]
			var hem := clampf(offset.y/48,0,1)
			var along: float = offset.dot(source_axis)*hip.distance_to(knee)/data["hip"].distance_to(data["knee"])
			var width: float = offset.dot(source_axis.orthogonal())*0.16*pose["depth"]
			var point: Vector2 = hip+axis*along+across*width
			point += across*pose["flutter"]*hem*(1 if limb == 0 else -1)
			point += axis*pose["fold"]*hem*0.28
			points.append(point)
		trousers[limb].polygon = points
		trousers[limb].uv = PackedVector2Array(pixels)
		trousers[limb].z_index = gait.legs.thighs[limb].z_index
		var origin: Vector2 = hip+axis*4.8+across*pose["pocket"]
		folds.append(PackedVector2Array([origin-across*1.25,origin+axis*(0.3+pose["fold"]*0.6),origin+across*1.25+axis*0.4]))
	queue_redraw()
func draw_details(canvas: CanvasItem) -> void:
	var amount: float = pose.get("fold",0.0)
	for fold in folds:
		canvas.draw_polyline(fold,Color(0.23,0.18,0.12,0.18+amount*0.24),0.25,true)
		canvas.draw_line(fold[1]+Vector2(0,0.3),fold[2]+Vector2(0,0.3),Color(0.67,0.46,0.25,amount*0.3),0.22,true)
func _draw() -> void: draw_details(self)
