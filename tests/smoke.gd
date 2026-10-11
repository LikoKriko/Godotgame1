extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
		assert(condition, message)

func run_checks() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	check(game.health == 100.0 and game.level == 1, "Initial state")
	var cell := Vector2i(342, -172)
	var biome: int = game.biome_at(cell)
	game.terrain.seed = game.WORLD_SEED
	check(game.biome_at(cell) == biome, "Deterministic terrain")
	check(game.walkable(Vector2.ZERO), "Spawn must be walkable")
	game.gain_experience(20)
	check(game.level == 2 and game.skill_points == 1, "Experience levels")
	game.upgrade(0)
	check(game.max_health() == 120.0 and game.skill_points == 0, "Vitality upgrade")
	game.upgrade(0)
	check(game.ranks[0] == 1, "Cannot upgrade without points")
	game.skill_points = 10
	for i in 10:
		game.upgrade(1)
	check(game.ranks[1] == 5 and game.skill_points == 5, "Rank cap")
	for i in game.WEAPONS.size():
		game.restart()
		game.weapon_index = i
		game.enemies.append({"position": Vector2(40, 0), "health": 1.0, "kind": 0})
		game.attack(Vector2(100, 0))
		if game.WEAPONS[i]["ranged"]:
			check(game.projectiles.size() == 1, "Ranged shot")
			game._process(0.04)
		else:
			game.resolve_kills()
		check(game.kills == 1 and game.enemies.is_empty(), "Weapon kill %d" % i)
	game.restart()
	game.spawn_enemy()
	check(game.enemies.size() == 1, "Enemy spawn")
	game.enemies[0]["position"] = game.player
	game.health = 0.01
	game._process(0.1)
	check(game.dead, "Contact damage and death")
	game.restart()
	check(not game.dead and game.enemies.is_empty() and game.kills == 0, "Restart")
	game.skills_open = true
	game._process(1.0)
	check(game.survival_time == 0.0, "Skills pause gameplay")
	print("PASS: terrain, spawn, levels, skills, six weapons, damage, death, restart, pause")
	quit(0)
