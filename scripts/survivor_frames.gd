extends RefCounted
## Eight views share the same head anchor and foot baseline; source art stays intact.
const IDLE_SHEET = preload("res://assets/characters/survivor_idle_8dir.png")
const BODY_SHEET = preload("res://assets/characters/survivor_body_8dir.png")
const Regions = preload("res://assets/characters/survivor_regions.gd")
const CHARACTER_HEIGHT := 64.0
const Motion = preload("res://scripts/turn_motion.gd")
const DIRECTIONS := [&"down", &"down_right", &"right", &"up_right", &"up", &"up_left", &"left", &"down_left"]
const CANVAS := Vector2(640, 640)
const BASELINE := 620.0
static var cache: SpriteFrames

static func build() -> SpriteFrames:
	if cache != null:
		return cache
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for row in DIRECTIONS.size():
		var walk := StringName("walk_" + DIRECTIONS[row])
		var idle := StringName("idle_" + DIRECTIONS[row])
		frames.add_animation(walk)
		frames.set_animation_speed(walk, 8.0)
		frames.set_animation_loop(walk, true)
		frames.add_animation(idle)
		frames.set_animation_loop(idle, false)
		var idle_texture := atlas(IDLE_SHEET, Regions.IDLE[row])
		for column in 4:
			frames.add_frame(walk, idle_texture)
		frames.add_frame(idle, idle_texture)
		var work := StringName("work_" + DIRECTIONS[row])
		frames.add_animation(work)
		frames.set_animation_loop(work, false)
		frames.add_frame(work, atlas(BODY_SHEET, Regions.BODY[row]))
	# Turn clips pass through each intermediate 45-degree view along the short arc.
	for from in 8:
		for offset in [-4, -3, -2, -1, 1, 2, 3]:
			var to := posmod(from + offset, 8)
			var name := StringName("turn_%s_%s" % [Motion.FACINGS[from], Motion.FACINGS[to]])
			frames.add_animation(name)
			frames.set_animation_loop(name, false)
			frames.set_animation_speed(name, (absi(offset) + 1) / (Motion.MAX_TURN_TIME * absi(offset) / 4.0))
			for step in absi(offset) + 1:
				var facing: StringName = Motion.FACINGS[posmod(from + step * signi(offset), 8)]
				frames.add_frame(name, frames.get_frame_texture("idle_" + facing, 0))
	cache = frames
	return frames

static func atlas(sheet: Texture2D, data: Array) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = sheet
	texture.region = Rect2(data[0], data[1], data[2], data[3])
	texture.margin = Rect2(Vector2(data[0] - data[4] + CANVAS.x / 2, BASELINE - data[3]), CANVAS - Vector2(data[2], data[3]))
	return texture
