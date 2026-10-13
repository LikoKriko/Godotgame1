extends SceneTree
const Aim = preload("res://tests/aim_fixture.gd")
var failures := 0
var checks := 0
func require(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false)
	var plant: Vector2i = game.world.burdock.keys()[0]
	var aim: Vector2 = Aim.approach(game,plant,&"axe")
	require(not game.interact_at(aim) and game.resources.nodes.has(plant) and game.feedback.contains("manos libres"),"E with a tool preserves the plant and explains the free-hand requirement")
	game.bag.unequip(&"tool")
	var leaves: int = game.resources.nodes[plant].yield
	require(game.interact_at(aim) and game.resources.nodes.has(plant),"E starts the six-frame pickup without granting leaves before contact")
	game.interaction_motion.advance(0.18); game.advance_pickup()
	require(not game.resources.nodes.has(plant) and game.bag.count(&"hoja_bardana") == leaves,"Leaves arrive at pickup contact")
	game.interaction_motion.advance(0.18); game.advance_pickup()
	var rock: Vector2i = game.resources.NONE
	for cell in game.resources.nodes:
		if game.resources.nodes[cell].hand_collectable: rock = cell; break
	aim = Aim.approach(game,rock,&"pickaxe")
	require(not game.interact_at(aim) and game.resources.hit(rock,game.player).get("reason") == "herramienta","Small stones cannot be picked while holding a pickaxe")
	game.bag.unequip(&"tool")
	var reward: int = game.resources.nodes[rock].yield
	require(reward >= 1 and reward <= 3 and game.interact_at(aim),"E starts picking one to three stones with free hands")
	game.interaction_motion.advance(0.18); game.advance_pickup()
	require(game.bag.count(&"piedra") == reward,"Stone pickup grants the resource only at contact")
	game.interaction_motion.advance(0.18); game.advance_pickup()
	var tree := Vector2i(-4,-3)
	aim = Aim.approach(game,tree,&"axe")
	var hits: int = game.resources.nodes[tree].remaining
	require(not game.interact_at(aim) and not game.working and game.resources.nodes[tree].remaining == hits,"E never chops a tree or starts an attack")
	game.bag.add(&"botella",1)
	var bottle_index := -1
	for i in game.bag.CAPACITY:
		if game.bag.slots[i].get("id") == &"botella": bottle_index = i
	game.bag.move_item(&"bag",bottle_index,&"quick",0); game.bag.activate_quick(0)
	var puddle: Dictionary = game.world.puddles[0]
	var presentation: Dictionary = game.world_view.puddle_presentation(puddle)
	var water_aim := Vector2.INF
	var transparent := Vector2.INF
	var rect: Rect2 = presentation.rect
	for y in range(int(rect.position.y),int(rect.end.y),2):
		for x in range(int(rect.position.x),int(rect.end.x),2):
			var point := Vector2(x,y)
			if game.world_view.water_at(point).has_area(): water_aim = point
			else: transparent = point
	require(water_aim.is_finite() and transparent.is_finite(),"Water hit detection distinguishes opaque water from transparent padding")
	game.player = rect.get_center()+Vector2(rect.size.x/2+10,0)
	require(game.interact_at(water_aim) and game.bag.held_item().water_ml == 500,"E over visible water fills the selected bottle when nearby")
	game.bag.held_item().water_ml = 0
	require(not game.interact_at(transparent) and game.bag.held_item().water_ml == 0,"Transparent puddle padding cannot refill a bottle")
	game.player = rect.end+Vector2(100,100)
	require(not game.interact_at(water_aim) and game.bag.held_item().water_ml == 0,"Distant water cannot refill a bottle")
	require(not game.start_work(water_aim) and not game.working,"Selected bottle cannot start a weapon action")
	print("%s: %d interaction checks: hands, E, visible water and reach" % ["PASS" if failures == 0 else "FAIL",checks])
	quit(0 if failures == 0 else 1)
