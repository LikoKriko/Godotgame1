extends Control
var world
var player := Vector2.ZERO

func _draw() -> void:
	if world == null:
		return
	draw_rect(Rect2(-8, -24, 208, 176), Color(0.05, 0.06, 0.08, 0.92))
	draw_string(ThemeDB.fallback_font, Vector2(0, -7), "BOSQUE · 32 × 24", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c5bea4"))
	for cell in world.cells:
		var data: Dictionary = world.cells[cell]
		var color := Color("737968") if data["blocked"] else Color("414a39")
		if data["road"] and not data["blocked"]:
			color = Color("6a6351")
		draw_rect(Rect2(Vector2(cell - world.FIRST) * 6, Vector2(6, 6)), color)
	var point: Vector2 = (player - world.bounds.position) / world.TILE * 6
	draw_rect(Rect2(point - Vector2(2, 2), Vector2(5, 5)), Color("ffe078"))
