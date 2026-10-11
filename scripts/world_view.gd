extends Node2D
const PROP_SHEET = preload("res://assets/environment/quarantine_props.png")
const GROUND_SHADER = preload("res://shaders/quarantine_ground.gdshader")
var world
var prop_textures: Array[AtlasTexture] = []
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
	ground = Polygon2D.new()
	ground.z_index = -1
	ground.polygon = PackedVector2Array([world.bounds.position, Vector2(world.bounds.end.x, world.bounds.position.y), world.bounds.end, Vector2(world.bounds.position.x, world.bounds.end.y)])
	ground.uv = PackedVector2Array([Vector2.ZERO, Vector2(1, 0), Vector2.ONE, Vector2(0, 1)])
	ground_material = ShaderMaterial.new()
	ground_material.shader = GROUND_SHADER
	ground_material.set_shader_parameter("map_size", world.bounds.size)
	ground_material.set_shader_parameter("map_origin", world.bounds.position)
	ground.material = ground_material
	add_child(ground)
	refresh_ground()
	queue_redraw()

func refresh_ground() -> void:
	ground_material.set_shader_parameter("map_seed", float(world.seed_value))
	var rng := RandomNumberGenerator.new()
	rng.seed = world.seed_value
	scuffs.clear()
	for i in 32:
		var start := Vector2(rng.randf_range(world.bounds.position.x + 100, world.bounds.end.x - 100), rng.randf_range(world.bounds.position.y + 100, world.bounds.end.y - 100)).snapped(Vector2(3, 3))
		if start.length() < 100:
			continue
		var middle := start + Vector2(rng.randi_range(3, 8) * 3, 0)
		var end := middle + Vector2(0, rng.randi_range(2, 4) * 3)
		scuffs.append(PackedVector2Array([start, middle, end]))
	queue_redraw()

func _draw() -> void:
	if world == null:
		return
	# Four continuous wall strips; the ground never exposes the navigation grid.
	var edge: Rect2 = world.bounds
	draw_rect(Rect2(edge.position, Vector2(edge.size.x, 64)), Color("363942"))
	draw_rect(Rect2(edge.position + Vector2(0, edge.size.y - 64), Vector2(edge.size.x, 64)), Color("363942"))
	draw_rect(Rect2(edge.position, Vector2(64, edge.size.y)), Color("363942"))
	draw_rect(Rect2(edge.position + Vector2(edge.size.x - 64, 0), Vector2(64, edge.size.y)), Color("363942"))
	draw_rect(edge.grow(-64), Color("181b22"), false, 4)
	for scuff in scuffs:
		draw_polyline(scuff, Color("1d2026"), 3, false)
	# Small landing-pad corner marks instead of a contrasting square tile.
	for corner in [Vector2(-48, -48), Vector2(48, -48), Vector2(-48, 48), Vector2(48, 48)]:
		var inward: Vector2 = -corner.sign()
		draw_line(corner, corner + Vector2(inward.x * 12, 0), Color("65604b"), 3)
		draw_line(corner, corner + Vector2(0, inward.y * 12), Color("65604b"), 3)
	for cell in world.props:
		var kind: int = world.props[cell]
		var large: bool = world.large_rocks.has(cell)
		var center: Vector2 = world.center(cell) + (Vector2(32, 32) if large else Vector2.ZERO)
		if kind == 3:
			draw_rect(Rect2(center - Vector2(44, 44), Vector2(88, 88)), Color(0.5, 0.08, 0.09, 0.025))
			draw_rect(Rect2(center - Vector2(24, 24), Vector2(48, 48)), Color(0.5, 0.08, 0.09, 0.04))
		var shadow_width := 116.0 if large else 56.0
		draw_rect(Rect2(center + Vector2(-shadow_width / 2, 8), Vector2(shadow_width, 20)), Color(0, 0, 0, 0.25))
		var texture := prop_textures[kind]
		var width := 124.0 if large else (92.0 if kind == 2 else 64.0)
		var height := minf(144.0, width * texture.get_height() / texture.get_width())
		draw_texture_rect(texture, Rect2(center + Vector2(-width / 2, (60 if large else 26) - height), Vector2(width, height)), false, Color(0.78, 0.78, 0.78))
