extends SceneTree
var failures := 0
var checks := 0
func _initialize(): call_deferred("run")
func check(value: bool,message: String):
	checks += 1
	if not value: failures += 1; push_error(message)
func run():
	var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false)
	game.bag.select_tool(&"bow"); game.equipping = false
	check(not game.start_work(Vector2(200,0)) and not game.working,"No ammunition means no attack animation")
	check(game.feedback == "Necesitas flechas para disparar el arco" and game.bag.held_item().uses == 60,"Missing ammunition shows the exact message without wear")
	check(not game.use_weapon(Vector2(200,0)) and get_nodes_in_group("player_arrows").is_empty(),"Direct fire cannot bypass ammunition")
	game.bag.add(&"flecha",2)
	check(game.start_work(Vector2(200,0)) and game.bag.held_item().uses == 59,"Drawing the string consumes one use immediately")
	game.advance_work(0.1); game.cancel_work()
	check(game.bag.count(&"flecha") == 2 and game.bag.held_item().uses == 59,"Cancelling a draw keeps the arrow but wears the bow")
	check(game.start_work(Vector2(200,0)),"A subsequent draw is possible")
	game.advance_work(0.499)
	check(game.bag.count(&"flecha") == 2 and get_nodes_in_group("player_arrows").is_empty(),"Six-frame draw does not fire before half a second")
	game.advance_work(0.001)
	check(game.bag.count(&"flecha") == 1 and game.bag.held_item().uses == 58,"Release consumes one arrow without charging a second use")
	var arrow = get_nodes_in_group("player_arrows")[0]; arrow.set_process(false)
	check(arrow.damage == 3,"Basic arrows take their three damage from the bow stats")
	game.cancel_work(); game.weapon_timer = 0; game.bag.held_item().uses = 1
	check(game.start_work(Vector2(200,0)) and game.bag.held_item().uses == 0,"Last usable draw can start")
	game.advance_work(0.5)
	check(game.bag.count(&"flecha") == 0 and get_nodes_in_group("player_arrows").size() == 2,"The final draw releases its arrow even after using the bow's last use")
	game.cancel_work(); game.weapon_timer = 0
	check(not game.start_work(Vector2(200,0)),"An exhausted bow cannot start another draw")
	var workshop = preload("res://scripts/workshop.gd")
	game.bag.add(&"palo",1); game.bag.add(&"piedra",1); game.bag.add(&"cuerda",1)
	check(workshop.craft(game.bag,&"flecha").is_empty() and game.bag.count(&"flecha") == 5,"One stick, one stone and one metre of cord create five arrows")
	game.free(); print("%s: %d bow ammunition checks, %d failures" % ["PASS" if not failures else "FAIL",checks,failures]); quit(1 if failures else 0)
