extends Node2D
## Fixed original head, independent upper body, articulated arms/legs and soft stop.
const Frames = preload("res://scripts/survivor_frames.gd")
const Regions = preload("res://assets/characters/survivor_regions.gd")
const STOP_SECONDS := 0.18
const START_SECONDS := 0.14
const Motion = preload("res://scripts/action_motion.gd")
var start_elapsed := 0.0
var working_pose := false
var game
var head: Sprite2D
var torso: Polygon2D
var legs: Node2D
var was_walking := false
var stopping := false
var stop_elapsed := 0.0
var phase := 0.0
var bob := 0.0
var facing: StringName = &"down"
var opacity := 1.0
var stride_amplitude := 0.0
var idle_clock := 0.0
var clothing: Node2D
var textures: Dictionary = {}
var torso_meshes: Dictionary = {}

func configure(owner_game) -> void:
	game = owner_game
	legs = preload("res://scripts/leg_rig.gd").new()
	add_child(legs)
	torso = Polygon2D.new()
	torso.texture = Frames.BODY_SHEET
	torso.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(torso)
	clothing = preload("res://scripts/clothing_rig.gd").new()
	add_child(clothing)
	head = Sprite2D.new()
	for sprite in [head]:
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
	hide()

func torso_piece(index: int) -> void:
	var data: Array = Regions.IDLE[index]
	var factor: float = 64.0/data[3]
	if not torso_meshes.has(index):
		var body: Array = Regions.BODY[index]
		var start: int = data[1]+floori(23/factor)
		var limit := 275.0 if index < 4 else 691.0
		var pixels := PackedVector2Array([Vector2(body[0],start),Vector2(body[0]+body[2],start),Vector2(body[0]+body[2],limit),Vector2(body[0],limit)])
		var vertices := PackedVector2Array()
		for pixel in pixels:
			vertices.append(Vector2((pixel.x-data[4])*factor,-47+(pixel.y-data[1])*factor))
		torso_meshes[index] = {"vertices":vertices,"uv":pixels}
	if torso.uv != torso_meshes[index]["uv"]:
		torso.polygon = torso_meshes[index]["vertices"]
		torso.uv = torso_meshes[index]["uv"]
	torso.position = game.player+Vector2(0,bob)
	torso.rotation = 0

func sprite_piece(sprite: Sprite2D, sheet: Texture2D, data: Array, from_y: float, to_y: float) -> void:
	var factor: float = 64.0/data[3]
	var start := floori((from_y+47)/factor)
	var end := ceili((to_y+47)/factor)
	var key := "%d/%d/%d/%d" % [sheet.get_instance_id(),data[0],start,end]
	if not textures.has(key):
		var texture := AtlasTexture.new()
		texture.atlas = sheet
		texture.region = Rect2(data[0],data[1]+start,data[2],end-start)
		textures[key] = texture
	sprite.texture = textures[key]
	sprite.scale = Vector2.ONE*factor
	sprite.rotation = 0
	sprite.position = game.player+Vector2((data[0]-data[4])*factor,-47+start*factor+bob)

func active() -> bool:
	return visible

func cancel() -> void:
	hide()
	was_walking = false
	working_pose = false
	start_elapsed = 0
	stopping = false
	game.character.show()
	game.character.modulate = Color.WHITE
	game.arm_rig.modulate = Color.WHITE

func update_pose(delta: float) -> void:
	idle_clock += maxf(0,delta)
	if game.working:
		update_work_pose()
		return
	if game.equipping:
		update_work_pose()
		return
	var walking: bool = game.character.animation.begins_with("walk_") or (game.movement.is_turning() and game.movement.target_direction != Vector2.ZERO)
	working_pose = false
	if walking:
		facing = game.movement.facing()
		if delta <= 0:
			phase = (game.character.frame+game.character.frame_progress)/4.0
			start_elapsed = START_SECONDS
		else:
			phase = fposmod(phase+delta*2*game.movement.speed_factor*game.nutrition.speed_multiplier(),1.0)
			start_elapsed += delta
		stop_elapsed = 0
		stopping = false
		was_walking = true
		game.character.hide()
		opacity = 1.0
	elif was_walking:
		stopping = true
		stop_elapsed += maxf(0,delta)
		opacity = 1.0
		game.character.hide()
		if stop_elapsed >= STOP_SECONDS:
			cancel()
			return
	else:
		cancel()
		return
	var stop_factor := 1-smoothstep(0,STOP_SECONDS,stop_elapsed) if stopping else 1.0
	bob = -0.65*(1-cos(phase*4*PI))*stop_factor
	var index: int = Frames.DIRECTIONS.find(facing)
	sprite_piece(head,Frames.IDLE_SHEET,Regions.IDLE[index],-47,-22)
	torso_piece(index)
	for sprite in [head,torso,legs]:
		sprite.modulate = Color(1,1,1,opacity)
	var amplitude := stop_factor*smoothstep(0,START_SECONDS,start_elapsed)
	stride_amplitude = amplitude
	legs.pose(game.player,facing,phase,amplitude,bob,game.movement.heading)
	game.arm_rig.gait(game.player+Vector2(0,bob),facing,game.bag.held_id(),phase,amplitude,game.movement.heading)
	game.arm_rig.modulate = Color.WHITE if game.bag.held_id() in Motion.TOOL_MASS else Color(1,1,1,opacity)
	show()
	clothing.update_pose(game,self)

func update_work_pose() -> void:
	working_pose = true
	was_walking = false
	stopping = false
	opacity = 1.0
	facing = game.movement.facing()
	var phase := clampf(game.work_elapsed/game.work_duration,0,1)
	var item: StringName = game.bag.held_id()
	var transform := Motion.torso_transform(game.player,facing,phase,item,game.arm_rig.impact_material)
	bob = 0
	var index: int = Frames.DIRECTIONS.find(facing)
	sprite_piece(head,Frames.IDLE_SHEET,Regions.IDLE[index],-47,-22)
	torso_piece(index)
	for sprite in [head,torso]:
		sprite.position = transform*sprite.position
		sprite.rotation = transform.get_rotation()
		sprite.modulate = Color.WHITE
	legs.modulate = Color.WHITE
	legs.pose(game.player,facing,0,0,0,game.movement.heading,transform)
	game.character.hide()
	game.arm_rig.modulate = Color.WHITE
	show()
	clothing.update_pose(game,self)

func apply_locomotion() -> void:
	if not active() or (game.locomotion.crouch == 0 and not game.locomotion.airborne() and not game.locomotion.sliding()):
		return
	var transform: Transform2D = game.locomotion.torso_transform(game.player,facing)
	for sprite in [head,torso]:
		sprite.position = transform*sprite.position
		sprite.rotation += transform.get_rotation()
	game.arm_rig.position = transform*game.arm_rig.position
	game.arm_rig.rotation += transform.get_rotation()
	var hips := transform
	var amplitude := stride_amplitude if was_walking else 0.0
	var leg_bob := bob
	if game.working:
		hips *= Motion.torso_transform(game.player,facing,clampf(game.work_elapsed/game.work_duration,0,1),game.bag.held_id(),game.arm_rig.impact_material)
		leg_bob = 0
	if game.locomotion.sliding() or game.locomotion.airborne():
		amplitude = 0
	legs.pose(game.player,facing,phase,amplitude,leg_bob,game.movement.heading,hips,game.locomotion.height())
	clothing.update_pose(game,self)
