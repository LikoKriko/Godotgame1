extends RefCounted
## One uploaded arrow and one set of anchors for icon, nock and projectile.
const SOURCE = preload("res://assets/items/basic_arrow.png")
const REGION := Rect2(225,110,910,1030)
const TAIL := Vector2(271,1090)-Vector2(225,110)
const TIP := Vector2(1087,142)-Vector2(225,110)
const LENGTH := 24.0
static var cache: Dictionary = {}
static func data(outline: bool = true) -> Dictionary:
	if cache.has(outline): return cache[outline]
	var region := AtlasTexture.new(); region.atlas = SOURCE; region.region = REGION
	var span := LENGTH/TAIL.distance_to(TIP)
	var texture: Texture2D = preload("res://scripts/visual_style.gd").normalized(region,region.get_size()*span,outline,true)
	var ratio := texture.get_size()/region.get_size()
	var tail := TAIL*ratio; var tip := TIP*ratio
	var entry := {"texture":texture,"tail":tail,"tip":tip,"world_per_pixel":LENGTH/tail.distance_to(tip)}
	cache[outline] = entry; return entry
