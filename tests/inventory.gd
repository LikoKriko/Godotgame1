extends SceneTree
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
	require(bag.consume_use() and bag.equipment[&"hands"]["uses"] == 29, "One use consumed")
	bag.select_tool(&"pickaxe")
	bag.select_tool(&"axe")
	require(bag.equipment[&"hands"]["uses"] == 29, "Swaps preserve durability")
	bag.equipment[&"hands"]["uses"] = 1
	require(bag.consume_use() and not bag.usable(), "Last use breaks tool")
	require(not bag.consume_use() and bag.equipment[&"hands"]["uses"] == 0, "Broken tool stays at zero")
	require(not bag.can_harvest("madera"), "Broken axe cannot gather")
	bag.reset()
	require(bag.add(&"madera", 120) and bag.count(&"madera") == 120, "Materials stack across slots")
	for item in bag.slots:
		if item.get("id", &"") == &"madera":
			require(item["quantity"] <= 99, "Stack limit respected")
	for i in 32:
		bag.slots[i] = bag.make_item(&"madera", 99)
	require(not bag.add(&"mineral", 1), "Full bag cannot accept new material")
	require(not bag.unequip(&"hands") and bag.held_id() == &"axe", "Full bag cannot lose unequipped item")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	var tree := Vector2i(-4, -3)
	game.player = game.resources.bounds(tree).position + Vector2(-24, 32)
	game.bag.select_tool(&"pickaxe")
	require(not game.start_work(tree), "Pickaxe does not chop trees")
	require(game.bag.equipment[&"hands"]["uses"] == 30, "Wrong use does not consume durability")
	game.bag.select_tool(&"axe")
	require(game.start_work(tree), "Axe chops trees")
	game.advance_work(0.1)
	game.cancel_work()
	require(game.bag.equipment[&"hands"]["uses"] == 30, "Cancel before impact preserves uses")
	game.start_work(tree)
	game.advance_work(0.7)
	require(game.bag.equipment[&"hands"]["uses"] == 29, "Resource impact consumes one use")
	game.resources.nodes[tree]["remaining"] = 1
	for i in 32:
		game.bag.slots[i] = game.bag.make_item(&"mineral", 99)
	game.start_work(tree)
	game.advance_work(0.7)
	require(game.resources.nodes[tree]["remaining"] == 1 and game.bag.equipment[&"hands"]["uses"] == 29, "Full inventory preserves resource and last-hit durability")
	game.restart()
	var rock: Vector2i = game.world.large_rocks.keys()[0]
	game.player = game.resources.bounds(rock).position + Vector2(-24, 32)
	game.bag.select_tool(&"axe")
	require(not game.start_work(rock), "Axe does not mine rocks")
	game.bag.select_tool(&"pickaxe")
	require(game.start_work(rock) and str(game.character.animation).begins_with("idle_"), "Mining works without a tool animation")
	game.advance_work(0.7)
	require(game.bag.equipment[&"hands"]["uses"] == 29, "Mining consumes a pickaxe use")
	for i in 5:
		game.start_work(rock)
		game.advance_work(0.7)
	require(game.bag.count(&"mineral") == 12 and not game.resources.nodes.has(rock), "Mined material enters backpack and node disappears")
	game.restart()
	game.bag.select_tool(&"sword")
	game.player = Vector2.ZERO
	var dummy := Target.new()
	dummy.position = Vector2(50, 0)
	root.add_child(dummy)
	dummy.add_to_group("damageable")
	require(game.use_weapon(Vector2(100, 0)), "Sword action")
	require(dummy.damage_received == 24 and game.bag.equipment[&"hands"]["uses"] == 39, "Sword affects combat targets and uses")
	require(not game.use_weapon(Vector2(100, 0)), "Weapon cooldown enforced")
	game.bag.select_tool(&"bow")
	game.weapon_timer = 0
	require(game.use_weapon(Vector2(100, 0)), "Bow shoots")
	var arrows := get_nodes_in_group("player_arrows")
	require(arrows.size() == 1 and game.bag.equipment[&"hands"]["uses"] == 59, "One arrow per bow use")
	var arrow = arrows[0]
	game.inventory_panel.show()
	var previous: Vector2 = arrow.position
	arrow._process(0.1)
	require(arrow.position == previous, "Inventory pauses projectiles")
	game.inventory_panel.hide()
	arrow._process(0.1)
	require(dummy.damage_received == 42, "Arrow hits only combat target")
	game.bag.select_tool(&"pickaxe")
	game.weapon_timer = 0
	require(not game.use_weapon(Vector2(100, 0)), "Pickaxe cannot attack")
	game.bag.select_tool(&"axe")
	require(not game.use_weapon(Vector2(100, 0)), "Axe cannot attack")
	game.bag.equipment[&"hands"]["uses"] = 0
	game.player = game.resources.bounds(tree).position + Vector2(-24, 32)
	require(not game.start_work(tree), "Broken equipped axe cannot start an action")
	game.bag.select_tool(&"sword")
	game.bag.equipment[&"hands"]["uses"] = 0
	require(not game.use_weapon(Vector2(100, 0)), "Broken sword cannot attack")
	game.bag.select_tool(&"axe")
	game.inventory_panel.show()
	game.inventory_panel.fit_panel()
	require(game.inventory_panel.backpack_buttons.size() == 32 and game.inventory_panel.gear_buttons.size() == 5, "Visible slot counts")
	var side: Vector2 = game.inventory_panel.panel.size
	require(is_equal_approx(side.x, side.y), "Inventory is square")
	var viewport_size := root.get_visible_rect().size
	var expected_side := minf(sqrt(viewport_size.x * viewport_size.y * 0.6), minf(viewport_size.x, viewport_size.y) * 0.95)
	require(is_equal_approx(side.x, expected_side), "Inventory follows 60-percent target while fitting widescreen viewport")
	var center: Vector2 = game.inventory_panel.panel.position + side / 2
	require(center.is_equal_approx(viewport_size / 2), "Inventory is centered")
	var sword_index := -1
	for i in Bag.CAPACITY:
		if game.bag.slots[i].get("id", &"") == &"sword":
			sword_index = i
	require(sword_index >= 0, "Sword preserved through equipment swaps")
	game.inventory_panel.select_backpack(sword_index)
	game.inventory_panel.equip_selected()
	require(game.bag.held_id() == &"sword", "UI equips selected object")
	game.inventory_panel.select_gear(&"hands")
	game.inventory_panel.remove_selected()
	require(game.bag.held_id() == &"", "UI removes equipment")
	var before: Vector2 = game.player
	game._process(1)
	require(game.player == before, "Inventory pauses gameplay")
	print("%s: %d inventory/tool checks, %d failures: slots, equipment, stacks, purpose, durability, overflow, sword, bow, UI and pause" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
