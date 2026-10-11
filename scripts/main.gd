extends Node2D

const TILE := 64
const WORLD_SEED := 73129
const WEAPONS := [
	{"name": "Espada", "damage": 24.0, "range": 100.0, "cooldown": 0.5, "ranged": false},
	{"name": "Hacha", "damage": 42.0, "range": 85.0, "cooldown": 0.9, "ranged": false},
	{"name": "Lanza", "damage": 20.0, "range": 160.0, "cooldown": 0.6, "ranged": false},
	{"name": "Arco", "damage": 18.0, "range": 650.0, "cooldown": 0.45, "ranged": true},
	{"name": "Bastón", "damage": 32.0, "range": 500.0, "cooldown": 0.75, "ranged": true},
	{"name": "Dagas", "damage": 12.0, "range": 75.0, "cooldown": 0.22, "ranged": false}
]
const BRANCHES := ["Vitalidad", "Fuerza", "Agilidad", "Recuperación", "Cadencia", "Sabiduría"]
var terrain := FastNoiseLite.new()
var player := Vector2.ZERO
var health := 100.0
var experience := 0
var level := 1
var skill_points := 0
var ranks: Array[int] = [0, 0, 0, 0, 0, 0]
var weapon_index := 0
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var survival_time := 0.0
var spawn_timer := 1.0
var attack_timer := 0.0
var flash_timer := 0.0
var dead := false
var skills_open := false
var kills := 0
var camera: Camera2D
var character: AnimatedSprite2D
var movement = preload("res://scripts/turn_motion.gd").new()
var hud: Label
var skill_panel: PanelContainer
var skill_buttons: Array[Button] = []

func _ready() -> void:
	terrain.seed = WORLD_SEED
	terrain.frequency = 0.018
	character = AnimatedSprite2D.new()
	character.sprite_frames = preload("res://scripts/survivor_frames.gd").build()
	character.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	character.scale = Vector2(0.215, 0.215)
	character.position = player + Vector2(0, -14)
	add_child(character)
	camera = Camera2D.new()
	add_child(camera)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = Label.new()
	hud.position = Vector2(18, 12)
	hud.add_theme_font_size_override("font_size", 18)
	canvas.add_child(hud)
	skill_panel = PanelContainer.new()
	skill_panel.position = Vector2(230, 170)
	skill_panel.size = Vector2(500, 350)
	canvas.add_child(skill_panel)
	var box := VBoxContainer.new()
	skill_panel.add_child(box)
	var title := Label.new()
	title.text = "HABILIDADES · 6 ramas × 5 rangos\nCada rango requiere el anterior y un punto."
	box.add_child(title)
	for i in BRANCHES.size():
		var button := Button.new()
		button.pressed.connect(upgrade.bind(i))
		box.add_child(button)
		skill_buttons.append(button)
	var hint := Label.new()
	hint.text = "Pulsa Tab para volver al mundo."
	box.add_child(hint)
	restart()

func restart() -> void:
	player = Vector2.ZERO
	movement.reset()
	character.play(&"idle_down")
	health = 100.0
	experience = 0
	level = 1
	skill_points = 0
	ranks = [0, 0, 0, 0, 0, 0]
	weapon_index = 0
	enemies.clear()
	projectiles.clear()
	survival_time = 0.0
	spawn_timer = 1.0
	attack_timer = 0.0
	flash_timer = 0.0
	kills = 0
	dead = false
	skills_open = false
	camera.position = player
	character.position = player + Vector2(0, -14)
	update_hud()
	queue_redraw()

func max_health() -> float:
	return 100.0 + ranks[0] * 20.0

func upgrade(branch: int) -> void:
	if skill_points <= 0 or ranks[branch] >= 5:
		return
	skill_points -= 1
	ranks[branch] += 1
	if branch == 0:
		health = minf(health + 20.0, max_health())
	update_hud()

func gain_experience(amount: int) -> void:
	experience += int(amount * (1.0 + ranks[5] * 0.2))
	while experience >= level * 20:
		experience -= level * 20
		level += 1
		skill_points += 1

func biome_at(cell: Vector2i) -> int:
	var value := terrain.get_noise_2d(cell.x, cell.y)
	if value < -0.25:
		return 0
	if value > 0.25:
		return 2
	return 1

func tree_at(cell: Vector2i) -> bool:
	if Vector2(cell).length() < 3.0:
		return false
	var value := absi(cell.x * 73856093 ^ cell.y * 19349663 ^ WORLD_SEED)
	return value % 13 == 0 and biome_at(cell) != 0

func walkable(point: Vector2) -> bool:
	var cell := Vector2i(floori(point.x / TILE), floori(point.y / TILE))
	if not tree_at(cell):
		return true
	return point.distance_to(Vector2(cell) * TILE + Vector2(32, 32)) > 30.0

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.keycode == KEY_TAB and not dead:
		skills_open = not skills_open
	if event.keycode == KEY_R and dead:
		restart()
	if event.keycode >= KEY_1 and event.keycode <= KEY_6:
		weapon_index = event.keycode - KEY_1
	update_hud()

func _process(delta: float) -> void:
	if dead or skills_open:
		character.pause()
		return
	survival_time += delta
	attack_timer = maxf(attack_timer - delta, 0.0)
	flash_timer = maxf(flash_timer - delta, 0.0)
	health = minf(health + ranks[3] * 0.4 * delta, max_health())
	var direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	move_player(direction, delta)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_SPACE):
		attack(get_global_mouse_position())
	update_world(delta)

func move_player(direction: Vector2, delta: float) -> void:
	var previous := player
	var velocity: Vector2 = movement.step(direction, delta, 220.0 + ranks[2] * 22.0)
	var motion := velocity * delta
	if walkable(player + Vector2(motion.x, 0)):
		player.x += motion.x
	if walkable(player + Vector2(0, motion.y)):
		player.y += motion.y
	camera.position = player
	character.position = player + Vector2(0, -14)
	var moving := player.distance_squared_to(previous) > 0.00001
	var animation := StringName(("walk_" if moving else "idle_") + movement.facing())
	character.speed_scale = movement.speed_factor if moving else 1.0
	character.play(animation)

func update_world(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0.0 and enemies.size() < 80:
		spawn_enemy()
		spawn_timer = maxf(0.35, 2.0 - survival_time / 120.0)
	for enemy in enemies:
		var speed: float = 65.0 if enemy["kind"] == 0 else 110.0
		enemy["position"] = enemy["position"].move_toward(player, speed * delta)
		if enemy["position"].distance_to(player) < 26.0:
			health -= (12.0 if enemy["kind"] == 0 else 8.0) * delta
	for shot in projectiles:
		shot["position"] += shot["velocity"] * delta
		shot["life"] -= delta
		for enemy in enemies:
			if shot["life"] > 0.0 and shot["position"].distance_to(enemy["position"]) < 22.0:
				enemy["health"] -= shot["damage"]
				shot["life"] = 0.0
	projectiles = projectiles.filter(func(shot): return shot["life"] > 0.0)
	resolve_kills()
	if health <= 0:
		health = 0
		dead = true
	update_hud()
	queue_redraw()

func spawn_enemy() -> void:
	var angle := randf() * TAU
	var position := player + Vector2.from_angle(angle) * 580.0
	var kind := randi_range(0, 1)
	enemies.append({"position": position, "health": 45.0 if kind == 0 else 28.0, "kind": kind})

func attack(target: Vector2) -> void:
	if attack_timer > 0.0 or dead or skills_open:
		return
	var weapon: Dictionary = WEAPONS[weapon_index]
	attack_timer = weapon["cooldown"] / (1.0 + ranks[4] * 0.12)
	var damage: float = weapon["damage"] * (1.0 + ranks[1] * 0.15)
	var aim := player.direction_to(target)
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT
	if weapon["ranged"]:
		projectiles.append({"position": player, "velocity": aim * 650.0, "damage": damage, "life": weapon["range"] / 650.0})
	else:
		flash_timer = 0.12
		for enemy in enemies:
			var offset: Vector2 = enemy["position"] - player
			if offset.length() <= weapon["range"] and offset.normalized().dot(aim) >= 0.0:
				enemy["health"] -= damage

func resolve_kills() -> void:
	for enemy in enemies:
		if enemy["health"] <= 0.0:
			kills += 1
			gain_experience(10)
	enemies = enemies.filter(func(enemy): return enemy["health"] > 0.0)

func update_hud() -> void:
	hud.text = "VIDA %d / %d   NIVEL %d   EXP %d / %d   PUNTOS %d\n%s   |   Tiempo %ds   Bajas %d\nWASD/flechas · Clic/espacio: atacar hacia el cursor · 1–6: armas · Tab: habilidades" % [health, max_health(), level, experience, level * 20, skill_points, WEAPONS[weapon_index]["name"], survival_time, kills]
	if dead:
		hud.text += "\nHAS CAÍDO · Pulsa R para empezar otra partida"
	skill_panel.visible = skills_open
	var effects := ["+20 vida", "+15% daño", "+22 velocidad", "+0.4 vida/s", "+12% cadencia", "+20% experiencia"]
	for i in skill_buttons.size():
		skill_buttons[i].text = "%s %d/5 → %s" % [BRANCHES[i], ranks[i], effects[i]]
		skill_buttons[i].disabled = skill_points <= 0 or ranks[i] >= 5

func _draw() -> void:
	var center := Vector2i(floori(player.x / TILE), floori(player.y / TILE))
	var colors := [Color("806c45"), Color("23483c"), Color("33495f")]
	for y in range(center.y - 7, center.y + 8):
		for x in range(center.x - 9, center.x + 10):
			var cell := Vector2i(x, y)
			var origin := Vector2(cell) * TILE
			draw_rect(Rect2(origin, Vector2(TILE, TILE)), colors[biome_at(cell)])
			draw_rect(Rect2(origin, Vector2(TILE, TILE)), Color(0, 0, 0, 0.08), false)
			if tree_at(cell):
				draw_circle(origin + Vector2(32, 36), 20, Color("102c24"))
				draw_circle(origin + Vector2(32, 28), 19, Color("39764e"))
	for enemy in enemies:
		draw_circle(enemy["position"], 16 if enemy["kind"] == 0 else 12, Color("d95763") if enemy["kind"] == 0 else Color("eaa759"))
	for shot in projectiles:
		draw_circle(shot["position"], 5, Color("ffe29a"))
	if flash_timer > 0:
		draw_arc(player, WEAPONS[weapon_index]["range"], 0, TAU, 32, Color("ffe29a"), 2)
	draw_ellipse_shadow()
	draw_line(player, player + player.direction_to(get_global_mouse_position()) * 25, Color.WHITE, 3)

func draw_ellipse_shadow() -> void:
	draw_set_transform(player + Vector2(0, 17), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 19, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
