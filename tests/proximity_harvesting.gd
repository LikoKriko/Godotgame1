extends SceneTree
const Aim = preload("res://tests/aim_fixture.gd")
var failures := 0
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func require(condition: bool,message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	for fixture in [[Vector2i(-4,-3),&"axe"],[Vector2i(3,-4),&"pickaxe"],[game.world.saplings.keys()[0],&""]]:
		var cell: Vector2i = fixture[0]
		var aim := Aim.approach(game,cell,fixture[1])
		var record: Dictionary = game.world_view.hit_meshes.targets[cell]
		var high_point := aim
		for point in record["surface"]:
			var world_point: Vector2 = record["area"].global_transform*point
			if world_point.y < high_point.y and game.resources.target_at(world_point) == cell:
				high_point = world_point
		var hp: int = game.resources.nodes[cell]["remaining"]
		require(game.resources.can_reach(cell,game.player),"Nearby object passes the distance test")
		game.start_work(high_point)
		game.advance_work(game.work_duration)
		require(game.resources.nodes[cell]["remaining"] == hp-1,"Any visible surface of a nearby selected object can be worked")
		require(game.world_view.hit_meshes.contains(cell,game.impact_position),"Visual hit stays on that object's nearby silhouette")
		game.world_view.update_trees(game.player,0.3)
		game.start_work(Vector2(8000,8000))
		game.advance_work(game.work_duration)
		require(game.resources.nodes[cell]["remaining"] == hp-1,"Cursor off the object remains a miss even while nearby")
		var rect: Rect2 = game.resources.bounds(cell)
		game.player = rect.position-Vector2(game.resources.REACH+1,0)
		game.start_work(high_point)
		game.advance_work(game.work_duration)
		require(game.resources.nodes[cell]["remaining"] == hp-1,"Cursor on a distant object cannot harvest it")
	print("%s: %d proximity checks, %d failures: nearby base plus cursor on visible surface" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(0 if failures == 0 else 1)
