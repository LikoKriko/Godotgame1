extends Node2D
const Tools = preload("res://scripts/tool_sprites.gd")
var game
var shadow_material: ShaderMaterial
var direction := Vector2.RIGHT
var stretch := 1.0
var strength := 0.0
var body_textures: Dictionary = {}

func configure(owner_game) -> void:
	game = owner_game
	z_index = -9
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow_material = ShaderMaterial.new()
	shadow_material.shader = preload("res://shaders/silhouette_shadow.gdshader")
	material = shadow_material

func update_sun(state: Dictionary) -> void:
	direction = state["direction"]
	stretch = state["stretch"]
	strength = state["shadow_alpha"]
	shadow_material.set_shader_parameter("opacity",strength)
	visible = strength > 0.001
	queue_redraw()

func projection(base: Vector2) -> Transform2D:
	# Upright sprite height is projected away from the sun onto the ground.
	# Keep the feet/trunk fixed while the silhouette rotates and changes length.
	var vertical := -direction*stretch
	return Transform2D(Vector2(1,0),vertical,base-Vector2(base.x,0)-vertical*base.y)

func draw_sprite(sprite, base: Vector2) -> void:
	var texture: Texture2D
	var rect: Rect2
	if sprite is AnimatedSprite2D:
		texture = sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
		rect = Rect2(-texture.get_size()/2,texture.get_size())
	else:
		texture = sprite.texture
		rect = Rect2(-texture.get_size()/2 if sprite.centered else Vector2.ZERO,texture.get_size())
	draw_set_transform_matrix(projection(base)*sprite.global_transform)
	draw_texture_rect(texture,rect,false)

func _draw() -> void:
	if game == null or strength <= 0.001:
		return
	var view: Node2D = game.world_view
	var viewport_world := Rect2(game.camera.get_screen_center_position()-game.get_viewport_rect().size/game.camera.zoom/2,game.get_viewport_rect().size/game.camera.zoom).grow(600)
	for cell in game.world.props:
		var data: Dictionary = view.presentation(cell)
		var rect: Rect2 = data["rect"]
		if not viewport_world.intersects(rect):
			continue
		var base := Vector2(rect.get_center().x,rect.end.y)
		if view.tree_sprites.has(cell):
			draw_sprite(view.tree_sprites[cell],base)
		else:
			var displaced: Rect2 = rect
			displaced.position += view.offset_for(cell)
			draw_set_transform_matrix(projection(base))
			draw_texture_rect(data["texture"],displaced,false)
	var feet: Vector2 = game.player+Vector2(0,17)
	if game.gait.active() and game.gait.opacity > 0.5:
		draw_sprite(game.gait.head,feet)
		draw_sprite(game.gait.torso,feet)
		var leg_rig = game.gait.legs
		for part in leg_rig.thighs+leg_rig.shins+leg_rig.feet:
			var uv := PackedVector2Array()
			for point in part.uv:
				uv.append(point/part.texture.get_size())
			draw_set_transform_matrix(projection(feet)*part.global_transform)
			draw_polygon(part.polygon,PackedColorArray([Color.WHITE]),uv,part.texture)
	elif game.original_head.visible:
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
		var position: Vector2 = game.player+Vector2((data[0]-data[4])*factor,-47+start*factor)
		draw_set_transform_matrix(projection(feet)*Transform2D(0,Vector2.ONE*factor,0,position))
		var texture: Texture2D = body_textures[facing]
		draw_texture_rect(texture,Rect2(Vector2.ZERO,texture.get_size()),false)
		draw_sprite(game.original_head,feet)
	else:
		draw_sprite(game.character,feet)
	if game.arm_rig.visible:
		for limb in game.arm_rig.layers:
			var transform: Transform2D = projection(feet)*limb.global_transform
			for part in [limb.upper,limb.lower]:
				var uv := PackedVector2Array()
				for point in part.uv:
					uv.append(point/part.texture.get_size())
				draw_set_transform_matrix(transform)
				draw_polygon(part.polygon,PackedColorArray([Color.WHITE]),uv,part.texture)
			if limb.tool != &"":
				Tools.draw(self,limb.tool,limb.hand,limb.tip,limb.source_index == 0,transform)
	elif game.held_tool.visible:
		var held = game.held_tool
		Tools.draw(self,held.item,held.hand,held.tip,held.mirrored,projection(feet)*held.global_transform)
	draw_set_transform_matrix(Transform2D.IDENTITY)
