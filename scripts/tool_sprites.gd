extends RefCounted
const SHEET = preload("res://assets/items/stone_tools.png")
const SWORD = preload("res://assets/items/basic_sword.png")
const BOW = preload("res://assets/items/basic_bow.png")
const DATA := {
	&"axe": {"rect": Rect2(108,92,666,754), "grip": Vector2(230,692), "contact": Vector2(744,376), "support": Vector2(342,563)},
	&"pickaxe": {"rect": Rect2(991,92,710,756), "grip": Vector2(1480,726), "contact": Vector2(1680,320), "support": Vector2(1437,603)},
	&"sword": {"rect": Rect2(350,100,765,1085), "grip": Vector2(567,882), "contact": Vector2(1060,156), "support": Vector2(629,789)},
	&"bow": {"rect": Rect2(455,65,535,1140), "grip": Vector2(540,727), "contact": Vector2(782,-50), "support": Vector2(540,727), "string_top": Vector2(886,258), "string_bottom": Vector2(644,1035)},
}
const DISPLAY_SIZES := {&"axe": 32.0, &"pickaxe": 32.0, &"sword": 32.0, &"bow": 28.0}
static var textures: Dictionary = {}
static var geometry_cache: Dictionary = {}

static func icon(id: StringName) -> Texture2D:
	if not DATA.has(id):
		return null
	if not textures.has(id):
		var texture := AtlasTexture.new()
		texture.atlas = SWORD if id == &"sword" else (BOW if id == &"bow" else SHEET)
		texture.region = DATA[id]["rect"]
		textures[id] = texture
	return textures[id]

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
	if id in [&"bottle_empty",&"bottle_full"]:
		var filled := id == &"bottle_full"
		var bottle := preload("res://scripts/container_art.gd").part(1 if filled else 0)
		var grip := Vector2(1050,235) if filled else Vector2(435,235)
		var mouth := Vector2(1090,135) if filled else Vector2(475,130)
		var entry := {"texture":bottle,"grip":grip-bottle.region.position,"contact":mouth-bottle.region.position,"display_size":14.0,"clear_black":true}
		geometry_cache[id] = entry
		return entry
	var texture: Texture2D = icon(id)
	if texture == null: return {}
	var grip: Vector2 = DATA[id].grip-DATA[id].rect.position
	var contact: Vector2 = DATA[id].contact-DATA[id].rect.position
	var result := {"texture": texture,"grip": grip,"contact": contact,"support":DATA[id].support-DATA[id].rect.position}
	geometry_cache[id] = result
	return result

static func reach_length(id: StringName) -> float:
	var data := geometry(id)
	if data.is_empty():
		return 0.0
	var size: Vector2 = data["texture"].get_size()
	return data["grip"].distance_to(data["contact"])*data.get("display_size",DISPLAY_SIZES.get(id,14.0))/maxf(size.x,size.y)

static func reach_lengths() -> Dictionary:
	var lengths := {&"": 0.0}
	for id in DISPLAY_SIZES:
		lengths[id] = reach_length(id)
	return lengths
