extends Node2D

const TILE := 64
const WORLD_SEED := 73129
const BRANCHES := ["Silvicultura", "Minería", "Agilidad", "Reciclaje", "Ritmo", "Sabiduría"]
const HARVEST_TIME := 0.6
var resources = preload("res://scripts/harvesting.gd").new()
var focused := Vector2i(99999, 99999)
var working := false
var work_target := Vector2i(99999, 99999)
var work_elapsed := 0.0
var work_duration := HARVEST_TIME
var hit_applied := false
var feedback := ""
var feedback_time := 0.0
var impact_position := Vector2.ZERO
var impact_time := 0.0
var interaction: Label
var world = preload("res://scripts/test_world.gd").new()
var terrain = world.terrain
var world_view: Node2D
var minimap: Control
var player := Vector2.ZERO
var experience := 0
var level := 1
var skill_points := 0
var ranks: Array[int] = [0, 0, 0, 0, 0, 0]
var skills_open := false
var camera: Camera2D
var character: AnimatedSprite2D
var movement = preload("res://scripts/turn_motion.gd").new()
var hud: Label
var skill_panel: PanelContainer
var skill_buttons: Array[Button] = []

func _ready() -> void:
	world.generate(WORLD_SEED)
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
	interaction = Label.new()
	interaction.position = Vector2(18, 568)
	interaction.add_theme_font_size_override("font_size", 18)
	canvas.add_child(interaction)
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
	world.generate(world.seed_value)
	world_view.refresh_ground()
	resources.configure(world)
	player = Vector2.ZERO
	movement.reset()
	character.play(&"idle_down")
	experience = 0
	level = 1
	skill_points = 0
	ranks = [0, 0, 0, 0, 0, 0]
	working = false
	work_elapsed = 0.0
	focused = resources.NONE
	feedback = ""
	feedback_time = 0.0
	impact_time = 0.0
	skills_open = false
	camera.position = player
	character.position = player + Vector2(0, -14)
	update_hud()
	queue_redraw()

func upgrade(branch: int) -> void:
	if working or skill_points <= 0 or ranks[branch] >= 5:
		return
	skill_points -= 1
	ranks[branch] += 1
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
	if event.keycode == KEY_TAB:
		skills_open = not skills_open
		if skills_open:
			cancel_work()
	if event.keycode == KEY_F2:
		world.seed_value += 1
		restart()
	if event.keycode == KEY_R:
		restart()
	update_hud()

func _process(delta: float) -> void:
	if skills_open:
		character.pause()
		return
	feedback_time = maxf(0, feedback_time - delta)
	impact_time = maxf(0, impact_time - delta)
	var direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if direction != Vector2.ZERO and working:
		cancel_work()
	if not working:
		move_player(direction, delta)
	focused = resources.nearest(player)
	if direction == Vector2.ZERO and not working and Input.is_physical_key_pressed(KEY_E):
		start_work(focused)
	if working:
		advance_work(delta)
	update_hud()
	queue_redraw()

func cancel_work() -> void:
	if not working:
		return
	working = false
	work_elapsed = 0.0
	character.speed_scale = 1.0
	character.play(StringName("idle_" + movement.facing()))

func start_work(target: Vector2i) -> bool:
	if skills_open or working or not resources.can_reach(target, player):
		return false
	work_target = target
	working = true
	work_elapsed = 0.0
	hit_applied = false
	work_duration = HARVEST_TIME / (1.0 + ranks[4] * 0.12)
	var aim: Vector2 = resources.bounds(target).get_center() - player
	movement.heading = aim.angle()
	movement.target_direction = Vector2.ZERO
	character.speed_scale = HARVEST_TIME / work_duration
	character.play(StringName("harvest_" + movement.facing()))
	character.frame = 0
	return true

func advance_work(delta: float) -> void:
	if not working:
		return
	work_elapsed += delta
	character.set_frame_and_progress(mini(3, floori(work_elapsed / work_duration * 4)), 0)
	if not hit_applied and work_elapsed >= work_duration * 0.5:
		hit_applied = true
		if resources.can_reach(work_target, player):
			var branch: int = resources.nodes[work_target]["branch"]
			impact_position = resources.bounds(work_target).get_center()
			impact_time = 0.18
			var result: Dictionary = resources.hit(work_target, player, ranks[branch])
			if result.get("depleted", false):
				feedback = "+%d %s" % [result["amount"], result["material"]]
				feedback_time = 2.0
				gain_experience(10)
				world_view.queue_redraw()
				focused = resources.NONE
	if work_elapsed >= work_duration:
		cancel_work()

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

func update_hud() -> void:
	hud.text = "EXPLORACIÓN · NIVEL %d · EXP %d/%d · PUNTOS %d\nMadera %d   Mineral %d   Chatarra %d\nWASD/flechas: moverse · E: recolectar · Tab: habilidades\nR: reiniciar prueba · F2: otro mapa" % [level, experience, level * 20, skill_points, resources.inventory["madera"], resources.inventory["mineral"], resources.inventory["chatarra"]]
	interaction.text = "Acércate a un árbol, roca o máquina y mantén E."
	if resources.nodes.has(focused):
		var node: Dictionary = resources.nodes[focused]
		interaction.text = "%s · Golpes restantes %d/%d · Mantén E" % [node["name"], node["remaining"], node["hits"]]
	if feedback_time > 0:
		interaction.text += "\n" + feedback
	minimap.player = player
	minimap.queue_redraw()
	skill_panel.visible = skills_open
	var effects := ["+1 madera por árbol", "+1 mineral por roca", "+22 velocidad", "+1 chatarra por máquina", "+12% ritmo de trabajo", "+20% experiencia"]
	for i in skill_buttons.size():
		skill_buttons[i].text = "%s %d/5 → %s" % [BRANCHES[i], ranks[i], effects[i]]
		skill_buttons[i].disabled = skill_points <= 0 or ranks[i] >= 5

func _draw() -> void:
	if resources.nodes.has(focused):
		var rect: Rect2 = resources.bounds(focused).grow(3)
		draw_rect(rect, Color(0.65, 0.58, 0.30, 0.55), false, 2)
	if impact_time > 0:
		for i in 5:
			var offset := Vector2.from_angle(i * TAU / 5) * (0.18 - impact_time) * 150
			draw_rect(Rect2(impact_position + offset, Vector2(3, 3)), Color("bcb39b"))
	draw_ellipse_shadow()

func draw_ellipse_shadow() -> void:
	draw_set_transform(player + Vector2(0, 17), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 19, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
