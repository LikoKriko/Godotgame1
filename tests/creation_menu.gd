extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func require(value: bool,message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func key(code: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	var inventory = game.inventory_panel
	require(inventory.navigation.tab_count == 7,"Seven sections include the embedded map, quests and achievements")
	for i in 4:
		require(inventory.navigation.get_tab_title(i) == ["Inventario","Creación","Habilidades","Perks"][i],"Correct section names and order")
	key(KEY_T)
	require(inventory.visible and inventory.navigation.current_tab == 1 and game.is_paused(),"T opens Creación and pauses gameplay")
	var page = inventory.creation_page
	page.select_recipe(&"pickaxe")
	require(page.create_button.disabled,"Cannot create without its materials")
	game.bag.add(&"piedra",2)
	game.bag.add(&"palo",2)
	game.bag.add(&"cuerda",1)
	page.refresh()
	require(not page.create_button.disabled and page.preview.texture != null,"Available ingredients enable Crear with the actual tool preview")
	var before: int = game.bag.count(&"pickaxe")
	page.create_selected()
	require(page.is_crafting() and game.bag.count(&"pickaxe") == before,"Creation reserves ingredients without immediately delivering the tool")
	page.advance_creation(1.99)
	require(game.bag.count(&"pickaxe") == before,"Tool is not delivered before two seconds")
	page.advance_creation(0.01)
	require(game.bag.count(&"pickaxe") == before+1 and game.bag.count(&"piedra") == 0 and game.bag.count(&"palo") == 0 and game.bag.count(&"cuerda") == 0,"Pico consumes precisely 2 stones, 2 sticks and 1 metre of rope")
	var identities := {}
	for item in game.bag.slots:
		if item.get("id") == &"pickaxe":
			require(item["quantity"] == 1 and not identities.has(item["uid"]),"Every tool retains its own inventory slot and identity")
			identities[item["uid"]] = true
	page.create_selected()
	require(game.bag.count(&"pickaxe") == before+1,"Rejected crafting cannot create a free item")
	game.bag.add(&"fibra",3)
	page.select_recipe(&"cuerda")
	page.create_selected()
	page.advance_creation(2.0)
	require(game.bag.count(&"cuerda") == 1 and game.bag.count(&"fibra") == 0,"Cuerda recipe produces one metre")
	key(KEY_I)
	require(inventory.visible and inventory.navigation.current_tab == 0,"I returns from creation to the inventory")
	key(KEY_ESCAPE)
	require(not inventory.visible and not game.is_paused(),"Esc closes the menu and resumes gameplay")
	print("%s: %d creation/navigation checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(1 if failures else 0)
