extends SceneTree
const Aim = preload("res://tests/aim_fixture.gd")
const Bag = preload("res://scripts/inventory.gd")
var checks := 0
var failures := 0
class Target:
	extends Node2D
	var damage_received := 0.0
	func take_damage(amount: float) -> void:
		damage_received += amount
func _initialize() -> void:
	call_deferred("run_checks")
func require(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
func run_checks() -> void:
	var bag = Bag.new()
	bag.reset()
	require(bag.slots.size() == 32 and bag.equipment.size() == 5, "32 objects and five equipment slots")
	require(bag.held_id() == &"axe", "Axe initially equipped")
	require(not bag.equip(0, &"head"), "Sword cannot occupy head slot")
	require(bag.consume_use() and bag.held_item()["uses"] == 29, "One use consumed")
	bag.select_tool(&"pickaxe")
	bag.select_tool(&"axe")
	require(bag.held_item()["uses"] == 29, "Swaps preserve durability")
	bag.held_item()["uses"] = 1
	require(bag.consume_use() and not bag.usable(), "Last use breaks tool")
	require(not bag.consume_use() and bag.held_item()["uses"] == 0, "Broken tool stays at zero")
	require(not bag.can_harvest("madera"), "Broken axe cannot gather")
	bag.reset()
	require(bag.add(&"madera", 120) and bag.count(&"madera") == 120, "Materials stack across slots")
	for item in bag.slots:
		if item.get("id", &"") == &"madera":
			require(item["quantity"] <= 99, "Stack limit respected")
	for i in 32:
		bag.slots[i] = bag.make_item(&"madera", 99)
	require(not bag.add(&"piedra", 1), "Full bag cannot accept new material")
	require(bag.unequip(&"tool") and bag.held_id() == &"" and bag.quick_slots[5].id == &"axe", "A full bag cannot prevent putting away a physically stored quick tool")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	var tree := Vector2i(-4, -3)
	var aim: Vector2 = Aim.approach(game, tree, &"pickaxe")
	require(game.start_work(aim), "Wrong tool can swing")
	game.advance_work(game.work_duration)
	require(game.resources.nodes[tree]["remaining"] == 3, "Pickaxe does not chop trees")
	require(game.bag.held_item()["uses"] == 28, "Wrong tool impact costs two uses")
	aim = Aim.approach(game, tree, &"axe")
	require(game.start_work(aim), "Axe chops trees")
	game.advance_work(0.1)
	game.cancel_work()
	require(game.bag.held_item()["uses"] == 30, "Cancel before impact preserves uses")
	game.start_work(aim)
	game.advance_work(game.work_duration)
	require(game.bag.held_item()["uses"] == 29, "Resource impact consumes one use")
	game.resources.nodes[tree]["remaining"] = 1
	for i in 32:
		game.bag.slots[i] = game.bag.make_item(&"piedra", 99)
	game.start_work(aim)
	game.advance_work(game.work_duration)
	require(game.resources.nodes[tree]["remaining"] == 1 and game.bag.held_item()["uses"] == 28, "Full inventory preserves resource but physical impact still costs a use")
	game.restart()
	var rock: Vector2i = game.world.large_rocks.keys()[0]
	aim = Aim.approach(game, rock, &"axe")
	require(game.start_work(aim), "Axe can swing at rocks")
	game.advance_work(game.work_duration)
	require(game.resources.nodes[rock]["remaining"] == 12, "Axe does not mine rocks")
	aim = Aim.approach(game, rock, &"pickaxe")
	require(game.start_work(aim) and game.working, "Mining starts a complete-sprite action")
	game.advance_work(game.work_duration)
	require(game.bag.held_item()["uses"] == 29, "Mining consumes a pickaxe use")
	for i in 11:
		game.start_work(aim)
		game.advance_work(game.work_duration)
	require(game.bag.count(&"piedra") == 15 and not game.resources.nodes.has(rock), "Mined material enters backpack and node disappears")
	game.restart()
	game.bag.select_tool(&"sword")
	game.player = Vector2.ZERO
	var dummy := Target.new()
	dummy.position = Vector2(32, -12)
	root.add_child(dummy)
	dummy.add_to_group("damageable")
	game.progression.rng.seed = 42
	require(game.use_weapon(Vector2(32, -12)), "Sword action")
	require(dummy.damage_received == 3 and game.bag.held_item()["uses"] == 39, "Sword affects combat targets and uses")
	require(not game.use_weapon(Vector2(32, -12)), "Weapon cooldown enforced")
	game.bag.select_tool(&"bow")
	game.bag.add(&"flecha",1)
	game.weapon_timer = 0
	require(game.use_weapon(Vector2(32, -12)), "Bow shoots")
	var arrows := get_nodes_in_group("player_arrows")
	require(arrows.size() == 1 and game.bag.held_item()["uses"] == 59, "A bow use is spent when drawing/firing, including missed arrows")
	var arrow = arrows[0]
	game.inventory_panel.show()
	var previous: Vector2 = arrow.position
	arrow._process(0.1)
	require(arrow.position == previous, "Inventory pauses projectiles")
	game.inventory_panel.hide()
	arrow._process(0.1)
	require(dummy.damage_received == 6, "Arrow hits only combat target")
	game.bag.select_tool(&"pickaxe")
	game.weapon_timer = 0
	require(not game.use_weapon(Vector2(32, -12)), "Pickaxe cannot attack")
	game.bag.select_tool(&"axe")
	require(not game.use_weapon(Vector2(32, -12)), "Axe cannot attack")
	game.bag.held_item()["uses"] = 0
	game.player = game.resources.bounds(tree).position + Vector2(-24, 32)
	require(not game.start_work(aim), "Broken equipped axe cannot start an action")
	game.bag.select_tool(&"sword")
	game.bag.held_item()["uses"] = 0
	require(not game.use_weapon(Vector2(32, -12)), "Broken sword cannot attack")
	game.bag.select_tool(&"axe")
	game.inventory_panel.show()
	game.inventory_panel.fit_panel()
	require(game.inventory_panel.backpack_buttons.size() == 32 and game.inventory_panel.gear_buttons.size() == 5, "Visible slot counts")
	var side: Vector2 = game.inventory_panel.panel.size
	require(is_equal_approx(side.x/side.y,1370.0/960.0), "Inventory follows the supplied template aspect")
	var viewport_size := root.get_visible_rect().size
	var expected_side := 1370*minf(sqrt(viewport_size.x*viewport_size.y*0.6/(1370*960)),minf(viewport_size.x*0.95/1370,viewport_size.y*0.84/960))
	require(is_equal_approx(side.x, expected_side), "Inventory follows 60-percent target while fitting widescreen viewport")
	var center: Vector2 = game.inventory_panel.panel.position + side / 2
	require(center.is_equal_approx(viewport_size / 2), "Inventory is centered")
	var sword_item: Dictionary = (game.bag.slots+game.bag.quick_slots).filter(func(item): return item.get("id") == &"sword")[0]
	var sword_location: Dictionary = game.bag.location(sword_item.uid)
	require(not sword_location.is_empty(), "Sword preserved through equipment swaps")
	if sword_location.kind == &"quick": game.inventory_panel.select_quick(sword_location.index)
	else: game.inventory_panel.select_backpack(sword_location.index)
	game.inventory_panel.equip_selected()
	require(game.bag.held_id() == &"sword", "UI equips selected object")
	game.inventory_panel.select_gear(&"hands")
	require(not game.inventory_panel.equip_button.visible and game.bag.equipment[&"hands"].is_empty(), "Glove slot stays independent of the held weapon")
	game.bag.unequip(&"tool")
	require(game.bag.held_id() == &"", "Putting away a tool leaves hands free")
	var before: Vector2 = game.player
	game._process(1)
	require(game.player == before, "Inventory pauses gameplay")
	print("%s: %d inventory/tool checks, %d failures: slots, equipment, stacks, purpose, durability, overflow, sword, bow, UI and pause" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
