extends RefCounted
## Isolated glyphs baked from the user template; shared resources at runtime.
const BOUNDS := Rect2(50,66,1370,960)
const SIZE := Vector2(1370,960)
const PAPER := Rect2(378,438,100,100)
const SLOT := Rect2(124,714,84,83)
const ACTION := Rect2(884,260,409,85)
const ACTION_PAPER := Rect2(845,208,450,40)
const TAB := Rect2(416,99,219,78)
const GEAR_ICONS := {&"head":Rect2(211,270,79,67),&"torso":Rect2(600,269,74,68),&"hands":Rect2(210,412,77,63),&"legs":Rect2(600,450,78,82),&"feet":Rect2(210,555,77,66)}
static var textures: Dictionary = {}
static func crop(rect: Rect2) -> Texture2D:
	if textures.has(rect): return textures[rect]
	var glyphs := {Rect2(924,278,52,47):"improve",Rect2(924,391,52,49):"repair",Rect2(924,503,52,49):"dismantle"}
	for slot in GEAR_ICONS:
		glyphs[GEAR_ICONS[slot]] = "gear_"+str(slot)
	if not glyphs.has(rect): return null
	var texture: Texture2D = load("res://assets/ui/styles/"+glyphs[rect]+"_icon.png")
	textures[rect] = texture
	return texture
static func patch(parent: Control, rect: Rect2, source: Rect2 = PAPER) -> Control:
	var panel := Panel.new()
	panel.position = rect.position; panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var appearance: StyleBox = preload("res://scripts/ui_style.gd").frame() if source == BOUNDS else fill_box()
	if source == BOUNDS: appearance.edge = 24.0
	panel.add_theme_stylebox_override("panel",appearance)
	parent.add_child(panel); return panel
static func fill_box() -> StyleBoxTexture:
	var box := StyleBoxTexture.new(); box.texture = preload("res://assets/ui/styles/fill.png")
	box.modulate_color = Color(0.80,0.80,0.80,1); return box
static func skin(button: Button, _source: Rect2, _center: bool = false) -> void:
	preload("res://scripts/ui_style.gd").skin_button(button)
