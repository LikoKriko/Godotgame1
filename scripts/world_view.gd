extends Node2D
const PROP_SHEET = preload("res://assets/environment/quarantine_props.png")
const FOREST_SHEET = preload("res://assets/environment/basic_forest_props.png")
const DETAILS_SHEET = preload("res://assets/environment/forest_details.png")
const DetailRegions = preload("res://assets/environment/forest_details_regions.gd")
const GROUND_SHADER = preload("res://shaders/quarantine_ground.gdshader")
const Nature = preload("res://scripts/nature_variants.gd")
const TREE_FADED_ALPHA := 0.35
var world
var prop_textures: Array[AtlasTexture] = []
var forest_textures: Array[AtlasTexture] = []
var detail_textures: Array[AtlasTexture] = []
var ground: Polygon2D
var ground_material: ShaderMaterial
var scuffs: Array[PackedVector2Array] = []
var tree_sprites: Dictionary = {}
var hit_meshes = preload("res://scripts/hit_meshes.gd").new()
var impulses: Dictionary = {}
var particles: Array[Dictionary] = []

func atlas(sheet: Texture2D, cell: Rect2i, trim: bool = true) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = sheet
	var used := sheet.get_image().get_region(cell).get_used_rect() if trim else Rect2i(Vector2i.ZERO, cell.size)
	texture.region = Rect2(cell.position + used.position, used.size)
	return texture

func configure(map) -> void:
	world = map
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -10
	var half := Vector2i(PROP_SHEET.get_width() / 2, PROP_SHEET.get_height() / 2)
	for i in 4:
		prop_textures.append(atlas(PROP_SHEET, Rect2i(Vector2i(i % 2, i / 2) * half, half)))
	for region in [Rect2i(0,0,650,676), Rect2i(658,280,FOREST_SHEET.get_width()-658,396), Rect2i(0,676,640,FOREST_SHEET.get_height()-676), Rect2i(640,676,FOREST_SHEET.get_width()-640,FOREST_SHEET.get_height()-676)]:
		forest_textures.append(atlas(FOREST_SHEET, region))
	for region in DetailRegions.REGIONS:
		detail_textures.append(atlas(DETAILS_SHEET, region, false))
	hit_meshes.configure(self)
	ground = Polygon2D.new()
	ground.z_index = -1
	ground.polygon = PackedVector2Array([world.bounds.position, Vector2(world.bounds.end.x, world.bounds.position.y), world.bounds.end, Vector2(world.bounds.position.x, world.bounds.end.y)])
	ground_material = ShaderMaterial.new()
	ground_material.shader = GROUND_SHADER
	ground.material = ground_material
	add_child(ground)
	refresh_ground()

func presentation(cell: Vector2i) -> Dictionary:
	var kind: int = world.props[cell]
	var large: bool = world.large_rocks.has(cell)
	var center: Vector2 = world.center(cell) + (Vector2(32,32) if large else Vector2.ZERO)
	var texture: Texture2D = detail_textures[1] if kind == 4 else prop_textures[kind]
	var dimensions := Vector2(64, 64 * texture.get_height() / texture.get_width())
	var tint := Color(0.75,0.75,0.75)
	if kind in [1,2]:
		var variant: int = world.prop_variants[cell]
		var profile := Nature.profile(kind, variant)
		texture = forest_textures[(0 if kind == 2 else 1) + profile["shape"] * 2]
		dimensions = Nature.dimensions(kind, variant, texture.get_size())
		tint = profile["tint"]
	elif kind == 4:
		var height: float = world.saplings[cell]["height"]
		dimensions = Vector2(height * texture.get_width() / texture.get_height(), height)
		tint = world.saplings[cell]["tint"]
	return {"texture": texture, "size": dimensions, "tint": tint, "rect": Rect2(center + Vector2(-dimensions.x/2, (60 if large else 26)-dimensions.y), dimensions)}

func refresh_ground() -> void:
	ground_material.set_shader_parameter("map_seed", float(world.seed_value))
	var rng := RandomNumberGenerator.new()
	rng.seed = world.seed_value
	scuffs.clear()
	impulses.clear()
	particles.clear()
	for i in world.SIZE.x * world.SIZE.y / 24:
		var start := Vector2(rng.randf_range(world.bounds.position.x+100,world.bounds.end.x-100), rng.randf_range(world.bounds.position.y+100,world.bounds.end.y-100)).snapped(Vector2(3,3))
		if start.length() < 100:
			continue
		var middle := start + Vector2(rng.randi_range(3,8)*3, rng.randi_range(-2,2)*3)
		scuffs.append(PackedVector2Array([start,middle,middle+Vector2(rng.randi_range(2,4)*3,rng.randi_range(-1,1)*3)]))
	rebuild_trees()
	queue_redraw()

func rebuild_trees() -> void:
	for sprite in tree_sprites.values():
		remove_child(sprite)
		sprite.queue_free()
	tree_sprites.clear()
	hit_meshes.clear()
	for cell in world.props:
		var data := presentation(cell)
		var texture: Texture2D = data["texture"]
		var rect: Rect2 = data["rect"]
		hit_meshes.add(cell, texture, rect, world.prop_collisions[cell].end.y)
		if world.props[cell] not in [2,4]:
			continue
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.position = rect.position
		sprite.scale = rect.size / texture.get_size()
		sprite.modulate = data["tint"]
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_as_relative = false
		sprite.z_index = -1
		add_child(sprite)
		tree_sprites[cell] = sprite

func register_impact(cell: Vector2i, point: Vector2, direction: Vector2, material: String, strength: float = 1) -> void:
	impulses[cell] = {"time": 0.20, "direction": direction, "strength": strength}
	var tint := Color("95968b") if material == "mineral" else (Color("97a568") if material == "fibra" else Color("b5905c"))
	for i in 5:
		particles.append({"position": point, "velocity": Vector2.from_angle(i*TAU/5-PI/2)*22+Vector2(0,-12), "time": 0.25, "tint": tint})
	queue_redraw()

func impulse_wave(cell: Vector2i) -> float:
	if not impulses.has(cell):
		return 0
	var remaining: float = impulses[cell]["time"] / 0.20
	return sin((1-remaining)*TAU*1.5)*remaining*remaining*impulses[cell]["strength"]

func offset_for(cell: Vector2i) -> Vector2:
	if not impulses.has(cell):
		return Vector2.ZERO
	return impulses[cell]["direction"] * impulse_wave(cell) * 1.6

func update_trees(player: Vector2, delta: float) -> void:
	var had_effects := not impulses.is_empty() or not particles.is_empty()
	for cell in impulses.keys():
		impulses[cell]["time"] -= delta
		if impulses[cell]["time"] <= 0:
			impulses.erase(cell)
	for i in range(particles.size()-1,-1,-1):
		particles[i]["time"] -= delta
		particles[i]["position"] += particles[i]["velocity"] * delta
		particles[i]["velocity"].y += 60 * delta
		if particles[i]["time"] <= 0:
			particles.remove_at(i)
	var character_rect := Rect2(player+Vector2(-28,-53),Vector2(56,76))
	for cell in tree_sprites.keys():
		var sprite: Sprite2D = tree_sprites[cell]
		if not world.props.has(cell):
			remove_child(sprite)
			sprite.queue_free()
			tree_sprites.erase(cell)
			continue
		var rest: Rect2 = hit_meshes.targets[cell]["rest"]
		var base := rest.position + Vector2(rest.size.x/2,rest.size.y)
		var direction := 1.0
		if impulses.has(cell) and absf(impulses[cell]["direction"].x) > 0.1:
			direction = signf(impulses[cell]["direction"].x)
		var rotation := impulse_wave(cell) * (0.065 if world.props[cell] == 4 else 0.025) * direction
		sprite.rotation = rotation
		sprite.position = base - Vector2(rest.size.x/2,rest.size.y).rotated(rotation)
		var behind: bool = player.y+17 < world.prop_collisions[cell].end.y
		var hidden: bool = behind and rest.intersects(character_rect)
		sprite.z_index = 1 if behind else -1
		var alpha := lerpf(sprite.modulate.a,TREE_FADED_ALPHA if hidden else 1.0,1-exp(-delta*12))
		sprite.modulate = presentation(cell)["tint"].lerp(Color.WHITE,absf(impulse_wave(cell))*0.15)
		sprite.modulate.a = alpha
		hit_meshes.set_transform(cell,sprite.position,sprite.rotation,sprite.scale)
	for cell in hit_meshes.targets:
		if world.props.has(cell) and world.props[cell] not in [2,4]:
			var record: Dictionary = hit_meshes.targets[cell]
			var rest: Rect2 = record["rest"]
			hit_meshes.set_transform(cell,rest.position+offset_for(cell),0,rest.size/record["texture_size"])
	if had_effects:
		queue_redraw()

func _draw() -> void:
	if world == null:
		return
	var edge: Rect2 = world.bounds
	for strip in [Rect2(edge.position,Vector2(edge.size.x,64)),Rect2(edge.position+Vector2(0,edge.size.y-64),Vector2(edge.size.x,64)),Rect2(edge.position,Vector2(64,edge.size.y)),Rect2(edge.position+Vector2(edge.size.x-64,0),Vector2(64,edge.size.y))]:
		draw_rect(strip,Color("3b4433"))
	for puddle in world.puddles:
		var texture: Texture2D = detail_textures[3]
		var size := Vector2(puddle["width"],puddle["width"]*texture.get_height()/texture.get_width())
		draw_texture_rect(texture,Rect2(puddle["position"]-size/2,size),false,Color(0.84,0.87,0.85))
	for tuft in world.grass_tufts:
		var texture: Texture2D = detail_textures[0 if tuft["variant"] == 0 else 2]
		var size := Vector2(tuft["width"],tuft["width"]*texture.get_height()/texture.get_width())
		draw_texture_rect(texture,Rect2(tuft["position"]-Vector2(size.x/2,size.y),size),false,Color(0.82,0.89,0.80))
	for scuff in scuffs:
		draw_polyline(scuff,Color("444637"),2,false)
	for cell in world.props:
		var body: Rect2 = world.prop_collisions[cell]
		draw_set_transform(body.get_center()+Vector2(0,body.size.y*0.2),0,Vector2(1,0.3))
		draw_circle(Vector2.ZERO,body.size.x*0.65,Color(0.06,0.08,0.04,0.22))
		draw_set_transform(Vector2.ZERO)
		if world.props[cell] not in [2,4]:
			var data := presentation(cell)
			var rect: Rect2 = data["rect"]
			rect.position += offset_for(cell)
			draw_texture_rect(data["texture"],rect,false,data["tint"].lerp(Color.WHITE,absf(impulse_wave(cell))*0.15))
	for particle in particles:
		draw_rect(Rect2(particle["position"],Vector2(2,2)),particle["tint"])
