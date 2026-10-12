extends RefCounted
const BASIC = preload("res://assets/items/basic_tools.png")
const SHEET = preload("res://assets/items/stone_tools.png")
const DATA := {
	&"axe": {"rect": Rect2(108,92,666,754), "grip": Vector2(230,692), "contact": Vector2(744,376), "support": Vector2(342,563)},
	&"pickaxe": {"rect": Rect2(991,92,710,756), "grip": Vector2(1480,726), "contact": Vector2(1680,320), "support": Vector2(1437,603)},
}
static var textures: Dictionary = {}

static func icon(id: StringName) -> Texture2D:
	if not DATA.has(id):
		return null
	if not textures.has(id):
		var texture := AtlasTexture.new()
		texture.atlas = SHEET
		texture.region = DATA[id]["rect"]
		textures[id] = texture
	return textures[id]

static func draw(canvas: CanvasItem, id: StringName, hand: Vector2, tip: Vector2, mirrored: bool = false) -> void:
	var texture: Texture2D = icon(id)
	var grip: Vector2
	var contact: Vector2
	if texture != null:
		grip = DATA[id]["grip"]-DATA[id]["rect"].position
		contact = DATA[id]["contact"]-DATA[id]["rect"].position
	else:
		var ids := [&"sword",&"bow"]
		if id not in ids:
			return
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
			return
		grip = texture.get_size()*Vector2(0.5,0.8)
		contact = texture.get_size()*Vector2(0.5,0.15)
	var reflection := Vector2(-1,1) if mirrored else Vector2.ONE
	grip *= reflection
	contact *= reflection
	var factor := hand.distance_to(tip)/grip.distance_to(contact)
	var rotation := (tip-hand).angle()-(contact-grip).angle()
	canvas.draw_set_transform(hand-grip.rotated(rotation)*factor,rotation,reflection*factor)
	canvas.draw_texture_rect(texture,Rect2(Vector2.ZERO,texture.get_size()),false)
	canvas.draw_set_transform(Vector2.ZERO)

# Both hands are anchored to actual points on the wooden shaft, using the
# same reflection, rotation and scale as the visible tool.
static func support_offset(id: StringName, direction: Vector2, mirrored: bool) -> Vector2:
	if not DATA.has(id):
		return Vector2.ZERO
	var data: Dictionary = DATA[id]
	var reflection := Vector2(-1,1) if mirrored else Vector2.ONE
	var axis: Vector2 = (data["contact"]-data["grip"])*reflection
	var offset: Vector2 = (data["support"]-data["grip"])*reflection
	var length := 25.0 if id == &"axe" else 28.0
	return offset.rotated(direction.angle()-axis.angle())*length/axis.length()
