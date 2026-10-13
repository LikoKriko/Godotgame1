extends Node2D
var world
var game
var velocity := Vector2.ZERO
var distance_left := 680.0
var damage := 3.0
var sprite := Sprite2D.new()
func _ready() -> void:
	var art := preload("res://scripts/arrow_art.gd").data()
	var turn: float = velocity.angle()-(art.tip-art.tail).angle()
	sprite.texture = art.texture; sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE*art.world_per_pixel; sprite.rotation = turn
	sprite.position = -Vector2(art.tip).rotated(turn)*art.world_per_pixel
	add_child(sprite)

func _process(delta: float) -> void:
	if game != null and game.is_paused():
		return
	var displacement := velocity * delta
	var steps := maxi(1, ceili(displacement.length() / 6.0))
	for i in steps:
		var motion := displacement / steps
		position += motion
		distance_left -= motion.length()
		if distance_left <= 0:
			queue_free()
			return
		for target in get_tree().get_nodes_in_group("damageable"):
			if not target is Node2D or not target.has_method("take_damage"): continue
			var touching: bool = target.contains_point(global_position) if target.has_method("contains_point") else target.global_position.distance_to(global_position) < 18
			if touching:
				target.take_damage(game.combat_damage(damage) if game != null else damage)
				queue_free()
				return

		if game != null and game.resources.target_at(global_position) != game.resources.NONE:
			game.combat_effects.flash(global_position,velocity.normalized())
			queue_free(); return
		if not world.walkable(position,2): queue_free(); return
