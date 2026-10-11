extends Node2D

const TILE := 64
const WORLD_SEED := 73129
const BRANCHES := ["Silvicultura", "Minería", "Agilidad", "Reciclaje", "Ritmo", "Sabiduría"]
const HARVEST_TIME := 0.6
var bag = preload("res://scripts/inventory.gd").new()
var inventory_panel: Control
var work_item_uid := -1
var weapon_timer := 0.0
var sword_flash := 0.0
var combat_aim := Vector2.RIGHT
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
var hud_backdrop: Panel
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
	camera.zoom = Vector2(1.5, 1.5)
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
	hud_backdrop = Panel.new()
	hud_backdrop.position = Vector2(6, 4)
	hud_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hud_style := StyleBoxFlat.new()
	hud_style.bg_color = Color(0.09, 0.115, 0.09, 0.90)
	hud_style.set_corner_radius_all(4)
	hud_backdrop.add_theme_stylebox_override("panel", hud_style)
	canvas.add_child(hud_backdrop)
	hud = Label.new()
	hud.position = Vector2(18, 12)
	hud.add_theme_font_size_override("font_size", 24)
	canvas.add_child(hud)
	interaction = Label.new()
	interaction.add_theme_font_size_override("font_size", 22)
	canvas.add_child(interaction)
	minimap = preload("res://scripts/world_minimap.gd").new()
	minimap.world = world
	minimap.scale = Vector2(1.25, 1.25)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(minimap)
	inventory_panel = preload("res://scripts/inventory_panel.gd").new()
	canvas.add_child(inventory_panel)
	bag.reset()
	inventory_panel.configure(bag)
	inventory_panel.equipment_changed.connect(func(): cancel_work(); update_hud())
	skill_panel = PanelContainer.new()
	var skill_style := StyleBoxFlat.new()
	skill_style.bg_color = Color("252b23")
	skill_style.content_margin_left = 16
	skill_style.content_margin_right = 16
	skill_style.content_margin_top = 12
	skill_style.content_margin_bottom = 12
	skill_panel.add_theme_stylebox_override("panel", skill_style)
	skill_panel.size = Vector2(700, 440)
	canvas.add_child(skill_panel)
	var box := VBoxContainer.new()
	skill_panel.add_child(box)
	var title := Label.new()
	title.text = "HABILIDADES · 6 ramas × 5 rangos\nCada rango requiere el anterior y un punto."
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	for i in BRANCHES.size():
		var button := Button.new()
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(upgrade.bind(i))
		box.add_child(button)
		skill_buttons.append(button)
	var hint := Label.new()
	hint.text = "Pulsa Tab para volver al mundo."
	hint.add_theme_font_size_override("font_size", 20)
	box.add_child(hint)
	get_viewport().size_changed.connect(fit_hud)
	skill_panel.resized.connect(fit_hud)
	fit_hud()
	restart()

func fit_hud() -> void:
	var viewport_size := get_viewport_rect().size
	interaction.position = Vector2(24, viewport_size.y - 84)
	minimap.position = viewport_size - Vector2(264, 208)
	skill_panel.position = (viewport_size - skill_panel.size) / 2

func restart() -> void:
	world.generate(world.seed_value)
	world_view.refresh_ground()
	bag.reset()
	resources.configure(world, bag)
	inventory_panel.refresh()
	inventory_panel.hide()
	for arrow in get_tree().get_nodes_in_group("player_arrows"):
		arrow.queue_free()
	weapon_timer = 0.0
	sword_flash = 0.0
	character.rotation = 0
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
	if event.keycode == KEY_I:
		cancel_work()
		skills_open = false
		inventory_panel.refresh()
		inventory_panel.show()
		update_hud()
		return
	if inventory_panel.visible:
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_4:
		cancel_work()
		bag.select_tool([&"sword", &"bow", &"pickaxe", &"axe"][event.keycode - KEY_1])
	if event.keycode == KEY_0:
		cancel_work()
		if bag.held_id() != &"" and not bag.unequip(&"hands"):
			feedback = "La mochila está llena."
			feedback_time = 2
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
	if skills_open or inventory_panel.visible:
		character.pause()
		return
	weapon_timer = maxf(0, weapon_timer - delta)
	sword_flash = maxf(0, sword_flash - delta)
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
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_SPACE):
		use_weapon(get_global_mouse_position())
	update_hud()
	queue_redraw()

func cancel_work() -> void:
	if not working:
		return
	working = false
	work_elapsed = 0.0
	character.speed_scale = 1.0
	character.rotation = 0
	character.play(StringName("idle_" + movement.facing()))

func start_work(target: Vector2i) -> bool:
	if skills_open or inventory_panel.visible or working or not resources.can_reach(target, player):
		return false
	if not bag.can_harvest(resources.nodes[target]["material"]):
		feedback = "Usa hacha para árboles, pico para rocas y manos libres para chatarra."
		feedback_time = 2.0
		return false
	work_item_uid = bag.equipment[&"hands"].get("uid", -1)
	work_target = target
	working = true
	work_elapsed = 0.0
	hit_applied = false
	work_duration = HARVEST_TIME / (1.0 + ranks[4] * 0.12)
	var aim: Vector2 = resources.bounds(target).get_center() - player
	movement.heading = aim.angle()
	movement.target_direction = Vector2.ZERO
	character.speed_scale = HARVEST_TIME / work_duration
	var action := "mine_" if bag.held_id() == &"pickaxe" else ("harvest_" if bag.held_id() == &"axe" else "idle_")
	character.play(StringName(action + movement.facing()))
	character.frame = 0
	return true

func advance_work(delta: float) -> void:
	if not working:
		return
	work_elapsed += delta
	if bag.held_id() == &"":
		character.rotation = sin(work_elapsed / work_duration * PI) * 0.06
	else:
		character.set_frame_and_progress(mini(3, floori(work_elapsed / work_duration * 4)), 0)
	if not hit_applied and work_elapsed >= work_duration * 0.5:
		hit_applied = true
		if resources.can_reach(work_target, player) and bag.equipment[&"hands"].get("uid", -1) == work_item_uid:
			var branch: int = resources.nodes[work_target]["branch"]
			impact_position = resources.bounds(work_target).get_center()
			impact_time = 0.18
			var result: Dictionary = resources.hit(work_target, player, ranks[branch])
			if result.has("reason"):
				feedback = "La mochila está llena." if result["reason"] == "mochila_llena" else "Herramienta incorrecta o rota."
				feedback_time = 2
			elif not result.is_empty() and bag.held_id() != &"":
				bag.consume_use()
			if result.get("depleted", false):
				feedback = "+%d %s" % [result["amount"], result["material"]]
				feedback_time = 2.0
				gain_experience(10)
				world_view.queue_redraw()
				focused = resources.NONE
	if work_elapsed >= work_duration:
		cancel_work()

func use_weapon(target: Vector2) -> bool:
	if working or skills_open or inventory_panel.visible or weapon_timer > 0 or not bag.usable():
		return false
	var id: StringName = bag.held_id()
	if id not in [&"sword", &"bow"]:
		return false
	combat_aim = player.direction_to(target)
	if combat_aim == Vector2.ZERO:
		combat_aim = Vector2.from_angle(movement.heading)
	bag.consume_use()
	weapon_timer = 0.45 if id == &"sword" else 0.65
	if id == &"sword":
		sword_flash = 0.18
		for victim in get_tree().get_nodes_in_group("damageable"):
			if victim is Node2D and victim.has_method("take_damage"):
				var offset: Vector2 = victim.global_position - player
				if offset.length() <= 85 and offset.normalized().dot(combat_aim) >= 0.3 and clear_combat_path(victim.global_position):
					victim.take_damage(24.0)
	else:
		var arrow := preload("res://scripts/arrow.gd").new()
		arrow.world = world
		arrow.game = self
		arrow.position = player + combat_aim * 20
		arrow.velocity = combat_aim * 650
		add_child(arrow)
		arrow.add_to_group("player_arrows")
	update_hud()
	return true

func clear_combat_path(target: Vector2) -> bool:
	var distance := player.distance_to(target)
	for i in range(1, ceili(distance / 6.0)):
		if not world.walkable(player.move_toward(target, i * 6), 1):
			return false
	return true

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
	hud.text = "EXPLORACIÓN · NIVEL %d · EXP %d/%d · PUNTOS %d\nMadera %d   Mineral %d   Chatarra %d\nWASD: moverse · E: recolectar · I: inventario · Tab: habilidades\nR: reiniciar prueba · F2: otro mapa" % [level, experience, level * 20, skill_points, resources.inventory["madera"], resources.inventory["mineral"], resources.inventory["chatarra"]]
	var held: Dictionary = bag.equipment[&"hands"]
	hud.text += "\nManos: %s · 1 Espada / 2 Arco / 3 Pico / 4 Hacha / 0 Vaciar" % ("Libres" if held.is_empty() else "%s [%d usos]" % [bag.DEFINITIONS[held["id"]]["name"], held["uses"]])
	hud_backdrop.size = hud.get_combined_minimum_size() + Vector2(24, 18)
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
	if sword_flash > 0:
		draw_arc(player, 72, combat_aim.angle() - 0.7, combat_aim.angle() + 0.7, 12, Color("ddd3ad"), 3)
	var id: StringName = bag.held_id()
	if id != &"" and not working:
		var icon: Texture2D = preload("res://scripts/item_icons.gd").get_icon(id)
		if icon != null:
			draw_texture_rect(icon, Rect2(player + Vector2(11, -10), Vector2(23, 23)), false)
	draw_ellipse_shadow()

func draw_ellipse_shadow() -> void:
	draw_set_transform(player + Vector2(0, 17), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 19, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
