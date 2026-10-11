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
var world = preload("res://scripts/test_world.gd").new()
var terrain = world.terrain
var world_view: Node2D
var minimap: Control
var spawn_rng := RandomNumberGenerator.new()
var enemy_flow: Dictionary = {}
var flow_cell := Vector2i(99999, 99999)
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
	world.generate(WORLD_SEED)
	spawn_rng.randomize()
	world_view = preload("res://scripts/world_view.gd").new()
	world_view.configure(world)
	add_child(world_view)
	character = AnimatedSprite2D.new()
	character.sprite_frames = preload("res://scripts/survivor_frames.gd").build()
	character.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	character.scale = Vector2(0.215, 0.215)
	character.position = player + Vector2(0, -14)
	add_child(character)
	camera = Camera2D.new()
	camera.limit_left = int(world.bounds.position.x)
	camera.limit_top = int(world.bounds.position.y)
	camera.limit_right = int(world.bounds.end.x)
	camera.limit_bottom = int(world.bounds.end.y)
	add_child(camera)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var atmosphere := ColorRect.new()
	atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var atmosphere_material := ShaderMaterial.new()
	atmosphere_material.shader = preload("res://shaders/atmosphere.gdshader")
	atmosphere.material = atmosphere_material
	canvas.add_child(atmosphere)
	hud = Label.new()
	hud.position = Vector2(18, 12)
	hud.add_theme_font_size_override("font_size", 18)
	canvas.add_child(hud)
	minimap = preload("res://scripts/world_minimap.gd").new()
	minimap.world = world
	minimap.position = Vector2(744, 476)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(minimap)
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
	flow_cell = Vector2i(99999, 99999)
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
	return world.biome_at(cell)

func walkable(point: Vector2) -> bool:
	return world.walkable(point)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.keycode == KEY_TAB and not dead:
		skills_open = not skills_open
	if event.keycode == KEY_F2:
		world.generate(world.seed_value + 1)
		world_view.queue_redraw()
		restart()
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
	player = world.move_actor(player, motion)
	camera.position = player
	character.position = player + Vector2(0, -14)
	var moving := player.distance_squared_to(previous) > 0.00001
	var animation := StringName(("walk_" if moving else "idle_") + movement.facing())
	character.speed_scale = movement.speed_factor if moving else 1.0
	character.play(animation)

func update_world(delta: float) -> void:
	var current_cell: Vector2i = world.cell_at(player)
	if current_cell != flow_cell:
		enemy_flow = world.flow_to(player)
		flow_cell = current_cell
	spawn_timer -= delta
	if spawn_timer <= 0.0 and enemies.size() < 80:
		spawn_enemy()
		spawn_timer = maxf(0.35, 2.0 - survival_time / 120.0)
	for enemy in enemies:
		var speed: float = 65.0 if enemy["kind"] == 0 else 110.0
		var enemy_cell: Vector2i = world.cell_at(enemy["position"])
		var target := player
		if enemy_cell != current_cell:
			var step: Vector2i = enemy_flow.get(enemy_cell, Vector2i.ZERO)
			target = world.center(enemy_cell + step)
			# Center the perpendicular axis before entering the next corridor.
			var cell_center: Vector2 = world.center(enemy_cell)
			if step.x != 0 and absf(enemy["position"].y - cell_center.y) > 3:
				target = cell_center
			elif step.y != 0 and absf(enemy["position"].x - cell_center.x) > 3:
				target = cell_center
		var displacement: Vector2 = enemy["position"].direction_to(target) * minf(speed * delta, enemy["position"].distance_to(target))
		enemy["position"] = world.move_actor(enemy["position"], displacement, 14.0)
		if enemy["position"].distance_to(player) < 26.0:
			health -= (12.0 if enemy["kind"] == 0 else 8.0) * delta
	for shot in projectiles:
		shot["position"] += shot["velocity"] * delta
		shot["life"] -= delta
		if not world.walkable(shot["position"], 4.0):
			shot["life"] = 0.0
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
	var position: Vector2 = world.spawn_position(player, spawn_rng)
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
	hud.text += "\nZona de cuarentena · Semilla %d · F2: nuevo mapa" % world.seed_value
	minimap.player = player
	minimap.queue_redraw()
	if dead:
		hud.text += "\nHAS CAÍDO · Pulsa R para empezar otra partida"
	skill_panel.visible = skills_open
	var effects := ["+20 vida", "+15% daño", "+22 velocidad", "+0.4 vida/s", "+12% cadencia", "+20% experiencia"]
	for i in skill_buttons.size():
		skill_buttons[i].text = "%s %d/5 → %s" % [BRANCHES[i], ranks[i], effects[i]]
		skill_buttons[i].disabled = skill_points <= 0 or ranks[i] >= 5

func _draw() -> void:
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
