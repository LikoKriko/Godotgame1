extends SceneTree
const Enemy = preload("res://scripts/enemy.gd")
const Save = preload("res://scripts/save_game.gd")
var failures := 0
var checks := 0
var game
func _initialize() -> void: call_deferred("run")
func require(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func encounter():
	game.player = Vector2.ZERO; game.progression.health = 20; game.enemies.reset()
	var enemy = game.enemies.enemy
	enemy.position = Vector2(25,0); enemy.update_sprite(); enemy.advance(0)
	return enemy
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false)
	var enemy = game.enemies.enemy
	require(is_instance_valid(enemy) and get_nodes_in_group("damageable").size() == 1,"One young creature spawns outside the initial danger area")
	require(enemy.position.length() >= 280 and enemy.health == 10 and Enemy.SPEED == 70*0.8,"Young enemy has ten HP and twenty percent less speed than walking")
	require(enemy.clips.world_height == 32 and enemy.clips.source == "Day_Zero_Enemigo_Joven_4_Vistas.png","Only the young reference is used, at 32 world units")
	for name in ["idle","walk","attack_left","attack_right"]:
		var clip: Dictionary = enemy.clips[name]
		require(clip.directions == 16 and clip.frames == (1 if name == "idle" else (12 if name == "walk" else 16)),"The exported direction/frame contract is retained: "+name)
	for direction in 16:
		enemy.heading = direction*TAU/16; enemy.update_sprite()
		require(enemy.atlas.region.position.y == direction*enemy.clips.canvas[1],"Runtime preserves every authored direction")
	require(not enemy.contains_point(enemy.sprite.to_global(-enemy.atlas.get_size()/2+Vector2(1,1))),"Transparent sprite padding cannot receive damage")
	enemy.position = Vector2(251,0); var origin: Vector2 = enemy.position
	game.enemies.advance(0.1)
	require(enemy.position == origin and enemy.state == &"idle","Outside the 250-unit radius the creature waits")
	enemy.position = Vector2(100,0); origin = enemy.position; game.enemies.advance(0.1)
	require(absf(enemy.position.distance_to(origin)-5.6) < 0.001 and enemy.state == &"walk","Chasing travels at the specified speed and animates")
	enemy = encounter(); game.enemies.advance(0.5)
	require(game.progression.health == 20 and game.enemies.parry.pending.size() == 1,"A punch connects at half its one-second sequence but defers health damage")
	game.enemies.advance(0.349)
	require(game.progression.health == 20,"Damage has not applied before 0.35 seconds")
	game.enemies.advance(0.002)
	require(game.progression.health == 18,"The delayed punch applies exactly two damage")
	game.enemies.advance(0.65)
	require(not enemy.punch_left and game.enemies.parry.pending.size() == 1,"The next punch alternates hands and connects one second after the first")
	enemy = encounter(); require(game.enemies.activate_parry(),"F is available initially")
	game.enemies.advance(0.5)
	require(enemy.stun_remaining > 1.49 and game.enemies.parry.pending.is_empty() and game.progression.health == 20,"A parry half a second before contact cancels damage and stuns for 1.5 s")
	require(not game.enemies.activate_parry(),"Parry cannot be repeated during its four-second cooldown")
	enemy = encounter(); game.enemies.advance(0.69)
	require(game.enemies.activate_parry() and enemy.stun_remaining == 1.5 and game.enemies.parry.pending.is_empty(),"A parry 0.19 s after contact still cancels the queued damage")
	game.enemies.advance(0.2); require(game.progression.health == 20,"A deflected pending hit never applies later")
	enemy = encounter(); game.enemies.advance(0.701); game.enemies.activate_parry()
	require(enemy.stun_remaining == 0 and not game.enemies.parry.pending.is_empty(),"After 0.2 s the post-contact parry window has closed")
	game.enemies.advance(0.151); require(game.progression.health == 18,"An out-of-window attempt cannot prevent the original delayed hit")
	enemy = encounter(); game.enemies.advance(0.6)
	var state := Save.capture(game)
	require(Save.valid(state) and Save.restore(game,state),"An in-progress enemy attack and pending hit survive save/restore")
	require(game.enemies.parry.pending.size() == 1 and absf(game.enemies.enemy.attack_elapsed-0.6) < 0.001,"Restoration preserves punch phase and delayed damage")
	game.enemies.advance(0.251); require(game.progression.health == 18,"Restored damage applies once, with its remaining delay")
	enemy = encounter(); game.enemies.advance(0.2)
	var clock: float = game.enemies.parry.time; var phase: float = enemy.attack_elapsed
	game.inventory_panel.show(); game._process(1)
	require(game.enemies.parry.time == clock and enemy.attack_elapsed == phase,"Inventory pauses combat and parry timers")
	game.inventory_panel.hide()
	enemy = encounter(); game.bag.select_tool(&"sword"); game.weapon_timer = 0
	require(enemy.contains_point(enemy.hit_center()) and game.use_weapon(enemy.hit_center()),"A sword can select an opaque enemy surface at close range")
	require(enemy.health > 0 and not game.combat_effects.flashes.is_empty(),"A three-damage sword strike emits contact shock without instantly killing ten HP")
	for i in 3:
		game.weapon_timer = 0; game.use_weapon(enemy.hit_center())
	require(enemy.health == 0 and game.enemies.defeated,"Four basic sword strikes defeat the ten-HP creature")
	state = Save.capture(game); require(Save.valid(state) and Save.restore(game,state) and not is_instance_valid(game.enemies.enemy),"A defeated enemy stays defeated after continuing a saved game")
	enemy = encounter()
	var arrow = preload("res://scripts/arrow.gd").new(); arrow.world = game.world; arrow.game = game
	game.add_child(arrow); arrow.set_process(false); arrow.position = enemy.hit_center()-Vector2(3,0); arrow.velocity = Vector2(60,0); arrow._process(0.05)
	require(enemy.health > 0 and enemy.health <= 7,"A three-damage arrow impacts opaque enemy pixels without instantly killing ten HP")
	print("%s: %d young enemy/combat checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	game.free(); quit(1 if failures else 0)
