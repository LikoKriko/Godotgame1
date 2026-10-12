extends RefCounted
## A validated library of final character-plus-item frames. Each direction is
## authored separately; intermediate directions never rotate a flat body sprite.
const TOOL_DIRECTIONS := 16
const WALK_FRAMES := 12
const ACTION_FRAMES := 16

static func direction_index(angle: float, directions: int = TOOL_DIRECTIONS) -> int:
	return posmod(roundi(angle / (TAU / directions)), directions)

static func clip_name(state: StringName, direction: int) -> StringName:
	return StringName("%s_%02d" % [state, direction])

static func cache_key(item_id: StringName, category: StringName) -> String:
	# Categories select the poses; IDs select the item artwork. Never cache by
	# category alone, or two axes with different designs would share the picture.
	return "%s/%s" % [category, item_id]

static func validate_sheet(texture: Texture2D, canvas: Vector2i, directions: int, frames: int) -> bool:
	return texture != null and canvas.x > 0 and canvas.y > 0 and directions > 0 and frames > 0 \
		and Vector2i(texture.get_size()) == Vector2i(canvas.x * frames, canvas.y * directions)

static func add_sheet(library: SpriteFrames, sheet: Texture2D, canvas: Vector2i,
		state: StringName, directions: int, frames: int, seconds: float, loop: bool) -> bool:
	if not validate_sheet(sheet, canvas, directions, frames) or seconds <= 0:
		return false
	for row in directions:
		if library.has_animation(clip_name(state, row)):
			return false
	for row in directions:
		var name := clip_name(state, row)
		library.add_animation(name)
		library.set_animation_loop(name, loop)
		library.set_animation_speed(name, frames / seconds)
		for column in frames:
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(Vector2i(column * canvas.x, row * canvas.y), canvas)
			frame.filter_clip = true
			library.add_frame(name, frame)
	return true

static func action_frame(phase: float, frames: int) -> int:
	return clampi(floori(clampf(phase, 0, 1) * frames), 0, frames - 1)
