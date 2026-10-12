extends Button
## The visible rectangle is the complete hit area: no expansion or offset.
func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO,size).has_point(point)
