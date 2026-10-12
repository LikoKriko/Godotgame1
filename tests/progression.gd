extends SceneTree
const Progression = preload("res://scripts/progression.gd")
var checks := 0
var failures := 0
class Target:
	extends Node2D
	var damage := 0.0
	func take_damage(value: float) -> void: damage += value
func _initialize() -> void: call_deferred("run")
func require(value: bool,message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func close_to(a: float,b: float) -> bool: return absf(a-b) < 0.001
func key(code: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code; event.physical_keycode = code; event.pressed = pressed
		Input.parse_input_event(event); Input.flush_buffered_events()
func run() -> void:
	var progress := Progression.new()
	progress.reset()
	require(progress.health == 20 and progress.max_health() == 20,"Base health is 20")
	require(close_to(progress.critical_chance(),0.01),"Base critical chance is 1 percent")
	require(close_to(progress.combat_damage(10,0),11),"Critical multiplier is 1.1")
	for next_level in range(1,11): require(Progression.skill_cost(next_level) == int(pow(2,next_level-1)),"Ability costs double per level")
	for next_phase in range(1,31): require(Progression.perk_cost(next_phase) == maxi(2,next_phase),"Perk unlock includes first phase; subsequent phases cost their phase number")
	for id in progress.perks:
		require(progress.purchase(id,false,1) == 0 and progress.perks[id] == 0,"Insufficient perk points cannot mutate ranks")
		require(progress.purchase(id,false,2) == 2 and progress.perks[id] == 1,"Two points unlock perk with phase one")
		require(progress.purchase(id,false,2) == 2 and progress.perks[id] == 2,"Two further points buy phase two")
		require(progress.purchase(id,false,100) == 0 and progress.perks[id] == 2,"Unavailable perk phases cannot be bought")
	require(close_to(progress.health,24) and close_to(progress.max_health(),24),"Vitality phases add two HP each")
	require(close_to(progress.attack_multiplier(),1.2),"Two attack phases add 20 percent")
	require(close_to(progress.critical_chance(),0.11),"Two critical phases add ten percentage points")
	progress.take_damage(6)
	require(close_to(progress.health,18),"Health is used by damage, not just displayed")
	for id in progress.skills:
		require(not progress.activate(id),"Locked abilities cannot activate")
		require(progress.purchase(id,true,1) == 1,"Abilities unlock with one shared point")
		require(progress.purchase(id,true,100) == 0,"Only ability level one is enabled")
		require(progress.activate(id) and not progress.activate(id),"Activation starts cooldown and cannot repeat")
	require(progress.speed_multiplier() == 1.25,"Speed burst adds 25 percent")
	require(close_to(progress.combat_damage(10,0.9),18),"Power hit adds fifty percent on top of attack")
	require(close_to(progress.combat_damage(10,0.9),12),"Power hit is consumed once")
	progress.advance(5)
	require(progress.speed_multiplier() == 1 and progress.cooldowns[&"speed"] == 15 and progress.cooldowns[&"power"] == 10,"Active duration and distinct cooldowns advance independently")
	progress.advance(15)
	require(progress.activate(&"power"),"Ability is ready after cooldown")
	progress.advance(5.01)
	require(close_to(progress.combat_damage(10,0.9),12),"Unused powered hit expires after five seconds")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game); game.set_process(false)
	game.gain_experience(60)
	require(game.level == 3 and game.skill_points == 2,"Each of two levels grants exactly one shared point")
	var inventory = game.inventory_panel
	inventory.open_section(3)
	var perks_page = inventory.sections[3]
	perks_page.select(&"life"); perks_page.purchase()
	require(game.skill_points == 0 and game.progression.perks[&"life"] == 1 and game.progression.max_health() == 22,"Perks page spends shared points and applies real health")
	require(perks_page.purchase_button.disabled,"Button cannot spend unavailable points")
	game.gain_experience(60)
	inventory.open_section(2)
	var abilities = inventory.sections[2]
	abilities.select(&"speed"); abilities.purchase(); abilities.activate()
	require(game.skill_points == 0 and game.progression.active[&"speed"] == 5,"Skill page uses the same bank and activates the bonus")
	game._process(2)
	require(game.progression.active[&"speed"] == 5 and game.progression.cooldowns[&"speed"] == 20,"Inventory pause freezes ability duration and cooldown")
	inventory.hide()
	game.movement.reset(); game.move_player(Vector2.RIGHT,1)
	require(close_to(game.player.x,87.5),"Speed bonus changes actual walking displacement")
	game.running = true
	game.player = Vector2.ZERO; game.movement.reset()
	game.move_player(Vector2.RIGHT,1)
	require(close_to(game.player.x,140),"Speed ability combines with the running multiplier")
	game.running = false
	game._process(5.1)
	require(game.progression.speed_multiplier() == 1,"Gameplay advances and expires burst")
	game.skill_points = 1; game.buy_improvement(&"power",true)
	key(KEY_X)
	require(game.progression.active[&"power"] == 5,"X activates the unlocked power skill")
	game.bag.select_tool(&"sword"); game.weapon_timer = 0
	game.progression.rng.seed = 42
	var target := Target.new(); target.position = game.player+Vector2(20,0)
	game.add_child(target); target.add_to_group("damageable")
	game.use_weapon(game.player+Vector2(500,0))
	require(game.progression.active[&"power"] == 5 and target.damage == 0,"Swinging at air does not consume the powered hit")
	game.weapon_timer = 0
	var pose := {"reachable":true}
	game.use_weapon(target.global_position,false,pose)
	require(close_to(target.damage,36) and game.progression.active[&"power"] == 0,"Successful sword hit receives power bonus")
	game.progression.cooldowns[&"power"] = 0; key(KEY_X)
	game.bag.select_tool(&"bow"); game.weapon_timer = 0
	game.use_weapon(target.global_position)
	require(game.progression.active[&"power"] == 5,"Arrow release preserves powered hit until impact")
	var arrows := get_nodes_in_group("player_arrows")
	var arrow = arrows[-1]
	arrow.set_process(false); arrow.position = target.global_position-Vector2(3,0); arrow.velocity = Vector2(30,0)
	arrow._process(0.1)
	require(close_to(target.damage,63) and game.progression.active[&"power"] == 0,"Arrow impact consumes power and adds 27 damage")
	game.progression.cooldowns[&"speed"] = 0; key(KEY_Z)
	require(game.progression.active[&"speed"] == 5,"Z activates the movement ability")
	game.restart()
	require(game.progression.health == 20 and game.skill_points == 0 and game.progression.skills[&"speed"] == 0,"New run resets progression and temporary effects")
	print("%s: %d progression/combat/UI checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(1 if failures else 0)
