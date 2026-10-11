extends RefCounted
## Atlas regions are aligned to a common foot baseline without modifying the source.
const SHEET = preload("res://assets/characters/survivor_walk.png")
const HARVEST_SHEET = preload("res://assets/characters/survivor_harvest.png")
const DIRECTIONS := [&"down", &"left", &"right", &"up"]

static func build() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var image := SHEET.get_image()
	var columns := [70, 375, 655, 940]
	var rows := [0, 315, 627, 933]
	for row in 4:
		var walk := StringName("walk_" + DIRECTIONS[row])
		var idle := StringName("idle_" + DIRECTIONS[row])
		frames.add_animation(walk)
		frames.set_animation_speed(walk, 8.0)
		frames.set_animation_loop(walk, true)
		frames.add_animation(idle)
		frames.set_animation_loop(idle, false)
		for column in 4:
			var height := mini(315, image.get_height() - rows[row])
			var cell := Rect2i(columns[column], rows[row], 260, height)
			var used := image.get_region(cell).get_used_rect()
			var atlas := AtlasTexture.new()
			atlas.atlas = SHEET
			atlas.region = Rect2(cell.position + used.position, used.size)
			atlas.margin = Rect2(Vector2((260 - used.size.x) / 2.0, 310 - used.size.y), Vector2(260, 320) - Vector2(used.size))
			frames.add_frame(walk, atlas)
			if column == 1:
				frames.add_frame(idle, atlas)
	var harvest_image := HARVEST_SHEET.get_image()
	var cell_size := Vector2i(harvest_image.get_width() / 4, harvest_image.get_height() / 4)
	for row in 4:
		var action := StringName("harvest_" + DIRECTIONS[row])
		frames.add_animation(action)
		frames.set_animation_speed(action, 4.0 / 0.6)
		frames.set_animation_loop(action, false)
		for column in 4:
			var cell := Rect2i(Vector2i(column, row) * cell_size, cell_size)
			var used := harvest_image.get_region(cell).get_used_rect()
			var atlas := AtlasTexture.new()
			atlas.atlas = HARVEST_SHEET
			atlas.region = Rect2(cell.position + used.position, used.size)
			# Keep the atlas cell's horizontal anchor: tool reach must not shift the torso.
			atlas.margin = Rect2(Vector2(used.position.x - (cell_size.x - 260) / 2.0, 310 - used.size.y), Vector2(260, 320) - Vector2(used.size))
			frames.add_frame(action, atlas)
	return frames
