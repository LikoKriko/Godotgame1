extends SceneTree
const Cycle = preload("res://scripts/day_cycle.gd")
const Nutrition = preload("res://scripts/nutrition.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Tools = preload("res://scripts/tool_sprites.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func require(condition: bool,message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
func run() -> void:
	var clock = Cycle.new()
	clock.hour = 23.9
	require(clock.advance(12) == 1 and clock.day == 2 and is_equal_approx(clock.hour,0.1),"Midnight advances one day without discarding overflow time")
	require(clock.advance(3*Cycle.DAY_SECONDS) == 3 and clock.day == 5,"Long frames count all elapsed days")
	clock.reset()
	require(clock.hour == 8 and clock.day == 1,"New game starts at 08:00 on day one")
	var samples := {}
	for hour in [0,6,7,9,12,15,19,20,23]:
		clock.hour = hour
		samples[hour] = clock.sun_state()
	require(not samples[0]["visible"] and samples[0]["shadow_alpha"] == 0,"No solar light or solar shadows at night")
	require(samples[12]["shadow_alpha"] > samples[7]["shadow_alpha"] and samples[15]["shadow_alpha"] > samples[19]["shadow_alpha"],"Shadows are stronger at midday/afternoon than first/last sunlight")
	require(samples[7]["direction"].x < 0 and samples[19]["direction"].x > 0,"Shadow direction follows solar travel")
	require(samples[7]["stretch"] > samples[12]["stretch"],"Low sun produces longer shadows")
	var nutrition = Nutrition.new()
	for entry in [[0,0.0],[1599,0.0],[1600,0.01],[1799,0.01],[1800,0.03],[1999,0.03],[2000,0.06],[2200,0.06],[2201,0.10],[2399,0.10],[2400,0.24],[10000,0.24]]:
		nutrition.calories_today = entry[0]
		require(is_equal_approx(nutrition.speed_penalty(),entry[1]),"Exact calorie threshold: %d" % entry[0])
	var bag = Inventory.new()
	bag.reset()
	bag.add(&"ration",2)
	var index := -1
	for i in bag.CAPACITY:
		if bag.slots[i].get("id") == &"ration":
			index = i
	nutrition.reset()
	require(nutrition.consume(bag,index)["ok"] and nutrition.calories_today == 400 and bag.count(&"ration") == 1,"Eating consumes one item and adds its calories")
	nutrition.consume(bag,index)
	require(bag.slots[index].is_empty() and nutrition.calories_today == 800,"Last portion frees its inventory slot")
	require(not nutrition.consume(bag,index)["ok"],"Empty slot cannot create calories")
	bag.add(&"water",2)
	for i in bag.CAPACITY:
		if bag.slots[i].get("id") == &"water":
			index = i
	require(not nutrition.consume(bag,index)["ok"] and bag.count(&"water") == 2,"Full hydration conserves bottled water")
	nutrition.advance(Cycle.DAY_SECONDS/2,Cycle.DAY_SECONDS)
	require(is_equal_approx(nutrition.hydration_ml,1000),"Hydration decreases by one litre per half day")
	require(nutrition.consume(bag,index)["ok"] and nutrition.hydration_ml == 1500 and nutrition.calories_today == 800,"Water restores hydration without calories")
	nutrition.new_day()
	require(nutrition.calories_today == 0 and nutrition.speed_penalty() == 0 and nutrition.hydration_ml == 1500,"Midnight clears daily calories/penalty but does not refill hydration")
	for id in Tools.DISPLAY_SIZES:
		var geometry := Tools.geometry(id)
		var size: Vector2 = geometry["texture"].get_size()
		var scale: float = Tools.reach_length(id)/geometry["grip"].distance_to(geometry["contact"])
		require(is_equal_approx(maxf(size.x,size.y)*scale,Tools.DISPLAY_SIZES[id]),"Visible tool dimensions agree with collision scale")
	require(Tools.DISPLAY_SIZES[&"axe"] == Tools.DISPLAY_SIZES[&"pickaxe"],"Axe and pickaxe share the same visible size")
	require(Tools.DISPLAY_SIZES[&"sword"] == preload("res://scripts/survivor_frames.gd").CHARACTER_HEIGHT/2,"Sword measures half the character height")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.nutrition.calories_today = 2400
	game.player = Vector2.ZERO
	game.movement.reset()
	game.move_player(Vector2.DOWN,0.1)
	require(is_equal_approx(game.player.y,70*0.76*0.1),"24% penalty changes actual gameplay movement")
	game.menu_open = true
	var hour: float = game.day_cycle.hour
	var water: float = game.nutrition.hydration_ml
	game._process(30)
	require(game.day_cycle.hour == hour and game.nutrition.hydration_ml == water,"Menus pause both time and hydration")
	game.menu_open = false
	game.day_cycle.hour = 23.99
	game._process(1)
	require(game.day_cycle.day == 2 and game.nutrition.calories_today == 0,"Gameplay midnight resets its nutrition ledger")
	game.bag.add(&"ration",1)
	for i in game.bag.CAPACITY:
		if game.bag.slots[i].get("id") == &"ration":
			game.inventory_panel.select_backpack(i)
			break
	require(game.inventory_panel.equip_button.text == "Comer" and not game.inventory_panel.equip_button.disabled,"Inventory exposes eating through its action button")
	game.inventory_panel.equip_selected()
	require(game.nutrition.calories_today == 400,"Inventory action reaches the gameplay nutrition system")
	game.restart()
	require(game.day_cycle.day == 1 and game.day_cycle.hour == 8 and game.nutrition.calories_today == 0 and game.nutrition.hydration_ml == 2000,"Restart restores survival state")
	print("%s: %d survival checks, %d failures: clock, sunlight, tools, calories, water, pause, inventory and movement" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(0 if failures == 0 else 1)
