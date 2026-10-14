extends Node2D
const Mask = preload("res://scripts/character_shadow_mask.gd")
var game
var shadow_material: ShaderMaterial
var direction := Vector2.RIGHT
var stretch := 1.0
var strength := 0.0
var textures: Dictionary = {}
var prop_masks: Dictionary = {}
var mask_viewport: SubViewport
var mask: Node2D
var avatar: Node2D
var enemy_projection: Node2D
var extra_projections: Array[Node2D] = []
var colored_avatar: Sprite2D
var last_direction := Vector2.INF
var last_stretch := INF
var last_camera := Vector2.INF
var last_prop_count := -1
var had_impulses := false
var prop_redraws := 0

class AvatarVisual:
	extends Sprite2D
	var game
	func _process(_delta: float) -> void:
		position = game.player+Vector2(0,17-game.ground_height)-Mask.ORIGIN/Mask.SCALE

class AvatarProjection:
	extends Node2D
	var host
	func _draw() -> void:
		var feet: Vector2 = host.game.player+Vector2(0,17-host.game.ground_height)
		draw_set_transform_matrix(host.projection(feet))
		var rect := Rect2(feet-Mask.ORIGIN/Mask.SCALE,Vector2(Mask.SIZE)/Mask.SCALE)
		draw_texture_rect(host.mask_viewport.get_texture(),rect,false)
		draw_set_transform_matrix(Transform2D.IDENTITY)

class EnemyProjection:
	extends Node2D
	var host
	var target
	func _draw() -> void:
		var enemy = target if target != null else host.game.enemies.enemy
		if not is_instance_valid(enemy) or enemy.health <= 0 or enemy.sprite.texture == null: return
		var atlas: AtlasTexture = enemy.sprite.texture
		var size: Vector2 = atlas.atlas.get_size()
		var a := atlas.region.position/size; var b := atlas.region.end/size
		material.set_shader_parameter("uv_rect",Vector4(a.x,a.y,b.x,b.y))
		material.set_shader_parameter("foot_uv_y",enemy.clips.foot[1]/enemy.clips.canvas[1])
		var feet: Vector2 = enemy.position+Vector2(0,17-enemy.ground_height)
		draw_set_transform_matrix(host.projection(feet)*enemy.sprite.global_transform)
		draw_texture_rect(atlas,Rect2(-atlas.get_size()/2,atlas.get_size()),false)
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
	# Reuse the silhouette target for a high-resolution colored avatar.
	# The complete sprite source is excluded from the main canvas.
	game.get_viewport().canvas_cull_mask &= ~(1 << 19)
	colored_avatar = AvatarVisual.new()
	colored_avatar.game = game
	colored_avatar.texture = mask_viewport.get_texture()
	colored_avatar.centered = false
	colored_avatar.scale = Vector2.ONE/Mask.SCALE
	colored_avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	game.add_child(colored_avatar)
	avatar = AvatarProjection.new()
	avatar.host = self
	avatar.material = shadow_material.duplicate()
	avatar.material.set_shader_parameter("foot_uv_y",Mask.ORIGIN.y/Mask.SIZE.y)
	add_child(avatar)
	enemy_projection = EnemyProjection.new(); enemy_projection.host = self
	enemy_projection.material = shadow_material.duplicate(); add_child(enemy_projection)

func update_sun(state: Dictionary) -> void:
	direction = state["direction"]
	stretch = state["stretch"]
	strength = state["shadow_alpha"]
	var softness := lerpf(1.45,0.75,float(state["elevation"]))
	for shader_material in [shadow_material,avatar.material,enemy_projection.material]:
		shader_material.set_shader_parameter("opacity",strength)
		shader_material.set_shader_parameter("softness",softness)
	for node in extra_projections.duplicate():
		if not is_instance_valid(node.target) or node.target.health <= 0:
			extra_projections.erase(node); node.queue_free(); continue
		node.material.set_shader_parameter("opacity",strength)
		node.material.set_shader_parameter("softness",softness); node.queue_redraw()
	visible = strength > 0.001
	avatar.queue_redraw()
	enemy_projection.queue_redraw()
	var camera_position: Vector2 = game.camera.get_screen_center_position()
	var impacts: bool = not game.world_view.impulses.is_empty()
	var object_count: int = game.world.props.size()+(game.workbenches.tables.size() if game.workbenches != null else 0)
	if direction.distance_to(last_direction) > 0.00025 or absf(stretch-last_stretch) > 0.001 or camera_position.distance_to(last_camera) > 64 or object_count != last_prop_count or impacts or had_impulses:
		last_direction = direction
		last_stretch = stretch
		last_camera = camera_position
		last_prop_count = object_count
		had_impulses = impacts
		prop_redraws += 1
		queue_redraw()

func projection(base: Vector2) -> Transform2D:
	var vertical := -direction*stretch
	return Transform2D(Vector2(1,0),vertical,base-Vector2(base.x,0)-vertical*base.y)

func standalone(texture: Texture2D) -> Texture2D:
	# Isolate the crop so soft edges cannot sample neighbouring atlas sprites.
	var key := texture.get_instance_id()
	if not textures.has(key):
		if textures.size() >= 512: textures.clear()
		var pixels: Image = texture.atlas.get_image().get_region(Rect2i(texture.region)) if texture is AtlasTexture else texture.get_image()
		textures[key] = ImageTexture.create_from_image(pixels)
	return textures[key]

# The visible trunk/stone, rather than the collision footprint or padded bitmap,
# defines the contact row. Cache each raster so this never scans pixels per frame.
static func contact_row(pixels: Image, _kind: int) -> int:
	# The final visible raster row is authoritative. Colour-based guesses omit
	# dark roots, contours and earth-colored stone bases and leave a visible gap.
	for y in range(pixels.get_height()-1,-1,-1):
		for x in pixels.get_width():
			if pixels.get_pixel(x,y).a > 0.05: return y
	return pixels.get_height()-1

func shadow_info(texture: Texture2D, kind: int) -> Dictionary:
	var key := "%d:%d" % [texture.get_instance_id(),kind]
	if not prop_masks.has(key):
		if prop_masks.size() >= 512: prop_masks.clear()
		var pixels: Image = standalone(texture).get_image()
		var height := contact_row(pixels,kind)+1
		var cropped := pixels.get_region(Rect2i(0,0,pixels.get_width(),height))
		prop_masks[key] = {"texture":ImageTexture.create_from_image(cropped),"fraction":height/float(pixels.get_height())}
	return prop_masks[key]

func prop_geometry(cell: Vector2i) -> Dictionary:
	var view: Node2D = game.world_view
	var data: Dictionary = view.presentation(cell)
	var info := shadow_info(data["texture"],game.world.props[cell])
	var texture: Texture2D = info["texture"]
	var rect: Rect2 = data["rect"]
	rect.size.y *= info["fraction"]
	if view.tree_sprites.has(cell):
		var sprite_transform: Transform2D = view.tree_sprites[cell].global_transform
		var foot := Vector2(texture.get_width()/2.0,texture.get_height())
		return {"texture":texture,"rect":Rect2(Vector2.ZERO,texture.get_size()),"transform":sprite_transform,"base":sprite_transform*foot}
	rect.position += view.offset_for(cell)
	return {"texture":texture,"rect":rect,"transform":Transform2D.IDENTITY,"base":Vector2(rect.get_center().x,rect.end.y)}

func _draw() -> void:
	if game == null or strength <= 0.001: return
	var view: Node2D = game.world_view
	var viewport_world := Rect2(game.camera.get_screen_center_position()-game.get_viewport_rect().size/game.camera.zoom/2,game.get_viewport_rect().size/game.camera.zoom).grow(850)
	if game.hut != null and game.hut.inside: return
	for cell in game.world.props:
		if not viewport_world.intersects(view.presentation(cell)["rect"]): continue
		var data := prop_geometry(cell)
		draw_set_transform_matrix(projection(data["base"])*data["transform"])
		draw_texture_rect(data["texture"],data["rect"],false)
	if game.hut != null and game.hut.exterior.visible:
		var sprite: Sprite2D = game.hut.exterior
		var info := shadow_info(sprite.texture,2)
		var texture: Texture2D = info.texture
		var sprite_transform := sprite.global_transform
		var base := sprite_transform*Vector2(texture.get_width()/2.0,texture.get_height())
		draw_set_transform_matrix(projection(base)*sprite_transform)
		draw_texture_rect(texture,Rect2(Vector2.ZERO,texture.get_size()),false)
	if game.workbenches != null:
		for table in game.workbenches.tables:
			var sprite: Sprite2D = table.sprite
			var info := shadow_info(sprite.texture,6)
			var texture: Texture2D = info.texture
			var sprite_transform := sprite.global_transform
			var base := sprite_transform*Vector2(texture.get_width()/2.0,texture.get_height())
			draw_set_transform_matrix(projection(base)*sprite_transform)
			draw_texture_rect(texture,Rect2(Vector2.ZERO,texture.get_size()),false)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func add_enemy_projection(creature: Node2D) -> void:
	var node := EnemyProjection.new(); node.host = self; node.target = creature
	node.material = shadow_material.duplicate(); add_child(node); extra_projections.append(node)
