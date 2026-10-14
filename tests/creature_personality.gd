extends SceneTree
var failures := 0
var checks := 0
func _initialize(): call_deferred("run")
func require(ok: bool,message: String):
	checks += 1
	if not ok: failures += 1; push_error(message)
func run():
	var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false)
	var enemy = game.enemies.enemy
	var behavior = enemy.behavior
	game.player = enemy.position+Vector2(1000,1000)
	behavior.seed_if_needed()
	behavior.set_mode(&"sit_down",0.3); enemy.advance(0.3)
	require(enemy.state == &"sit" and behavior.remaining >= 4 and behavior.remaining <= 8,"Seated rest has the requested random duration")
	var duration: float = behavior.remaining
	enemy.advance(duration); require(enemy.state == &"sit_up","Rest transitions through getting up")
	for state in [&"sit_down",&"sit",&"sit_up",&"feed",&"walk"]:
		behavior.set_mode(state,5)
		game.player = enemy.position+Vector2(100,0)
		enemy.advance(0.1)
		require(enemy.state == &"run" and behavior.mode == &"chase","Player interrupts activity immediately: "+String(state))
	game.player = enemy.position+Vector2(1000,1000)
	behavior.set_mode(&"walk",12); behavior.goal = enemy.position+Vector2(30,0)
	var initial: Vector2 = enemy.position
	enemy.advance(0.1)
	require(absf(enemy.position.distance_to(initial)-2.975) < 0.001,"Wandering is half pursuit speed")
	var tree := Vector2i.ZERO
	for cell in game.world.props:
		if game.world.props[cell] == 2: tree = cell; break
	behavior.target_tree = tree; behavior.goal = enemy.position
	behavior.set_mode(&"walk",5); enemy.advance(0)
	require(enemy.state == &"feed" and behavior.remaining >= 2 and behavior.remaining <= 10,"Reaching a tree starts feeding for two to ten seconds")
	var saved: Dictionary = behavior.snapshot()
	require(behavior.valid_snapshot(saved),"Behavior state validates for persistence")
	var expected: float = behavior.rng.randf()
	behavior.restore(saved)
	require(behavior.rng.randf() == expected and behavior.target_tree == tree,"Save restoration retains activity and random sequence")
	for state in ["walk","run","sit","sit_down","sit_up","feed"]:
		var clip: Dictionary = enemy.clips[state]
		require(clip.directions == 16,"Every behavior has sixteen authored directions")
		for direction in 16:
			enemy.heading = direction*TAU/16; enemy.state = StringName(state); enemy.update_sprite()
			require(enemy.atlas.region.position.y == direction*enemy.clips.canvas[1],"Behavior selects its authored view")
	print("%s: %d creature personality checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	game.free(); quit(1 if failures else 0)
