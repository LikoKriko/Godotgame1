extends SceneTree
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func require(value: bool,message: String):
	checks += 1
	if not value: failures += 1; push_error(message)
func run():
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game); game.set_process(false)
	game.bag.select_tool(&"sword"); game.equipping = false
	for armored in [false,true]:
		game.bag.equipment[&"torso"] = game.bag.make_item(&"burdock_armor",1) if armored else {}
		for direction in 16:
			game.movement.heading = direction*TAU/16
			game.working = true; game.work_duration = 0.62
			game.combat_effects.trail.clear()
			for frame in [3,4,5,6,7,8]:
				game.work_elapsed = game.work_duration*frame/16.0
				game.full_avatar.update_pose(0)
				var tip: Vector2 = game.full_avatar.held_tip()
				game.combat_effects.advance(0.01)
				require(tip.is_finite() and not game.combat_effects.trail.is_empty(),"Sword action exports a usable tip in every direction, with both outfits")
				require(game.combat_effects.trail.back().point.distance_to(tip) < 0.001,"The trail terminates at the actual displayed sword tip")
			game.working = false; game.combat_effects.advance(0.1)
			require(game.combat_effects.trail.is_empty(),"The trail fades completely after the stroke")
	var arrow = preload("res://scripts/arrow.gd").new()
	arrow.velocity = Vector2(100,-40); game.add_child(arrow); arrow.set_process(false)
	var art := preload("res://scripts/arrow_art.gd").data()
	require(arrow.sprite.to_global(art.tip).distance_to(arrow.global_position) < 0.001,"The projectile collision point coincides with its drawn arrow tip")
	game.free(); print("%s: %d sword tip/trail checks, %d failures" % ["PASS" if not failures else "FAIL",checks,failures]); quit(1 if failures else 0)
