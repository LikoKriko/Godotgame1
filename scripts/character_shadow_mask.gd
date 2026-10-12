extends Node2D
## Compose the visible avatar once; projection then applies one shadow opacity.
const Tools = preload("res://scripts/tool_sprites.gd")
const SIZE := Vector2i(384,384)
const SCALE := 3.0
const ORIGIN := Vector2(192,270)
var game
var uv_cache: Dictionary = {}
var source_transform := Transform2D.IDENTITY
var initialized := false

func configure(owner_game) -> void:
	game = owner_game
	position = ORIGIN
	scale = Vector2.ONE*SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(_delta: float) -> void:
	if initialized and game.has_method("is_paused") and game.is_paused():
		get_viewport().render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	get_viewport().render_target_update_mode = SubViewport.UPDATE_ALWAYS
	initialized = true
	queue_redraw()

func draw_sprite(sprite) -> void:
	var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame) if sprite is AnimatedSprite2D else sprite.texture
	var rect := Rect2(-texture.get_size()/2 if sprite.centered else Vector2.ZERO,texture.get_size())
	draw_set_transform_matrix(source_transform*sprite.global_transform)
	draw_texture_rect(texture,rect,false,Color(1,1,1,sprite.modulate.a))

func draw_part(part: Polygon2D, alpha: float) -> void:
	var key := part.get_instance_id()
	if not uv_cache.has(key) or uv_cache[key]["source"] != part.uv:
		var uv := PackedVector2Array()
		for point in part.uv:
			uv.append(point/part.texture.get_size())
		uv_cache[key] = {"source":part.uv,"uv":uv}
	draw_set_transform_matrix(source_transform*part.global_transform)
	draw_polygon(part.polygon,PackedColorArray([Color(1,1,1,alpha)]),uv_cache[key]["uv"],part.texture)

func draw_tool(limb) -> void:
	Tools.draw(self,limb.tool,limb.hand,limb.tip,limb.source_index == 0,source_transform*limb.global_transform,Color(1,1,1,game.arm_rig.modulate.a))

func draw_arm(limb) -> void:
	for part in [limb.upper,limb.lower]:
		draw_part(part,game.arm_rig.modulate.a)
	draw_sprite(limb.elbow_patch)

func _draw() -> void:
	if game == null: return
	source_transform = Transform2D(0,-game.player-Vector2(0,17))*game.global_transform.affine_inverse()
	if game.full_avatar != null and game.full_avatar.visible:
		draw_sprite(game.full_avatar)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	if game.arm_rig.visible:
		for limb in game.arm_rig.layers:
			if limb.tool != &"" and limb.tool_layer.z_index < 0: draw_tool(limb)
		for limb in game.arm_rig.layers:
			if limb.z_index < 0: draw_arm(limb)
	if game.character.visible:
		draw_sprite(game.character)
	if game.gait.active():
		var legs = game.gait.legs
		var clothes = game.gait.clothing
		for part in legs.thighs+legs.shins+legs.feet:
			if part.z_index < 0: draw_part(part,game.gait.opacity)
		for part in clothes.trousers:
			if part.z_index < 0: draw_part(part,game.gait.opacity)
		draw_part(game.gait.torso,game.gait.opacity)
		for part in legs.thighs+legs.shins+legs.feet:
			if part.z_index >= 0: draw_part(part,game.gait.opacity)
		draw_part(clothes.waist,game.gait.opacity)
		for part in clothes.trousers:
			if part.z_index >= 0: draw_part(part,game.gait.opacity)
		draw_set_transform_matrix(source_transform*clothes.global_transform)
		clothes.draw_details(self)
		draw_sprite(game.gait.head)
	if game.arm_rig.visible:
		for limb in game.arm_rig.layers:
			if limb.tool != &"" and limb.tool_layer.z_index >= 0: draw_tool(limb)
		for limb in game.arm_rig.layers:
			if limb.z_index >= 0: draw_arm(limb)
	draw_set_transform_matrix(Transform2D.IDENTITY)
