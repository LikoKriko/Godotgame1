extends SceneTree
## Uses mouse events, rather than calling inventory actions directly.
const Settings = preload("res://scripts/game_settings.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run_checks")
func require(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
func settle() -> void:
	await process_frame
	await process_frame
func click(button: Control) -> void:
	await settle()
	var point := button.get_global_rect().get_center()
	Input.warp_mouse(point)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.position = point
		event.global_position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
	await settle()
func run_checks() -> void:
	var had_config := FileAccess.file_exists(Settings.PATH)
	var original: PackedByteArray = FileAccess.get_file_as_bytes(Settings.PATH) if had_config else PackedByteArray()
	var app = load("res://scenes/day_zero.tscn").instantiate()
	root.add_child(app)
	await settle()
	require(app.menu.visible and not is_instance_valid(app.game),"Startup shows Day Zero menu without launching a game")
	require(is_equal_approx(app.menu.title_area.size.x,app.menu.size.x*0.6),"Title occupies the right 60 percent")
	await click(app.menu.settings_button)
	require(is_instance_valid(app.menu.settings_panel),"Mouse opens settings")
	if is_instance_valid(app.menu.settings_panel):
		var screen = app.menu.settings_panel
		screen.volume_sliders["music"].value = 25
		screen.pending["fps"] = 120
		screen.apply_changes()
		var saved = Settings.new()
		saved.load_settings()
		require(saved.values["music"] == 0.25 and saved.values["fps"] == 120,"Sound and graphics preferences survive reload")
		require(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))),0.25),"Music slider applies to the audio bus")
		app.menu.close_settings()
	await click(app.menu.play_button)
	require(is_instance_valid(app.game) and not app.menu.visible,"Mouse Play enters the game")
	if is_instance_valid(app.game):
		var game = app.game
		game.set_process(false)
		game.bag.add(&"piedra",10)
		game.bag.add(&"palo",10)
		game.bag.add(&"cuerda",2)
		var inventory = game.inventory_panel
		inventory.refresh()
		inventory.show()
		await settle()
		await click(inventory.backpack_buttons[0])
		require(inventory.chosen == 0 and not inventory.equip_button.disabled,"Mouse selects a weapon and enables Equip")
		await click(inventory.equip_button)
		require(game.bag.held_id() == &"sword" and inventory.chosen_gear == &"hands","Mouse Equip swaps the item into the hands slot")
		require(not inventory.remove_button.disabled,"Equipping immediately enables Unequip")
		await click(inventory.remove_button)
		require(game.bag.held_id() == &"","Mouse Unequip returns the item to the backpack")
		var sword_index := -1
		var stone_index := -1
		for i in game.bag.CAPACITY:
			if game.bag.slots[i].get("id",&"") == &"sword":
				sword_index = i
			if game.bag.slots[i].get("id",&"") == &"piedra":
				stone_index = i
		require(stone_index >= 0 and sword_index >= 0,"Materials and unequipped weapon remain in inventory")
		if stone_index >= 0:
			var slot: Button = inventory.backpack_buttons[stone_index]
			require(slot.get_node("ItemIcon").texture != null and slot.get_node("Amount").text == "10","Stone slot shows an image and a small quantity of 10")
		if sword_index >= 0:
			game.bag.slots[sword_index]["uses"] = 7
			await click(inventory.backpack_buttons[sword_index])
			await click(inventory.repair_button)
			require(is_instance_valid(inventory.workshop_dialog),"Mouse Repair opens an object-and-materials window")
			await click(inventory.workshop_confirm)
			require(game.bag.slots[sword_index]["uses"] == 40 and game.bag.count(&"piedra") == 8,"Mouse repair restores the selected weapon and spends its materials")
			inventory.close_workshop()
		await click(inventory.craft_button)
		require(is_instance_valid(inventory.workshop_dialog) and inventory.workshop_mode == "craft","Mouse opens crafting")
		await click(inventory.workshop_confirm)
		require(game.bag.count(&"pickaxe") == 2 and game.bag.count(&"piedra") == 6 and game.bag.count(&"cuerda") == 1,"Mouse crafting creates a separate pickaxe with the exact recipe")
		inventory.close_workshop()
		var ration_index := -1
		var water_index := -1
		for i in game.bag.CAPACITY:
			if game.bag.slots[i].get("id") == &"ration":
				ration_index = i
			if game.bag.slots[i].get("id") == &"water":
				water_index = i
		if ration_index >= 0:
			await click(inventory.backpack_buttons[ration_index])
			require(inventory.equip_button.text == "Comer" and inventory.backpack_buttons[ration_index].get_node("ItemIcon").texture != null,"Food shows its icon and eating action")
			await click(inventory.equip_button)
			require(game.nutrition.calories_today == 400 and game.bag.count(&"ration") == 7,"Real mouse click eats one ration")
		if water_index >= 0:
			game.nutrition.hydration_ml = 1000
			await click(inventory.backpack_buttons[water_index])
			await click(inventory.equip_button)
			require(game.nutrition.hydration_ml == 1500 and game.bag.count(&"water") == 7,"Real mouse click drinks one bottle")
		inventory.hide()
		app.show_pause()
		require(game.is_paused() and app.menu.visible,"Pause menu suspends the game")
		await click(app.menu.play_button)
		require(not game.is_paused() and not app.menu.visible,"Continue resumes the existing game")
		app.show_pause()
		await click(app.menu.return_button)
		require(not is_instance_valid(app.game) and app.menu.visible,"Main menu releases the current game")
	# Restore the pre-test preferences instead of changing the player's settings.
	if had_config:
		var file := FileAccess.open(Settings.PATH,FileAccess.WRITE)
		file.store_buffer(original)
		file.close()
	else:
		DirAccess.remove_absolute(Settings.PATH)
	print("%s: %d GUI checks, %d failures: menu, saved settings, actual mouse equip/unequip, quantities, repair and crafting" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(0 if failures == 0 else 1)
