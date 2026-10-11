extends Node2D
const PROP_SHEET = preload("res://assets/environment/quarantine_props.png")
const FOREST_SHEET = preload("res://assets/environment/basic_forest_props.png")
const GROUND_SHADER = preload("res://shaders/quarantine_ground.gdshader")
var world
var prop_textures: Array[AtlasTexture] = []
var forest_textures: Array[AtlasTexture] = []
var ground: Polygon2D
var ground_material: ShaderMaterial
var scuffs: Array[PackedVector2Array] = []

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
	var forest_image := FOREST_SHEET.get_image()
	# The shared transparent gap lies below the larger tree's roots.
	var regions := [
		Rect2i(0, 0, 650, 676),
		Rect2i(658, 280, forest_image.get_width() - 658, 396),
		Rect2i(0, 676, 640, forest_image.get_height() - 676),
		Rect2i(640, 676, forest_image.get_width() - 640, forest_image.get_height() - 676)
	]
	for i in 4:
		var cell: Rect2i = regions[i]
		var used := forest_image.get_region(cell).get_used_rect()
		var atlas := AtlasTexture.new()
		atlas.atlas = FOREST_SHEET
		atlas.region = Rect2(cell.position + used.position, used.size)
		forest_textures.append(atlas)
	ground = Polygon2D.new()
	ground.z_index = -1
	ground.polygon = PackedVector2Array([world.bounds.position, Vector2(world.bounds.end.x, world.bounds.position.y), world.bounds.end, Vector2(world.bounds.position.x, world.bounds.end.y)])
	ground_material = ShaderMaterial.new()
	ground_material.shader = GROUND_SHADER
	ground.material = ground_material
	add_child(ground)
	refresh_ground()
	queue_redraw()

func refresh_ground() -> void:
	ground_material.set_shader_parameter("map_seed", float(world.seed_value))
	var rng := RandomNumberGenerator.new()
	rng.seed = world.seed_value
	scuffs.clear()
	for i in world.SIZE.x * world.SIZE.y / 24:
		var start := Vector2(rng.randf_range(world.bounds.position.x + 100, world.bounds.end.x - 100), rng.randf_range(world.bounds.position.y + 100, world.bounds.end.y - 100)).snapped(Vector2(3, 3))
		if start.length() < 100:
			continue
		var middle := start + Vector2(rng.randi_range(3, 8) * 3, rng.randi_range(-2, 2) * 3)
		var end := middle + Vector2(rng.randi_range(2, 4) * 3, rng.randi_range(-1, 1) * 3)
		scuffs.append(PackedVector2Array([start, middle, end]))
	queue_redraw()

func _draw() -> void:
	if world == null:
		return
	# A dark mossy perimeter marks the compact test area's collision boundary.
	var edge: Rect2 = world.bounds
	draw_rect(Rect2(edge.position, Vector2(edge.size.x, 64)), Color("3b4433"))
	draw_rect(Rect2(edge.position + Vector2(0, edge.size.y - 64), Vector2(edge.size.x, 64)), Color("3b4433"))
	draw_rect(Rect2(edge.position, Vector2(64, edge.size.y)), Color("3b4433"))
	draw_rect(Rect2(edge.position + Vector2(edge.size.x - 64, 0), Vector2(64, edge.size.y)), Color("3b4433"))
	for scuff in scuffs:
		draw_polyline(scuff, Color("444637"), 2, false)
	for cell in world.props:
		var kind: int = world.props[cell]
		var large: bool = world.large_rocks.has(cell)
		var center: Vector2 = world.center(cell) + (Vector2(32, 32) if large else Vector2.ZERO)
		var shadow_width := 116.0 if large else 56.0
		draw_set_transform(center + Vector2(0, 18), 0, Vector2(1, 0.3))
		draw_circle(Vector2.ZERO, shadow_width / 2, Color(0.06, 0.08, 0.04, 0.22))
		draw_set_transform(Vector2.ZERO)
		var texture := prop_textures[kind]
		if kind in [1, 2]:
			var variant: int = world.cells[cell]["variant"] % 2
			texture = forest_textures[(0 if kind == 2 else 1) + variant * 2]
		var width := 124.0 if large else 64.0
		var height := width * texture.get_height() / texture.get_width()
		if kind == 2:
			height = 142.0
			width = height * texture.get_width() / texture.get_height()
		var tint := Color.WHITE if kind in [1, 2] else Color(0.75, 0.75, 0.75)
		draw_texture_rect(texture, Rect2(center + Vector2(-width / 2, (60 if large else 26) - height), Vector2(width, height)), false, tint)
