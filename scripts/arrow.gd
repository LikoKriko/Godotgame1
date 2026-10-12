extends Node2D
var world
var game
var velocity := Vector2.ZERO
var distance_left := 680.0
var damage := 18.0

func _process(delta: float) -> void:
	if game != null and game.is_paused():
		return
	var displacement := velocity * delta
	var steps := maxi(1, ceili(displacement.length() / 6.0))
	for i in steps:
		var motion := displacement / steps
		position += motion
		distance_left -= motion.length()
		if distance_left <= 0 or not world.walkable(position, 2):
			queue_free()
			return
		for target in get_tree().get_nodes_in_group("damageable"):
			if target is Node2D and target.has_method("take_damage") and target.global_position.distance_to(global_position) < 18:
				target.take_damage(game.combat_damage(damage) if game != null else damage)
				queue_free()
				return

func _draw() -> void:
	var direction := velocity.normalized()
	draw_line(-direction * 16, Vector2.ZERO, Color("c5c0ac"), 2)
	draw_line(Vector2.ZERO, -direction.rotated(0.65) * 6, Color("e1d8b0"), 2)
	draw_line(Vector2.ZERO, -direction.rotated(-0.65) * 6, Color("e1d8b0"), 2)
