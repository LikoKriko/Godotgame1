extends RefCounted
const BASIC = preload("res://assets/items/basic_tools.png")
const SHEET = preload("res://assets/items/stone_tools.png")
const SWORD = preload("res://assets/items/basic_sword.png")
const DATA := {
	&"axe": {"rect": Rect2(108,92,666,754), "grip": Vector2(230,692), "contact": Vector2(744,376), "support": Vector2(342,563)},
	&"pickaxe": {"rect": Rect2(991,92,710,756), "grip": Vector2(1480,726), "contact": Vector2(1680,320), "support": Vector2(1437,603)},
	&"sword": {"rect": Rect2(350,100,765,1085), "grip": Vector2(567,882), "contact": Vector2(1060,156), "support": Vector2(629,789)},
}
const DISPLAY_SIZES := {&"axe": 32.0, &"pickaxe": 32.0, &"sword": 32.0, &"bow": 28.0}
static var textures: Dictionary = {}
static var geometry_cache: Dictionary = {}

static func icon(id: StringName) -> Texture2D:
	if not DATA.has(id):
		return null
	if not textures.has(id):
		var texture := AtlasTexture.new()
		texture.atlas = SWORD if id == &"sword" else SHEET
		texture.region = DATA[id]["rect"]
		textures[id] = texture
	return textures[id]

static func draw(canvas: CanvasItem, id: StringName, hand: Vector2, tip: Vector2, mirrored: bool = false, basis: Transform2D = Transform2D.IDENTITY, tint: Color = Color.WHITE) -> void:
	var data := geometry(id)
	if data.is_empty():
		return
	var texture: Texture2D = data["texture"]
	var grip: Vector2 = data["grip"]
	var contact: Vector2 = data["contact"]
	var reflection := Vector2(-1,1) if mirrored else Vector2.ONE
	grip *= reflection
	contact *= reflection
	var factor := hand.distance_to(tip)/grip.distance_to(contact)
	var rotation := (tip-hand).angle()-(contact-grip).angle()
	canvas.draw_set_transform_matrix(basis*Transform2D(rotation,reflection*factor,0,hand-grip.rotated(rotation)*factor))
	canvas.draw_texture_rect(texture,Rect2(Vector2.ZERO,texture.get_size()),false,tint)
	canvas.draw_set_transform_matrix(basis)

# Both hands are anchored to actual points on the wooden shaft, using the
# same reflection, rotation and scale as the visible tool.
static func support_offset(id: StringName, direction: Vector2, mirrored: bool) -> Vector2:
	if not DATA.has(id):
		return Vector2.ZERO
	var data: Dictionary = DATA[id]
	var reflection := Vector2(-1,1) if mirrored else Vector2.ONE
	var axis: Vector2 = (data["contact"]-data["grip"])*reflection
	var offset: Vector2 = (data["support"]-data["grip"])*reflection
	var length := reach_length(id)
	return offset.rotated(direction.angle()-axis.angle())*length/axis.length()

static func geometry(id: StringName) -> Dictionary:
	if geometry_cache.has(id):
		return geometry_cache[id]
	var texture: Texture2D = icon(id)
	var grip: Vector2
	var contact: Vector2
	if texture != null:
		grip = DATA[id]["grip"]-DATA[id]["rect"].position
		contact = DATA[id]["contact"]-DATA[id]["rect"].position
	else:
		var ids := [&"sword",&"bow"]
		if id not in ids:
			return {}
		if not textures.has(id):
			var half := Vector2i(BASIC.get_size()/2)
			var region := Rect2i(Vector2i(ids.find(id),0)*half,half)
			var used := BASIC.get_image().get_region(region).get_used_rect()
			var atlas := AtlasTexture.new()
			atlas.atlas = BASIC
			atlas.region = Rect2(region.position+used.position,used.size)
			textures[id] = atlas
		texture = textures[id]
		if texture == null:
			return {}
		grip = texture.get_size()*Vector2(0.5,0.8)
		contact = texture.get_size()*Vector2(0.5,0.15)
	var result := {"texture": texture,"grip": grip,"contact": contact}
	geometry_cache[id] = result
	return result

static func reach_length(id: StringName) -> float:
	var data := geometry(id)
	if data.is_empty():
		return 0.0
	var size: Vector2 = data["texture"].get_size()
	return data["grip"].distance_to(data["contact"])*DISPLAY_SIZES[id]/maxf(size.x,size.y)

static func reach_lengths() -> Dictionary:
	var lengths := {&"": 0.0}
	for id in DISPLAY_SIZES:
		lengths[id] = reach_length(id)
	return lengths
