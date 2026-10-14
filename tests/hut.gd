extends SceneTree
var failures := 0
var checks := 0
func _initialize(): call_deferred("run")
func require(ok: bool, label: String):
 checks += 1
 if not ok: failures += 1; push_error(label)
func run():
 var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false)
 var hut = game.hut
 require(hut.base.length() < 800 and hut.base != Vector2.ZERO,"One hut occupies a clearing near the initial crossroads")
 require(game.world.walkable(hut.door,15),"Exterior door remains reachable")
 require(absf((hut.door+Vector2(0,17)).y-hut.base.y) < 0.001,"Door approach aligns character feet with the visible threshold")
 var approach: Vector2 = game.world.move_actor(hut.door+Vector2(0,65),Vector2(0,-65))
 require(approach.distance_to(hut.door) < 1,"A character can approach through the actual doorway gap")
 require(not game.world.walkable(hut.footprint.get_center(),15),"Exterior walls block movement")
 for cell in game.world.props: require(not game.world_view.presentation(cell).rect.intersects(hut.footprint),"Hut walls avoid existing objects")
 require(not is_instance_valid(hut.room) and hut.exterior.visible,"Outside cannot see the separate interior")
 require(not hut.interact(),"E from a distance cannot enter")
 game.player = hut.door
 require(game.interact_at(Vector2.ZERO),"E near the doorway enters without requiring precise cursor aim")
 require(hut.inside and hut.room.visible and hut.room.scene_file_path == "res://scenes/hut_interior.tscn" and not hut.exterior.visible and not game.world_view.visible,"Entering replaces the visible map with the room")
 require(not game.enemies.enemy.visible,"The enemy stays outside")
 var time: float = game.enemies.parry.time
 game._process(0.1)
 require(game.enemies.parry.time == time,"The safe interior pauses exterior combat")
 game.player = hut.ROOM_CENTER
 game.move_player(Vector2.RIGHT,10)
 require(hut.ROOM_BOUNDS.grow(-19).has_point(game.player),"Room walls contain player movement")
 require(not hut.interact(),"Exiting requires approaching the room doorway")
 var Save = preload("res://scripts/save_game.gd")
 var terrain_before: Vector4 = game.world.ground_sampler.weights_at(hut.footprint.get_center())
 var state: Dictionary = Save.capture(game)
 require(Save.valid(state) and Save.restore(game,state) and game.hut.inside,"Manual saves restore the separate interior")
 require(game.world.ground_sampler.weights_at(hut.footprint.get_center()).is_equal_approx(terrain_before),"Saving and returning preserves the soil around the hut")
 game.player = hut.ROOM_DOOR
 require(game.interact_at(Vector2.ZERO) and not hut.inside,"E exits near the interior doorway")
 require(game.player.is_equal_approx(hut.door) and game.world_view.visible and game.enemies.enemy.visible,"Exiting returns to the same exterior entrance")
 require(game.gain_experience(20,&"craft") and game.level == 2 and game.skill_points == 1,"Registered sources use the existing shared level points")
 require(not game.gain_experience(20,&"gathering") and not game.gain_experience(20,&"enemy"),"Retired sources cannot grant experience")
 print("%s: %d hut and XP checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures]); game.free(); quit(1 if failures else 0)
