extends RefCounted
## Two silhouettes × five sizes × three restrained tones for each natural prop.
const COUNT := 30
const CHARACTER_HEIGHT := 64.0
const CHARACTER_WIDTH := 25.6
const TREE_HEIGHTS := [102.0, 120.0, 142.0, 166.0, 188.0]
const ROCK_RATIOS := [0.2, 0.4, 0.7, 1.2, 2.0]
const TREE_TONES := [Color(0.94, 1.0, 0.95), Color.WHITE, Color(1.0, 0.97, 0.92)]
const ROCK_TONES := [Color(0.95, 0.98, 1.0), Color.WHITE, Color(1.0, 0.97, 0.93)]

static func profile(kind: int, id: int) -> Dictionary:
	var index := posmod(id, COUNT)
	var size_index := floori(index / 6.0)
	var tone_index := floori(index / 2.0) % 3
	return {
		"id": index,
		"shape": index % 2,
		"size_index": size_index,
		"size": TREE_HEIGHTS[size_index] if kind == 2 else CHARACTER_HEIGHT * ROCK_RATIOS[size_index],
		"tint": TREE_TONES[tone_index] if kind == 2 else ROCK_TONES[tone_index]
	}

static func dimensions(kind: int, id: int, texture_size: Vector2) -> Vector2:
	var data := profile(kind, id)
	var size: float = data["size"]
	if kind == 2:
		return Vector2(size * texture_size.x / texture_size.y, size)
	return Vector2(size, size * texture_size.y / texture_size.x)

static func collision(center: Vector2, kind: int, id: int, large: bool) -> Rect2:
	var size: float = profile(kind, id)["size"]
	var baseline := 60.0 if large else 26.0
	if kind == 2:
		var trunk := Vector2(size * 0.11, size * 0.10)
		return Rect2(center + Vector2(-trunk.x / 2, baseline - trunk.y), trunk)
	# Granite is wider than it is tall. The base leaves transparent sprite edges free.
	var body := Vector2(size * 0.72, size * 0.42)
	return Rect2(center + Vector2(-body.x / 2, baseline - body.y), body)
