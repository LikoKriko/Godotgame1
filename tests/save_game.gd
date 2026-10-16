extends SceneTree
const Save = preload("res://scripts/save_game.gd")
const TEST_PATH := "user://day_zero_test_save.cfg"
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func require(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func same_state(a: Dictionary,b: Dictionary) -> bool:
	if a.keys() != b.keys(): return false
	for field in a:
		if a[field] is float:
			if absf(a[field]-b[field]) >= 0.000001: return false
		elif a[field] != b[field]: return false
	return true
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.world.seed_value += 3
	game.restart()
	game.skill_points = 9
	game.buy_improvement(&"speed", true)
	game.buy_improvement(&"life", false)
	game.buy_improvement(&"life", false)
	game.progression.activate(&"speed")
	game.progression.advance(1)
	game.progression.take_damage(4)
	game.gain_experience(31,&"main_quest")
	game.day_cycle.advance(550)
	game.nutrition.calories_today = 1800
	game.nutrition.hydration_ml = 1999.1234567891011
	game.bag.add(&"piedra", 10)
	game.bag.held_item().uses = 18
	game.assign_quick_item(0,game.bag.held_item().uid)
	if game.bag.active_quick_uid != game.bag.quick_slots[0].uid: game.bag.activate_quick(0)
	game.movement.heading = -PI/2
	var removed: Vector2i = game.resources.nodes.keys()[0]
	var footprint: Rect2i = game.resources.nodes[removed].footprint
	game.world.release_prop(removed)
	game.resources.nodes.erase(removed)
	var partial: Vector2i = game.resources.nodes.keys()[0]
	game.resources.nodes[partial].remaining = 1
	var state: Dictionary = Save.capture(game)
	require(Save.valid(state), "The full gameplay snapshot is valid")
	require(Save.write(game, TEST_PATH) == OK, "Atomic save succeeds")
	require(not FileAccess.file_exists(TEST_PATH+".tmp"), "Successful replacement leaves no temporary file")
	game.free()
	# A newly constructed scene proves this does not rely on in-memory state.
	var loaded = load("res://scenes/main.tscn").instantiate()
	root.add_child(loaded)
	loaded.set_process(false)
	require(Save.restore(loaded, Save.read_state(TEST_PATH)), "New scene restores a disk save")
	require(same_state(Save.capture(loaded),state), "Round-trip preserves every saved field within decimal float precision")
	require(not loaded.world.props.has(removed) and not loaded.world_view.hit_meshes.targets.has(removed), "Harvested objects and their hit surfaces stay removed")
	for y in range(footprint.position.y, footprint.end.y):
		for x in range(footprint.position.x, footprint.end.x):
			require(not loaded.world.cells[Vector2i(x,y)].blocked, "Harvested footprint is freed")
	require(loaded.resources.nodes[partial].remaining == 1, "Partially worked objects retain remaining hits")
	require(loaded.bag.held_item().uses == 18 and loaded.progression.perks[&"life"] == 2, "Durability and paid perk phases persist")
	var legacy := state.duplicate(true)
	legacy.version = 1
	legacy.equipment[&"hands"] = legacy.quick_slots[0]
	legacy.erase("quick_slots"); legacy.erase("active_quick_uid")
	require(Save.restore(loaded,legacy),"Previous alias-based save migrates to physical quick storage")
	require(loaded.bag.equipment[&"hands"].is_empty() and loaded.bag.quick_slots[0].uid == loaded.bag.held_item().uid,"Migration retains the held tool exactly once")
	var physical_legacy := state.duplicate(true)
	physical_legacy.version = 2
	physical_legacy.equipment[&"hands"] = physical_legacy.quick_slots[0]
	physical_legacy.quick_slots[0] = {}
	physical_legacy.quick_items[0] = -1
	physical_legacy.active_quick_uid = -1
	physical_legacy.erase("held_tool")
	require(Save.restore(loaded,physical_legacy),"Version-two carried weapon migrates out of the glove equipment slot")
	require(loaded.bag.equipment[&"hands"].is_empty() and loaded.bag.held_item().uses == 18,"Migration preserves carried-tool durability and free glove slot")
	for mutate in [
		func(d): d.version = 99,
		func(d): d.slots[0].quantity = 200,
		func(d): d.slots[0].id = &"unknown",
		func(d): d.points = -1,
		func(d): d.hydration = INF,
		func(d): d.player = Vector2(INF, 0),
		func(d): d.skills[&"speed"] = 10,
		func(d): d.slots[1].uid = d.slots[0].uid,
		func(d): d.resources[Vector2i(999,999)] = 1
		,func(d): d.collected.erase("piedra")
		,func(d): d.quick_items[1] = d.quick_items[0]
	]:
		var corrupt := state.duplicate(true)
		mutate.call(corrupt)
		require(not Save.restore(loaded, corrupt), "Invalid or incompatible save is rejected")
		require(same_state(Save.capture(loaded),state), "Failed loading does not alter the current game")
	var broken := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	broken.store_string("this is not a save"); broken.close()
	require(Save.read_state(TEST_PATH).is_empty(), "Malformed files cannot be loaded")
	DirAccess.remove_absolute(TEST_PATH)
	loaded.free()
	print("%s: %d save checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
