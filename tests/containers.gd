extends SceneTree
const Inventory = preload("res://scripts/inventory.gd")
const Nutrition = preload("res://scripts/nutrition.gd")
const Workshop = preload("res://scripts/workshop.gd")
const Icons = preload("res://scripts/item_icons.gd")
const Save = preload("res://scripts/save_game.gd")
var failures := 0
var checks := 0
func require(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var bag = Inventory.new(); bag.reset()
	bag.add(&"cuero",3)
	require(Workshop.craft(bag,&"botella") != "" and bag.count(&"cuero") == 3,"Missing thread cannot consume leather")
	bag.add(&"hilo",1)
	require(Workshop.craft(bag,&"botella") == "" and bag.count(&"cuero") == 0 and bag.count(&"hilo") == 0,"Bottle costs exactly three leather and one metre of thread")
	var index := -1
	for i in bag.CAPACITY:
		if bag.slots[i].get("id") == &"botella": index = i
	var item: Dictionary = bag.slots[index]
	var uid: int = item.uid
	var empty_icon := Icons.for_item(item)
	require(item.water_ml == 0 and item.quantity == 1,"Crafting creates one empty container")
	require(Nutrition.refill(item).ok and item.water_ml == 500,"Refilling gives exactly 500 ml")
	require(Icons.for_item(item) != empty_icon,"Inventory distinguishes an empty and filled bottle")
	var nutrition = Nutrition.new()
	require(not nutrition.consume(bag,index).ok and item.water_ml == 500,"Full hydration preserves contents")
	nutrition.hydration_ml = 1000
	for expected in [250,0]:
		require(nutrition.consume(bag,index).ok and item.water_ml == expected and item.uid == uid,"Each sip uses 250 ml and retains container identity")
	require(nutrition.hydration_ml == 1500 and nutrition.calories_today == 0 and bag.count(&"botella") == 1,"Water adds no calories and never consumes the flask")
	require(not nutrition.consume(bag,index).ok,"Empty bottle cannot provide hydration")
	bag.add(&"botella",2)
	var bottles := 0
	for entry in bag.slots:
		if entry.get("id") == &"botella": bottles += 1; require(entry.quantity == 1,"Containers never stack")
	require(bottles == 3,"Three bottles use three physical slots")
	require(bag.move_item(&"bag",index,&"quick",0),"Bottle moves into physical quick storage")
	require(bag.activate_quick(0) and bag.held_id() == &"botella","Quick key selects bottle without drinking")
	require(bag.activate_quick(0) and bag.held_id() == &"","Repeated quick key leaves hands free")
	var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false)
	game.bag.add(&"water",8)
	var state: Dictionary = Save.capture(game); state.version = 3
	state.erase("resource_layout_version")
	for cell in state.resources:
		if game.world.props[cell] == 1:
			state.resources[cell] = 6 if game.world.large_rocks.has(cell) else (2 if game.world.prop_collisions[cell].size.x <= 20 else 3)
	var migrated: Dictionary = Save.migrate(state)
	require(Save.valid(migrated),"Old rock durability and stacked water migrate into a valid save")
	var volume := 0
	for entry in migrated.slots:
		if entry.get("id") == &"botella": volume += entry.water_ml; require(entry.quantity == 1,"Migrated containers are separate items")
	require(volume == 4000,"Migration preserves all eight old 500 ml portions")
	var full_legacy: Dictionary = state.duplicate(true)
	for i in full_legacy.slots.size():
		if full_legacy.slots[i].get("id") == &"water": full_legacy.slots[i].quantity = 99
		elif full_legacy.slots[i].is_empty():
			full_legacy.slots[i] = game.bag.make_item(&"axe",1)
	full_legacy.next_uid = game.bag.next_uid
	var packed: Dictionary = Save.migrate(full_legacy)
	require(Save.valid(packed),"Full old backpack remains valid without discarding an oversized legacy water stack")
	var legacy_bag = Inventory.new(); legacy_bag.reset(); legacy_bag.add(&"water",2)
	var legacy_index := -1
	for i in legacy_bag.CAPACITY:
		if legacy_bag.slots[i].get("id") == &"water": legacy_index = i
	nutrition.hydration_ml = 1000
	require(nutrition.consume(legacy_bag,legacy_index).ok and legacy_bag.count(&"water") == 1 and legacy_bag.count(&"botella") == 1,"Drinking a retained old stack separates a reusable container atomically")
	var malformed: Dictionary = migrated.duplicate(true)
	for entry in malformed.slots:
		if entry.get("id") == &"botella": entry.water_ml = 501; break
	require(not Save.valid(malformed),"Save validation rejects impossible container contents")
	for cell in game.resources.nodes:
		if game.world.props[cell] == 1: require(migrated.resources[cell] == game.resources.nodes[cell].hits,"Undamaged old rocks retain full durability at their new size")
	var damaged: Dictionary = state.duplicate(true)
	var largest: Vector2i = game.world.large_rocks.keys()[0]
	var depleted: Vector2i = game.world.large_rocks.keys()[1]
	damaged.resources[largest] = 3; damaged.resources.erase(depleted)
	var converted: Dictionary = Save.migrate(damaged)
	require(converted.resources[largest] == 6 and not converted.resources.has(depleted),"Old half-mined and depleted boulders preserve their progress after durability changes")
	var catalog = game.item_catalog
	catalog.open_catalog()
	require(game.is_paused() and catalog.buttons.has(&"hilo") and catalog.buttons.has(&"cuero") and not catalog.buttons.has(&"water"),"K catalogue pauses gameplay and includes unavailable materials without legacy duplicates")
	catalog.filter_entries("botella")
	require(catalog.buttons[&"botella"].visible and not catalog.buttons[&"axe"].visible,"Search filters by item name")
	catalog.select_item(&"botella"); catalog.quantity.value = 2
	require(catalog.add_selected() and game.bag.count(&"botella") == 2,"Catalogue adds nonstackable containers to the backpack")
	for i in game.bag.CAPACITY:
		if game.bag.slots[i].is_empty(): game.bag.slots[i] = game.bag.make_item(&"axe",1)
	var before: Array = game.bag.slots.duplicate(true)
	require(not catalog.add_selected() and game.bag.slots == before,"Full backpack rejects the entire request without partial additions")
	print("%s: %d container, crafting, migration and catalogue checks" % ["PASS" if failures == 0 else "FAIL",checks])
	quit(0 if failures == 0 else 1)
