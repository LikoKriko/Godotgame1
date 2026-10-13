extends SceneTree
const Bag = preload("res://scripts/inventory.gd")
const Workshop = preload("res://scripts/workshop.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run_checks")
func require(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
func empty_bag():
	var bag = Bag.new()
	bag.reset()
	for i in Bag.CAPACITY:
		bag.slots[i] = {}
	return bag
func run_checks() -> void:
	var bag = empty_bag()
	for id in [&"sword",&"bow",&"axe",&"pickaxe"]:
		require(bag.add(id,3),"Can own three distinct tools")
		var uids := {}
		for item in bag.slots:
			if item.get("id",&"") == id:
				require(item["quantity"] == 1,"Weapons and tools never stack")
				uids[item["uid"]] = true
		require(uids.size() == 3,"Each tool has an independent identity")
	bag = empty_bag()
	bag.add(&"piedra",10)
	bag.add(&"palo",10)
	bag.add(&"cuerda",10)
	var uid: int = bag.held_item()["uid"]
	require(Workshop.craft(bag,&"pickaxe") == "","Pickaxe crafts")
	require(bag.count(&"piedra") == 8 and bag.count(&"palo") == 8 and bag.count(&"cuerda") == 9,"Pickaxe costs exactly 2 stones, 2 sticks, 1 metre")
	require(Workshop.craft(bag,&"axe") == "","Axe crafts")
	require(bag.count(&"piedra") == 7 and bag.count(&"palo") == 6 and bag.count(&"cuerda") == 8,"Axe costs exactly 1 stone, 2 sticks, 1 metre")
	require(bag.held_item()["uid"] == uid,"Crafting preserves equipped identity")
	bag.held_item()["uses"] = 0
	require(Workshop.repair(bag,uid) == "" and bag.held_item()["uses"] == 30,"Broken equipped axe can be repaired")
	require(bag.count(&"piedra") == 6 and bag.count(&"palo") == 5,"Repair consumes displayed costs once")
	var before: Array = bag.slots.duplicate(true)
	require(Workshop.repair(bag,uid) != "" and bag.slots == before,"Repairing a full-durability item cannot spend materials")
	bag.add(&"helmet",1)
	for i in Bag.CAPACITY:
		if bag.slots[i].get("id",&"") == &"helmet":
			bag.equip(i,&"head")
	bag.equipment[&"head"]["uses"] = 15
	require(Workshop.repair(bag,bag.equipment[&"head"]["uid"]) == "" and bag.equipment[&"head"]["uses"] == 80,"Equipped armor repair restores durability")
	bag = empty_bag()
	bag.add(&"piedra",2)
	bag.add(&"palo",2)
	before = bag.slots.duplicate(true)
	require(Workshop.craft(bag,&"pickaxe") != "" and bag.slots == before,"Missing rope cannot partially consume other ingredients")
	bag.add(&"fibra",3)
	require(Workshop.craft(bag,&"cuerda") == "" and bag.count(&"cuerda") == 1 and bag.count(&"fibra") == 0,"Three fibers make one metre of rope")
	require(Workshop.craft(bag,&"pickaxe") == "" and bag.count(&"pickaxe") == 1,"Basic pickaxe can be made from gathered materials")
	bag = empty_bag()
	for i in Bag.CAPACITY:
		bag.slots[i] = bag.make_item(&"piedra",99)
	bag.slots[0] = bag.make_item(&"palo",99)
	bag.slots[1] = bag.make_item(&"cuerda",99)
	before = bag.slots.duplicate(true)
	require(Workshop.craft(bag,&"pickaxe") != "" and bag.slots == before,"Full backpack craft failure is atomic")
	bag.slots[1]["quantity"] = 1
	require(Workshop.craft(bag,&"pickaxe") == "" and bag.slots[1]["id"] == &"pickaxe","Consumed materials may free the output slot")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.bag.unequip(&"tool")
	var young: Vector2i = game.world.saplings.keys()[0]
	var position: Vector2 = game.resources.bounds(young).get_center()
	for i in 2:
		game.resources.hit(young,position)
	require(game.bag.count(&"fibra") == 3 and game.bag.count(&"palo") == 2,"Young tree provides both fibers and sticks with bare hands")
	var small: Vector2i = game.resources.NONE
	for cell in game.resources.nodes:
		if game.resources.nodes[cell]["hand_collectable"]:
			small = cell
			break
	require(small != game.resources.NONE,"Map contains stones collectible without a pickaxe")
	if small != game.resources.NONE:
		position = game.resources.bounds(small).get_center()
		for i in 2:
			game.resources.hit(small,position)
		require(game.bag.count(&"piedra") == 1,"Bare hands gather a small stone")
	game.inventory_panel.show()
	game.inventory_panel.open_crafting()
	require(game.inventory_panel.creation_page.materials.find_children("*","Label",true,false).any(func(node): return node.text.contains("Cuerda: 0 / 1 m")),"Creation page shows available/required rope in metre units")
	game.inventory_panel.open_section(0)
	game.inventory_panel.select_gear(&"legs")
	game.inventory_panel.open_repair()
	require(game.inventory_panel.workshop_confirm.disabled,"Undamaged armor shows disabled repair confirmation")
	print("%s: %d workshop checks, %d failures: exact recipes, tool identities, repair, armor, overflow and resource bootstrap" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(0 if failures == 0 else 1)
