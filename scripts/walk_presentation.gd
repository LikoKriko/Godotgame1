extends Node2D
## Fixed original head, independent upper body, articulated arms/legs and soft stop.
const Frames = preload("res://scripts/survivor_frames.gd")
const Regions = preload("res://assets/characters/survivor_regions.gd")
const STOP_SECONDS := 0.18
var game
var head: Sprite2D
var torso: Sprite2D
var legs: Node2D
var was_walking := false
var stopping := false
var stop_elapsed := 0.0
var phase := 0.0
var bob := 0.0
var facing: StringName = &"down"
var opacity := 1.0
var textures: Dictionary = {}

func configure(owner_game) -> void:
	game = owner_game
	legs = preload("res://scripts/leg_rig.gd").new()
	add_child(legs)
	torso = Sprite2D.new()
	head = Sprite2D.new()
	for sprite in [torso,head]:
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
	hide()

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
	sprite.position = game.player+Vector2((data[0]-data[4])*factor,-47+start*factor+bob)

func active() -> bool:
	return visible

func cancel() -> void:
	hide()
	was_walking = false
	stopping = false
	game.character.show()
	game.character.modulate = Color.WHITE
	game.arm_rig.modulate = Color.WHITE

func update_pose(delta: float) -> void:
	if game.working or game.equipping or game.movement.is_turning():
		cancel()
		return
	var walking: bool = game.character.animation.begins_with("walk_")
	if walking:
		facing = game.movement.facing()
		phase = (game.character.frame+game.character.frame_progress)/4.0
		stop_elapsed = 0
		stopping = false
		was_walking = true
		game.character.hide()
		opacity = 1.0
	elif was_walking:
		stopping = true
		stop_elapsed += maxf(0,delta)
		var blend := smoothstep(0,STOP_SECONDS,stop_elapsed)
		opacity = 1-blend
		game.character.show()
		game.character.modulate = Color(1,1,1,blend)
		if stop_elapsed >= STOP_SECONDS:
			cancel()
			return
	else:
		cancel()
		return
	bob = -0.65*(1-cos(phase*4*PI))*opacity
	var index: int = Frames.DIRECTIONS.find(facing)
	sprite_piece(head,Frames.IDLE_SHEET,Regions.IDLE[index],-47,-22)
	sprite_piece(torso,Frames.BODY_SHEET,Regions.BODY[index],-22,1.5)
	for sprite in [head,torso,legs]:
		sprite.modulate = Color(1,1,1,opacity)
	legs.pose(game.player,facing,phase,opacity,bob)
	game.arm_rig.gait(game.player+Vector2(0,bob),facing,game.bag.held_id(),phase,opacity)
	game.arm_rig.modulate = Color(1,1,1,opacity)
	game.held_tool.hide()
	show()
