extends Node2D
const Mask = preload("res://scripts/character_shadow_mask.gd")
var game
var shadow_material: ShaderMaterial
var direction := Vector2.RIGHT
var stretch := 1.0
var strength := 0.0
var textures: Dictionary = {}
var mask_viewport: SubViewport
var mask: Node2D
var avatar: Node2D

class AvatarProjection:
	extends Node2D
	var host
	func _draw() -> void:
		var feet: Vector2 = host.game.player+Vector2(0,17)
		draw_set_transform_matrix(host.projection(feet))
		var rect := Rect2(feet-Mask.ORIGIN/Mask.SCALE,Vector2(Mask.SIZE)/Mask.SCALE)
		draw_texture_rect(host.mask_viewport.get_texture(),rect,false)
		draw_set_transform_matrix(Transform2D.IDENTITY)

func configure(owner_game) -> void:
	game = owner_game
	z_index = -9
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow_material = ShaderMaterial.new()
	shadow_material.shader = preload("res://shaders/silhouette_shadow.gdshader")
	material = shadow_material
	mask_viewport = SubViewport.new()
	mask_viewport.size = Mask.SIZE
	mask_viewport.transparent_bg = true
	mask_viewport.world_2d = World2D.new()
	mask_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	mask_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(mask_viewport)
	mask = Mask.new()
	mask_viewport.add_child(mask)
	mask.configure(game)
	avatar = AvatarProjection.new()
	avatar.host = self
	avatar.material = shadow_material.duplicate()
	avatar.material.set_shader_parameter("foot_uv_y",Mask.ORIGIN.y/Mask.SIZE.y)
	add_child(avatar)

func update_sun(state: Dictionary) -> void:
	direction = state["direction"]
	stretch = state["stretch"]
	strength = state["shadow_alpha"]
	var softness := lerpf(1.45,0.75,float(state["elevation"]))
	for shader_material in [shadow_material,avatar.material]:
		shader_material.set_shader_parameter("opacity",strength)
		shader_material.set_shader_parameter("softness",softness)
	visible = strength > 0.001
	mask_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	mask.queue_redraw()
	avatar.queue_redraw()
	queue_redraw()

func projection(base: Vector2) -> Transform2D:
	var vertical := -direction*stretch
	return Transform2D(Vector2(1,0),vertical,base-Vector2(base.x,0)-vertical*base.y)

func standalone(texture: Texture2D) -> Texture2D:
	# Isolate the crop so soft edges cannot sample neighbouring atlas sprites.
	var key := texture.get_instance_id()
	if not textures.has(key):
		textures[key] = ImageTexture.create_from_image(texture.get_image())
	return textures[key]

func _draw() -> void:
	if game == null or strength <= 0.001:
		return
	var view: Node2D = game.world_view
	var viewport_world := Rect2(game.camera.get_screen_center_position()-game.get_viewport_rect().size/game.camera.zoom/2,game.get_viewport_rect().size/game.camera.zoom).grow(850)
	for cell in game.world.props:
		var data: Dictionary = view.presentation(cell)
		var rect: Rect2 = data["rect"]
		if not viewport_world.intersects(rect):
			continue
		var base := Vector2(rect.get_center().x,rect.end.y)
		var texture: Texture2D = standalone(data["texture"])
		if view.tree_sprites.has(cell):
			var sprite: Sprite2D = view.tree_sprites[cell]
			draw_set_transform_matrix(projection(base)*sprite.global_transform)
			draw_texture_rect(texture,Rect2(Vector2.ZERO,texture.get_size()),false)
		else:
			var displaced: Rect2 = rect
			displaced.position += view.offset_for(cell)
			draw_set_transform_matrix(projection(base))
			draw_texture_rect(texture,displaced,false)
	draw_set_transform_matrix(Transform2D.IDENTITY)
