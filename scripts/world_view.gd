extends Node2D
const PROP_SHEET = preload("res://assets/environment/quarantine_props.png")
const FLOOR_SHEET = preload("res://assets/environment/quarantine_floors.png")
var world
var prop_textures: Array[AtlasTexture] = []
var floor_textures: Array[AtlasTexture] = []

func configure(map) -> void:
	world = map
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -10
	var image := PROP_SHEET.get_image()
	var half := Vector2i(image.get_width() / 2, image.get_height() / 2)
	for i in 4:
		var cell := Rect2i(Vector2i(i % 2, i / 2) * half, half)
		var used := image.get_region(cell).get_used_rect()
		var atlas := AtlasTexture.new()
		atlas.atlas = PROP_SHEET
		atlas.region = Rect2(cell.position + used.position, used.size)
		prop_textures.append(atlas)
	var floor_half := Vector2i(FLOOR_SHEET.get_width() / 2, FLOOR_SHEET.get_height() / 2)
	for i in 4:
		var texture := AtlasTexture.new()
		texture.atlas = FLOOR_SHEET
		texture.region = Rect2(Vector2i(i % 2, i / 2) * floor_half, floor_half)
		floor_textures.append(texture)
	queue_redraw()

func _draw() -> void:
	if world == null:
		return
	draw_rect(world.bounds.grow(2000), Color("101219"))
	for cell in world.cells:
		var data: Dictionary = world.cells[cell]
		var origin := Vector2(cell * world.TILE)
		var rect := Rect2(origin, Vector2(64, 64))
		var is_border: bool = cell.x == world.FIRST.x or cell.x == world.FIRST.x + world.SIZE.x - 1 or cell.y == world.FIRST.y or cell.y == world.FIRST.y + world.SIZE.y - 1
		if is_border:
			draw_rect(rect, Color("191d26"))
			draw_rect(Rect2(origin + Vector2(4, 4), Vector2(56, 44)), Color("424652"))
			draw_rect(Rect2(origin + Vector2(4, 48), Vector2(56, 10)), Color("242832"))
			draw_rect(Rect2(origin + Vector2(8, 8), Vector2(48, 3)), Color("61616a"))
			for i in 4:
				draw_rect(Rect2(origin + Vector2(8 + i * 12, 52), Vector2(6, 4)), Color("b89a45"))
			continue
		var tile: int = 3 if data["road"] else data["zone"]
		var variant: int = data["variant"]
		var shade := 0.82 + variant * 0.015
		draw_set_transform(origin + Vector2(32, 32), (variant % 4) * PI / 2)
		draw_texture_rect(floor_textures[tile], Rect2(-32, -32, 64, 64), false, Color(shade, shade, shade))
		draw_set_transform(Vector2.ZERO)
	# Central landing platform; clear space, readable yellow industrial accents.
	draw_rect(Rect2(-64, -64, 128, 128), Color("484a51"))
	draw_rect(Rect2(-58, -58, 116, 116), Color("8c793b"), false, 4)
	draw_rect(Rect2(-22, -22, 44, 44), Color("242935"))
	for cell in world.props:
		var kind: int = world.props[cell]
		var center: Vector2 = world.center(cell)
		if kind == 3:
			draw_rect(Rect2(center - Vector2(44, 44), Vector2(88, 88)), Color(0.75, 0.04, 0.08, 0.035))
			draw_rect(Rect2(center - Vector2(24, 24), Vector2(48, 48)), Color(0.8, 0.06, 0.09, 0.06))
		draw_rect(Rect2(center + Vector2(-28, 8), Vector2(56, 20)), Color(0, 0, 0, 0.32))
		var texture := prop_textures[kind]
		var width := 64.0 if kind != 2 else 76.0
		var height := minf(88.0, width * texture.get_height() / texture.get_width())
		draw_texture_rect(texture, Rect2(center + Vector2(-width / 2, 26 - height), Vector2(width, height)), false)
