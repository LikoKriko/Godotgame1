extends Node2D
## Compose the visible avatar once; projection then applies one shadow opacity.
const SIZE := Vector2i(384,384)
const SCALE := 3.0
const ORIGIN := Vector2(192,270)
var game
var source_transform := Transform2D.IDENTITY
var initialized := false

func configure(owner_game) -> void:
	game = owner_game
	position = ORIGIN
	scale = Vector2.ONE*SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

var last_signature: Array = []
var redraws := 0
func _process(_delta: float) -> void:
	if game.full_avatar == null or game.full_avatar.texture == null: return
	var sprite: Sprite2D = game.full_avatar
	var image: AtlasTexture = sprite.texture
	var signature := [image.atlas.get_rid(),image.region,sprite.scale,(sprite.position-game.player).snapped(Vector2(0.001,0.001))]
	if initialized and signature == last_signature:
		get_viewport().render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	last_signature = signature
	initialized = true
	redraws += 1
	get_viewport().render_target_update_mode = SubViewport.UPDATE_ONCE
	queue_redraw()

func draw_sprite(sprite: Sprite2D) -> void:
	var texture: Texture2D = sprite.texture
	var rect := Rect2(-texture.get_size()/2 if sprite.centered else Vector2.ZERO,texture.get_size())
	draw_set_transform_matrix(source_transform*sprite.global_transform)
	draw_texture_rect(texture,rect,false,Color(1,1,1,sprite.modulate.a))

func _draw() -> void:
	if game == null or game.full_avatar == null: return
	source_transform = Transform2D(0,-game.player-Vector2(0,17-game.ground_height))*game.global_transform.affine_inverse()
	draw_sprite(game.full_avatar)
	draw_set_transform_matrix(Transform2D.IDENTITY)
