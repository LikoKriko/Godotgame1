extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func require(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false)
	var ui = game.inventory_panel
	ui.open_section(0)
	require(ui.navigation.tab_count == 5 and ui.sections.size() == 5,"The template has Inventory, Creation, Abilities, Perks and Map")
	for i in 32:
		var button: Button = ui.backpack_buttons[i]
		require(button.position == Vector2(194+(i%8)*72,648+(i/8)*72) and button.size == Vector2(64,64),"All 32 slots form four rows of eight within the backpack frame")
	require(ui.improve_button.disabled and ui.dismantle_button.disabled,"Undefined item actions remain disabled")
	for i in 5:
		ui.navigation.buttons[i].pressed.emit()
		require(ui.navigation.current_tab == i and ui.sections[i].visible,"Each template tab opens its own page")
		for other in 5:
			if other != i: require(not ui.sections[other].visible,"Previous pages cannot block the visible page")
	var map = ui.sections[4].get_node("Terrain")
	require(map.ground != null and not game.world_map.visible and game.is_paused(),"The map appears inside the inventory and pauses gameplay")
	var expected: Vector2 = (game.player-game.world.bounds.position)/game.world.bounds.size*map.size
	require(map.world_to_map(game.player).is_equal_approx(expected),"Embedded map marks the player's actual position")
	ui.open_section(0); ui.select_backpack(0)
	require(not ui.equip_button.visible,"Equippable objects are moved by dragging, without an Equip button")
	game.bag.add(&"botella",1)
	var bottle: int = -1
	for i in 32:
		if game.bag.slots[i].get("id") == &"botella": bottle = i; break
	ui.select_backpack(bottle)
	require(ui.equip_button.visible and ui.equip_button.text == "Beber","The explicit drinking action remains available for bottles")
	ui.select_gear(&"hands")
	require(ui.gear_buttons[&"hands"].get_node("ItemIcon").texture != null,"Empty equipment slots use the template's silhouette icons")
	require(ui.details.size.x <= 310 and ui.capacity_label.size.x <= 114,"Descriptions and capacity stay within their frames")
	for i in range(4):
		var a: Button = ui.navigation.buttons[i]; var b: Button = ui.navigation.buttons[i+1]
		require(a.position.x+a.size.x <= b.position.x,"Tab text cannot enlarge controls over their neighbours")
	print("%s: %d inventory template checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	game.free(); quit(1 if failures else 0)
