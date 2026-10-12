extends SceneTree
const Save = preload("res://scripts/save_game.gd")
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func require(value: bool,message: String):
	checks += 1
	if not value: failures += 1; push_error(message)
func run():
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game); game.set_process(false)
	require(game.world.burdock.size() == 24,"Twenty-four individually dispersed plants")
	var variants := {1:0,2:0}
	for cell in game.world.burdock:
		variants[game.world.burdock[cell]] += 1
		require(game.world.grass_allowed(game.world.center(cell)+Vector2(0,26),0),"Burdock lies on grass, outside dirt, puddles and stone patches")
		require(game.world.walkable(game.world.center(cell)+Vector2(0,26)),"Burdock never blocks walking")
	require(variants[1] == 12 and variants[2] == 12,"Both uploaded variants occur")
	var targets := {}
	for cell in game.world.burdock:
		if not targets.has(game.world.burdock[cell]): targets[game.world.burdock[cell]] = cell
	for variant in targets:
		var cell: Vector2i = targets[variant]
		var base: Vector2 = game.world.prop_collisions[cell].get_center()
		game.player = base+Vector2(0,25)
		var aim: Vector2 = game.world_view.hit_meshes.nearest_surface(cell,base)
		require(game.resources.target_at(aim) == cell,"Cursor chooses the visible leaf surface")
		require(game.resources.hit(cell,game.player).get("reason") == "herramienta","Holding a tool cannot harvest the plant")
		game.bag.unequip(&"hands")
		var result: Dictionary = game.resources.hit_at(aim,Vector2.ZERO,Vector2.ZERO,game.player)
		var quantity := 5 if variant == 1 else 3
		require(result.get("depleted",false) and result.get("amount") == quantity,"One bare-hand blow yields the exact variant quantity")
		require(not game.world.burdock.has(cell) and not game.world.props.has(cell),"Harvested plant is removed")
		game.bag.select_tool(&"axe")
	require(game.bag.count(&"hoja_bardana") == 8,"Both yields reach inventory")
	var state := Save.capture(game)
	require(Save.restore(game,state) and game.world.burdock.size() == 22,"Harvested plants stay absent after saving/loading")
	var older := state.duplicate(true)
	older.erase("plant_layout_version")
	for cell in game.world.burdock: older.resources.erase(cell)
	older.collected.erase("hoja_bardana")
	require(Save.restore(game,older) and game.world.burdock.size() == 24,"Earlier saves gain the newly introduced plants")
	game.free()
	print("%s: %d burdock checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(0 if failures == 0 else 1)
