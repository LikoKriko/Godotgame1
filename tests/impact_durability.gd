extends SceneTree
var checks := 0
var failures := 0
var game
func _initialize(): call_deferred("run")
func check(value: bool, message: String):
	checks += 1
	if not value: failures += 1; push_error(message)
func strike(id: StringName, target: Vector2):
	game.bag.select_tool(id)
	game.weapon_timer = 0
	return game.resolve_melee_contact(target,preload("res://scripts/tool_contact.gd").contact(game.player,target,id))
func run():
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false); game.progression.rng.seed = 42
	for id in [&"sword",&"axe",&"pickaxe"]:
		game.bag.select_tool(id)
		var before: int = game.bag.held_item().uses
		strike(id,Vector2(10000,10000))
		check(game.bag.held_item().uses == before,"Air swings preserve uses")
	var enemy = game.enemies.enemy
	enemy.position = Vector2(25,0); enemy.update_sprite()
	for id in [&"sword",&"axe",&"pickaxe"]:
		game.bag.select_tool(id); enemy.health = 10
		var before: int = game.bag.held_item().uses
		strike(id,enemy.hit_center())
		check(is_equal_approx(enemy.health,7 if id == &"sword" else 9),"Base sword/tool damage is 3/1")
		check(game.bag.held_item().uses == before-(1 if id == &"sword" else 2),"Enemy impacts cost one weapon use or two tool uses")
	enemy.position = Vector2(10000,10000)
	for kind in [1,2]:
		var cell := Vector2i.ZERO
		for candidate in game.resources.nodes:
			if game.world.props[candidate] == kind and not game.resources.nodes[candidate].hand_collectable: cell = candidate; break
		var rect: Rect2 = game.resources.bounds(cell)
		game.player = rect.position-Vector2(3,3)
		var aim: Vector2 = game.world_view.hit_meshes.nearest_surface(cell,rect.get_center())
		for id in [&"sword", &"axe", &"pickaxe"]:
			game.bag.select_tool(id)
			var node: Dictionary = game.resources.nodes[cell]
			var before_hits: int = node.remaining
			var before: int = game.bag.held_item().uses
			strike(id,aim)
			var correct: bool = id == (&"pickaxe" if kind == 1 else &"axe")
			check(game.bag.held_item().uses == before-(1 if id == &"sword" or correct else 2),"Correct work costs one; wrong tool costs two")
			check(node.remaining == before_hits-(1 if correct else 0),"Only the correct tool damages the resource")
	game.bag.select_tool(&"axe"); game.bag.held_item().uses = 1
	check(game.bag.consume_use(2) and game.bag.held_item().uses == 0,"The last wrong impact breaks a tool without negative durability")
	game.free(); print("%s: %d impact durability checks, %d failures" % ["PASS" if not failures else "FAIL",checks,failures]); quit(1 if failures else 0)
