extends Control
const MAP_SIZE := Vector2(192, 144)
var world
var player := Vector2.ZERO

func cell_scale() -> Vector2:
	return MAP_SIZE / Vector2(world.SIZE)

func _draw() -> void:
	if world == null:
		return
	draw_rect(Rect2(-8, -24, 208, 176), Color(0.05, 0.06, 0.08, 0.92))
	draw_string(ThemeDB.fallback_font, Vector2(0, -7), "BOSQUE · %d × %d" % [world.SIZE.x, world.SIZE.y], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c5bea4"))
	var scale_per_cell := cell_scale()
	for cell in world.cells:
		var data: Dictionary = world.cells[cell]
		var color := Color("737968") if data["blocked"] else Color("414a39")
		if data["road"] and not data["blocked"]:
			color = Color("6a6351")
		draw_rect(Rect2(Vector2(cell - world.FIRST) * scale_per_cell, scale_per_cell), color)
	var point: Vector2 = (player - world.bounds.position) / world.TILE * scale_per_cell
	draw_rect(Rect2(point - Vector2(2, 2), Vector2(5, 5)), Color("ffe078"))
