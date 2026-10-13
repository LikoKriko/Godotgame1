extends RefCounted
## Runtime regions of the unchanged user template; no generated background art.
const SOURCE = preload("res://assets/ui/inventory_template.png")
const BOUNDS := Rect2(50,66,1370,960)
const SIZE := Vector2(1370,960)
const PAPER := Rect2(378,438,100,100)
const SLOT := Rect2(124,714,84,83)
const ACTION := Rect2(884,260,409,85)
const ACTION_PAPER := Rect2(845,208,450,40)
const TAB := Rect2(416,99,219,78)
const GEAR_ICONS := {&"head":Rect2(211,270,79,67),&"torso":Rect2(600,269,74,68),&"hands":Rect2(210,412,77,63),&"legs":Rect2(600,450,78,82),&"feet":Rect2(210,555,77,66)}
static var textures: Dictionary = {}
static func crop(rect: Rect2) -> AtlasTexture:
	if textures.has(rect): return textures[rect]
	var texture := AtlasTexture.new(); texture.atlas = SOURCE; texture.region = rect; texture.filter_clip = true
	textures[rect] = texture
	return texture
static func patch(parent: Control, rect: Rect2, source: Rect2 = PAPER) -> TextureRect:
	var image := TextureRect.new(); image.texture = crop(source)
	image.position = rect.position; image.size = rect.size
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	parent.add_child(image); return image
static func skin(button: Button, source: Rect2, center: bool = false) -> void:
	for state in ["normal","hover","pressed","disabled","focus"]:
		var frame := StyleBoxTexture.new(); frame.texture = crop(source)
		frame.texture_margin_left = 10; frame.texture_margin_right = 10
		frame.texture_margin_top = 10; frame.texture_margin_bottom = 10
		frame.draw_center = center
		frame.modulate_color = Color(1.18,1.18,1.04) if state in ["hover","pressed","focus"] else (Color(0.65,0.65,0.65) if state == "disabled" else Color.WHITE)
		button.add_theme_stylebox_override(state,frame)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
