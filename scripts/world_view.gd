extends Node2D
const FOREST_SHEET = preload("res://assets/environment/basic_forest_props.png")
const DETAILS_SHEET = preload("res://assets/environment/forest_details.png")
const DetailRegions = preload("res://assets/environment/forest_details_regions.gd")
const GROUND_SHADER = preload("res://shaders/quarantine_ground.gdshader")
const Style = preload("res://scripts/visual_style.gd")
const Nature = preload("res://scripts/nature_variants.gd")
const Imported = preload("res://scripts/imported_nature.gd")
const TREE_FADED_ALPHA := 0.35
var world
var forest_textures: Array[AtlasTexture] = []
var detail_textures: Array[AtlasTexture] = []
var grass_textures: Array[AtlasTexture] = []
var burdock_textures: Array[AtlasTexture] = []
var sapling_textures: Array[Texture2D] = []
var grass_floor: Node2D
var props_layer: Node2D
var ground: Polygon2D
var ground_material: ShaderMaterial
var scuffs: Array[PackedVector2Array] = []
var tree_sprites: Dictionary = {}
var tree_records: Dictionary = {}
var fading_trees: Dictionary = {}
var last_tree_player := Vector2.INF
var last_tree_props := -1
var hit_meshes = preload("res://scripts/hit_meshes.gd").new()
var impulses: Dictionary = {}
var particles: Array[Dictionary] = []
var presentation_cache: Dictionary = {}
var water_presentations: Dictionary = {}

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
	for region in [Rect2i(0,0,650,676),Rect2i(0,676,640,FOREST_SHEET.get_height()-676)]:
		forest_textures.append(atlas(FOREST_SHEET, region))
	for region in DetailRegions.REGIONS:
		detail_textures.append(atlas(DETAILS_SHEET, region, false))
	for index in 5: sapling_textures.append(load("res://assets/environment/imported/sapling_%02d.png" % (index+1)))
	hit_meshes.configure(self)
	burdock_textures.append(atlas(preload("res://assets/environment/burdock1.png"),Rect2i(108,255,1032,710),false))
	burdock_textures.append(atlas(preload("res://assets/environment/burdock2.png"),Rect2i(140,160,1020,915),false))
	ground = Polygon2D.new()
	ground.z_index = -1
	ground.polygon = PackedVector2Array([world.bounds.position, Vector2(world.bounds.end.x, world.bounds.position.y), world.bounds.end, Vector2(world.bounds.position.x, world.bounds.end.y)])
	ground_material = ShaderMaterial.new()
	ground_material.shader = GROUND_SHADER
	ground_material.set_shader_parameter("grass_reference",preload("res://assets/environment/imported/terreno1.png"))
	ground_material.set_shader_parameter("soil_reference",preload("res://assets/environment/imported/terreno2.png"))
	ground_material.set_shader_parameter("dirt_reference_a",preload("res://assets/environment/imported/terreno6.png"))
	ground_material.set_shader_parameter("dirt_reference_b",preload("res://assets/environment/imported/terreno7.png"))
	ground.material = ground_material
	add_child(ground)
	refresh_ground()
	for record in Imported.GRASS: grass_textures.append(Imported.texture(record))
	grass_floor = Node2D.new()
	grass_floor.z_index = -1
	var foliage_material := ShaderMaterial.new()
	foliage_material.shader = preload("res://shaders/ground_foliage.gdshader")
	grass_floor.material = foliage_material
	add_child(grass_floor)
	grass_floor.draw.connect(draw_floor_grass)
	props_layer = Node2D.new()
	props_layer.z_as_relative = false
	props_layer.z_index = -2
	add_child(props_layer)
	props_layer.draw.connect(draw_props)

func presentation(cell: Vector2i) -> Dictionary:
	if presentation_cache.has(cell):
		return presentation_cache[cell]
	var kind: int = world.props[cell]
	var large: bool = world.large_rocks.has(cell)
	var center: Vector2 = world.center(cell) + (Vector2(32,32) if large else Vector2.ZERO)
	var texture: Texture2D = burdock_textures[world.burdock[cell]-1] if kind == 5 else (detail_textures[1] if kind == 4 else detail_textures[1])
	var dimensions := Vector2(64, 64 * texture.get_height() / texture.get_width())
	var tint := Color(0.75,0.75,0.75)
	if kind in [1,2]:
		var variant: int = world.prop_variants[cell]
		var profile := Nature.profile(kind, variant)
		texture = forest_textures[profile.shape] if kind == 2 else Imported.texture(Imported.ROCKS[profile.size_index*2+profile.shape])
		dimensions = Nature.dimensions(kind, variant, texture.get_size())
		tint = profile["tint"]
	elif kind == 4:
		texture = sapling_textures[posmod(cell.x*31+cell.y*17,5)]
		var height := 42.0
		dimensions = Vector2(height * texture.get_width() / texture.get_height(), height)
		tint = Color.WHITE
	elif kind == 5:
		dimensions = Vector2(32*texture.get_width()/texture.get_height(),32)
		tint = Color.WHITE
	texture = Style.normalized(texture,dimensions,true,kind == 1,0.9 if kind == 1 else 1.0)
	var result := {"texture": texture, "size": dimensions, "tint": tint, "rect": Rect2(center + Vector2(-dimensions.x/2, (60 if large else 26)-dimensions.y), dimensions)}
	presentation_cache[cell] = result
	return result

func refresh_ground() -> void:
	presentation_cache.clear()
	water_presentations.clear()
	ground_material.set_shader_parameter("map_seed", float(world.seed_value))
	for i in world.dirt_patches.size():
		var patch: Rect2 = world.dirt_patches[i]
		ground_material.set_shader_parameter("dirt_patch_%d" % i,Vector4(patch.get_center().x,patch.get_center().y,patch.size.x/2,patch.size.y/2))
	if grass_floor != null:
		grass_floor.queue_redraw()
	if props_layer != null:
		props_layer.queue_redraw()
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
	tree_records.clear(); fading_trees.clear()
	last_tree_player = Vector2.INF; last_tree_props = -1
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
		tree_records[cell] = {"rest":rect,"base":rect.position+Vector2(rect.size.x/2,rect.size.y),"tint":data["tint"],"initialized":false}

func register_impact(cell: Vector2i, point: Vector2, direction: Vector2, material: String, strength: float = 1) -> void:
	impulses[cell] = {"time": 0.20, "direction": direction, "strength": strength}
	var tint := Color("95968b") if material in ["mineral", "piedra"] else (Color("97a568") if material == "fibra" else Color("b5905c"))
	for i in 5:
		particles.append({"position": point, "velocity": Vector2.from_angle(i*TAU/5-PI/2)*22+Vector2(0,-12), "time": 0.25, "tint": tint})
	queue_redraw()
	props_layer.queue_redraw()

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
	var changed_props := impulses.keys()
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
	var visibility_changed: bool = player != last_tree_player or world.props.size() != last_tree_props
	var active: Array = tree_sprites.keys() if visibility_changed else fading_trees.keys()
	if not visibility_changed:
		for cell in changed_props:
			if tree_sprites.has(cell) and not active.has(cell): active.append(cell)
	var fade_factor := 1-exp(-delta*12)
	for cell in active:
		var sprite: Sprite2D = tree_sprites[cell]
		if not world.props.has(cell):
			remove_child(sprite)
			sprite.queue_free()
			tree_sprites.erase(cell)
			tree_records.erase(cell); fading_trees.erase(cell)
			hit_meshes.remove(cell)
			continue
		var record: Dictionary = tree_records[cell]
		var rest: Rect2 = record.rest
		var base: Vector2 = record.base
		var direction := 1.0
		if impulses.has(cell) and absf(impulses[cell]["direction"].x) > 0.1:
			direction = signf(impulses[cell]["direction"].x)
		var wave := impulse_wave(cell)
		var rotation := wave * (0.065 if world.props[cell] == 4 else 0.025) * direction
		if not record.initialized or sprite.rotation != rotation:
			sprite.rotation = rotation
			sprite.position = base - Vector2(rest.size.x/2,rest.size.y).rotated(rotation)
			hit_meshes.set_transform(cell,sprite.position,sprite.rotation,sprite.scale)
			record.initialized = true
		var behind: bool = player.y+17 < world.prop_collisions[cell].end.y
		var hidden: bool = behind and rest.intersects(character_rect)
		var z := 1 if behind else -1
		if sprite.z_index != z: sprite.z_index = z
		var target := TREE_FADED_ALPHA if hidden else 1.0
		var alpha := lerpf(sprite.modulate.a,target,fade_factor)
		var tint: Color = record.tint.lerp(Color.WHITE,absf(wave)*0.15)
		tint.a = alpha
		if sprite.modulate != tint: sprite.modulate = tint
		# Keep the original floating-point interpolation, without snapping alpha.
		if tint.a != Color(0,0,0,target).a: fading_trees[cell] = true
		else: fading_trees.erase(cell)
	last_tree_player = player; last_tree_props = world.props.size()
	# Static prop surfaces already have their transform from add(). Only
	# impacted props need updates, including the frame when an impulse ends.
	for cell in changed_props:
		if hit_meshes.targets.has(cell) and world.props.has(cell) and world.props[cell] not in [2,4]:
			var record: Dictionary = hit_meshes.targets[cell]
			var rest: Rect2 = record["rest"]
			hit_meshes.set_transform(cell,rest.position+offset_for(cell),0,rest.size/record["texture_size"])
	if had_effects:
		queue_redraw()
		props_layer.queue_redraw()

func _draw() -> void:
	if world == null:
		return
	var edge: Rect2 = world.bounds
	for strip in [Rect2(edge.position,Vector2(edge.size.x,64)),Rect2(edge.position+Vector2(0,edge.size.y-64),Vector2(edge.size.x,64)),Rect2(edge.position,Vector2(64,edge.size.y)),Rect2(edge.position+Vector2(edge.size.x-64,0),Vector2(64,edge.size.y))]:
		draw_rect(strip,Color("3b4433"))
	for puddle in world.puddles:
		var data := puddle_presentation(puddle)
		draw_texture_rect(data.texture,data.rect,false,Color(0.84,0.87,0.85))
	for scuff in scuffs:
		draw_polyline(scuff,Color("444637"),1.0/Style.PIXELS_PER_WORLD,false)
	for particle in particles:
		draw_rect(Rect2(particle["position"],Vector2(2,2)),particle["tint"])

func draw_floor_grass() -> void:
	for tuft in world.grass_tufts:
		var texture: Texture2D = grass_textures[posmod(tuft["variant"],grass_textures.size())]
		var size := Vector2(tuft["width"],tuft["width"]*texture.get_height()/texture.get_width())
		grass_floor.draw_texture_rect(Style.normalized(texture,size,true,true),Rect2(tuft["position"]-Vector2(size.x/2,size.y),size),false,Color.WHITE)

func puddle_presentation(puddle: Dictionary) -> Dictionary:
	var key := str(puddle.position)+"/"+str(puddle.width)
	if not water_presentations.has(key):
		var source: Texture2D = detail_textures[3]
		var size := Vector2(puddle.width,puddle.width*source.get_height()/source.get_width())
		var texture := Style.normalized(source,size)
		water_presentations[key] = {"texture":texture,"rect":Rect2(puddle.position-size/2,size),"pixels":texture.get_image()}
	return water_presentations[key]

func water_at(point: Vector2) -> Rect2:
	for puddle in world.puddles:
		var data := puddle_presentation(puddle)
		var rect: Rect2 = data.rect
		if not rect.has_point(point): continue
		var image: Image = data.pixels
		var pixel := Vector2i((point-rect.position)/rect.size*Vector2(image.get_size()))
		if image.get_pixelv(pixel).a > 0.5: return rect
	return Rect2()

func draw_props() -> void:
	for cell in world.props:
		if world.props[cell] not in [2,4]:
			var data := presentation(cell)
			var rect: Rect2 = data["rect"]
			rect.position += offset_for(cell)
			props_layer.draw_texture_rect(data["texture"],rect,false,data["tint"].lerp(Color.WHITE,absf(impulse_wave(cell))*0.15))
