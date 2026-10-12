extends Node2D
## Compose the visible avatar once; projection then applies one shadow opacity.
const Tools = preload("res://scripts/tool_sprites.gd")
const SIZE := Vector2i(256,256)
const SCALE := 2.0
const ORIGIN := Vector2(128,180)
var game
var body_textures: Dictionary = {}
var source_transform := Transform2D.IDENTITY

func configure(owner_game) -> void:
	game = owner_game
	position = ORIGIN
	scale = Vector2.ONE*SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func draw_sprite(sprite) -> void:
	var texture: Texture2D
	if sprite is AnimatedSprite2D:
		texture = sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
	else:
		texture = sprite.texture
	var rect := Rect2(-texture.get_size()/2 if sprite.centered else Vector2.ZERO,texture.get_size())
	draw_set_transform_matrix(source_transform*sprite.global_transform)
	draw_texture_rect(texture,rect,false,Color(1,1,1,sprite.modulate.a))

func draw_part(part: Polygon2D, alpha: float) -> void:
	var uv := PackedVector2Array()
	for point in part.uv:
		uv.append(point/part.texture.get_size())
	draw_set_transform_matrix(source_transform*part.global_transform)
	draw_polygon(part.polygon,PackedColorArray([Color(1,1,1,alpha)]),uv,part.texture)

func draw_work_body() -> void:
	var facing: StringName = StringName(str(game.character.animation).trim_prefix("work_"))
	var frames = preload("res://scripts/survivor_frames.gd")
	var data: Array = preload("res://assets/characters/survivor_regions.gd").BODY[frames.DIRECTIONS.find(facing)]
	var factor: float = 64.0/data[3]
	var start := floori(25/factor)
	if not body_textures.has(facing):
		var texture := AtlasTexture.new()
		texture.atlas = frames.BODY_SHEET
		texture.region = Rect2(data[0],data[1]+start,data[2],data[3]-start)
		body_textures[facing] = texture
	var origin: Vector2 = game.player+Vector2((data[0]-data[4])*factor,-47+start*factor)
	draw_set_transform_matrix(source_transform*Transform2D(0,Vector2.ONE*factor,0,origin))
	var texture: Texture2D = body_textures[facing]
	draw_texture_rect(texture,Rect2(Vector2.ZERO,texture.get_size()),false,Color(1,1,1,game.character.modulate.a))

func _draw() -> void:
	if game == null:
		return
	source_transform = Transform2D(0,-game.player-Vector2(0,17))
	if game.character.visible:
		if game.original_head.visible:
			draw_work_body()
		else:
			draw_sprite(game.character)
	if game.original_head.visible:
		draw_sprite(game.original_head)
	if game.gait.active():
		var legs = game.gait.legs
		for part in legs.thighs+legs.shins+legs.feet:
			draw_part(part,game.gait.opacity)
		draw_sprite(game.gait.torso)
		draw_sprite(game.gait.head)
	if game.arm_rig.visible:
		for limb in game.arm_rig.layers:
			for part in [limb.upper,limb.lower]:
				draw_part(part,game.arm_rig.modulate.a)
			if limb.tool != &"":
				Tools.draw(self,limb.tool,limb.hand,limb.tip,limb.source_index == 0,source_transform*limb.global_transform,Color(1,1,1,game.arm_rig.modulate.a))
	elif game.held_tool.visible:
		var held = game.held_tool
		var transform: Transform2D = source_transform*held.global_transform
		Tools.draw(self,held.item,held.hand,held.tip,held.mirrored,transform)
		if held.fist != null:
			draw_set_transform_matrix(transform)
			draw_texture_rect(held.fist,Rect2(held.hand-held.fist_size/2,held.fist_size),false)
	draw_set_transform_matrix(Transform2D.IDENTITY)
