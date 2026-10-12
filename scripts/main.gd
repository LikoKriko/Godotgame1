extends Node2D
signal menu_requested
var menu_open := false
var day_cycle = preload("res://scripts/day_cycle.gd").new()
var nutrition = preload("res://scripts/nutrition.gd").new()
var solar_lighting: Node
var survival_status: Control
var gait: Node2D
var locomotion = preload("res://scripts/locomotion.gd").new()
var original_head: Sprite2D
var head_mask: ShaderMaterial
var head_textures: Dictionary = {}
var equipping := false
var equip_elapsed := 0.0
var last_tool_uid := -1
var held_tool: Node2D

const TILE := 64
const WORLD_SEED := 73129
const BRANCHES := ["Silvicultura", "Minería", "Agilidad", "Reciclaje", "Ritmo", "Sabiduría"]
const HARVEST_TIME := 0.6
var bag = preload("res://scripts/inventory.gd").new()
var inventory_panel: Control
var work_item_uid := -1
var work_aim := Vector2.ZERO
var work_contact_aim := Vector2(INF,INF)
var arm_rig: Node2D
var weapon_timer := 0.0
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
	add_child(character)
	original_head = Sprite2D.new()
	original_head.centered = false
	original_head.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(original_head)
	original_head.hide()
	head_mask = ShaderMaterial.new()
	head_mask.shader = preload("res://shaders/body_without_head.gdshader")
	character.frame_changed.connect(sync_character)
	character.animation_changed.connect(sync_character)
	arm_rig = preload("res://scripts/arm_rig.gd").new()
	add_child(arm_rig)
	held_tool = preload("res://scripts/held_tool.gd").new()
	held_tool.z_index = 0
	held_tool.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(held_tool)
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
	var cursor := preload("res://scripts/aim_cursor.gd").new()
	cursor.game = self
	canvas.add_child(cursor)
	survival_status = preload("res://scripts/survival_status.gd").new()
	survival_status.configure(self)
	canvas.add_child(survival_status)
	inventory_panel.consume_requested.connect(consume_item)
	gait = preload("res://scripts/walk_presentation.gd").new()
	add_child(gait)
	gait.configure(self)
	# Near arms must draw after the torso; far arms retain z=-1.
	move_child(arm_rig,get_child_count()-1)
	solar_lighting = preload("res://scripts/solar_lighting.gd").new()
	add_child(solar_lighting)
	solar_lighting.configure(self)
	restart()
	fit_hud()

func consume_item(index: int) -> void:
	var result: Dictionary = nutrition.consume(bag,index)
	inventory_panel.status.text = result["message"]
	inventory_panel.refresh()
	survival_status.update_status()
	update_hud()

func fit_hud() -> void:
	var viewport_size := get_viewport_rect().size
	if survival_status != null:
		survival_status.position = Vector2(viewport_size.x-350,18)
	interaction.position = Vector2(24, viewport_size.y - 84)
	minimap.position = viewport_size - Vector2(264, 208)
	skill_panel.position = (viewport_size - skill_panel.size) / 2

func restart() -> void:
	locomotion.reset()
	world.generate(world.seed_value)
	world_view.refresh_ground()
	bag.reset()
	for provision in [[&"apple",4],[&"berries",10],[&"ration",8],[&"water",8]]:
		bag.add(provision[0],provision[1])
	day_cycle.reset()
	nutrition.reset()
	resources.configure(world, bag, world_view.hit_meshes)
	inventory_panel.refresh()
	inventory_panel.hide()
	for arrow in get_tree().get_nodes_in_group("player_arrows"):
		arrow.queue_free()
	weapon_timer = 0.0
	character.rotation = 0
	player = Vector2.ZERO
	movement.reset()
	character.play(&"idle_down")
	experience = 0
	level = 1
	skill_points = 0
	ranks = [0, 0, 0, 0, 0, 0]
	working = false
	equipping = false
	last_tool_uid = bag.equipment[&"hands"].get("uid",-1)
	arm_rig.hide()
	if gait != null:
		gait.cancel()
	work_elapsed = 0.0
	focused = resources.NONE
	feedback = ""
	feedback_time = 0.0
	impact_time = 0.0
	skills_open = false
	camera.position = player
	sync_character()
	world_view.update_trees(player, 1.0)
	if solar_lighting != null:
		solar_lighting.update_light()
		survival_status.update_status()
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
	if menu_open:
		return
	if not event.is_pressed() or event.is_echo():
		return
	if event.keycode == KEY_ESCAPE:
		if skills_open:
			skills_open = false
			update_hud()
		else:
			menu_requested.emit()
		get_viewport().set_input_as_handled()
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
	if event.keycode == KEY_SPACE:
		start_jump()
		return
	if event.keycode == KEY_SHIFT:
		start_slide()
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

func is_paused() -> bool:
	return menu_open or skills_open or inventory_panel.visible

func start_jump() -> bool:
	if is_paused() or not locomotion.jump():
		return false
	cancel_work()
	equipping = false
	return true

func start_slide() -> bool:
	var input_direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if input_direction == Vector2.ZERO:
		input_direction = movement.target_direction
	if is_paused() or not locomotion.slide(input_direction):
		return false
	cancel_work()
	equipping = false
	return true

func _process(delta: float) -> void:
	if is_paused():
		character.pause()
		return
	locomotion.advance(delta,Input.is_physical_key_pressed(KEY_CTRL))
	if day_cycle.advance(delta) > 0:
		nutrition.new_day()
	nutrition.advance(delta,day_cycle.day_seconds)
	weapon_timer = maxf(0, weapon_timer - delta)
	feedback_time = maxf(0, feedback_time - delta)
	impact_time = maxf(0, impact_time - delta)
	var uid: int = bag.equipment[&"hands"].get("uid",-1)
	if uid != last_tool_uid:
		cancel_work()
		last_tool_uid = uid
		equipping = bag.held_id() != &""
		equip_elapsed = 0
	var direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if direction != Vector2.ZERO and working:
		cancel_work()
	if direction != Vector2.ZERO and equipping:
		equipping = false
		arm_rig.hide()
	if not working and not equipping:
		move_player(direction, delta)
	if equipping:
		equip_elapsed += delta
		var duration := 0.5 if bag.held_id() == &"pickaxe" else 0.42
		var facing: StringName = movement.facing()
		character.play(StringName("work_"+facing))
		var idle: AtlasTexture = character.sprite_frames.get_frame_texture(StringName("idle_"+facing),0)
		arm_rig.equip(player,facing,bag.held_id(),clampf(equip_elapsed/duration,0,1),held_tool.offset(idle))
		if equip_elapsed >= duration:
			equipping = false
			arm_rig.hide()
			character.play(StringName("idle_"+facing))
	var aim := get_global_mouse_position()
	focused = resources.target_at(aim)
	var pressed := Input.is_physical_key_pressed(KEY_E) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if direction == Vector2.ZERO and not working and not equipping and pressed:
		start_work(aim)
	if working:
		advance_work(delta, aim)
	world_view.update_trees(player, delta)
	held_tool.update_pose(self)
	gait.update_pose(delta)
	if not gait.active() and not working and not equipping:
		if direction == Vector2.ZERO and bag.held_id() in [&"axe",&"pickaxe"]:
			character.play(StringName("work_"+movement.facing()))
			arm_rig.ready_pose(player,movement.facing(),bag.held_id())
			held_tool.hide()
			gait.update_work_pose()
		else:
			arm_rig.gait(player,movement.facing(),bag.held_id(),0,0)
			held_tool.hide()
			gait.update_work_pose()
	gait.apply_locomotion()
	solar_lighting.update_light()
	survival_status.update_status()
	update_hud()
	queue_redraw()

func cancel_work() -> void:
	if not working:
		return
	working = false
	arm_rig.hide()
	work_elapsed = 0.0
	character.speed_scale = 1.0
	character.rotation = 0
	arm_rig.rotation = 0
	character.show()
	character.play(StringName("idle_" + movement.facing()))
	gait.cancel()

func start_work(aim: Vector2) -> bool:
	if is_paused() or working or equipping or locomotion.airborne() or locomotion.sliding():
		return false
	var item: StringName = bag.held_id()
	if item != &"" and not bag.usable():
		feedback = "La herramienta está rota."
		feedback_time = 2
		return false
	if item in [&"sword", &"bow"] and weapon_timer > 0:
		return false
	work_item_uid = bag.equipment[&"hands"].get("uid", -1)
	work_aim = aim
	work_contact_aim = Vector2(INF,INF)
	work_target = resources.target_at(aim)
	working = true
	work_elapsed = 0.0
	hit_applied = false
	work_duration = preload("res://scripts/action_motion.gd").DURATION.get(item,HARVEST_TIME) / (1.0 + ranks[4] * 0.12)
	movement.heading = (resources.visual_aim(aim,player) - player).angle()
	movement.target_direction = Vector2.ZERO
	character.speed_scale = 1.0
	character.play(StringName("work_" + movement.facing()))
	character.frame = 0
	animate_work_rig(0)
	gait.update_pose(0)
	return true

func animate_work_rig(phase: float) -> Dictionary:
	var item: StringName = bag.held_id()
	var transform := preload("res://scripts/action_motion.gd").torso_transform(player,movement.facing(),phase,item,arm_rig.impact_material)
	var target: Vector2 = work_contact_aim if hit_applied and work_contact_aim.is_finite() else resources.visual_aim(work_aim,player)
	var aim: Vector2 = transform.affine_inverse()*target
	var pose: Dictionary = arm_rig.animate(player,aim,item,phase,movement.facing())
	arm_rig.position = transform*player
	arm_rig.rotation = transform.get_rotation()
	return pose

func advance_work(delta: float, aim: Vector2 = Vector2(INF, INF)) -> void:
	if not working:
		return
	if bag.equipment[&"hands"].get("uid", -1) != work_item_uid:
		cancel_work()
		return
	if is_finite(aim.x) and is_finite(aim.y):
		work_aim = aim
	work_elapsed += delta
	var target: Vector2 = work_contact_aim if hit_applied and work_contact_aim.is_finite() else resources.visual_aim(work_aim,player)
	movement.heading = (target-player).angle()
	character.play(StringName("work_" + movement.facing()))
	var item: StringName = bag.held_id()
	var pose: Dictionary = animate_work_rig(clampf(work_elapsed / work_duration, 0, 1))
	if not hit_applied and work_elapsed >= work_duration * 0.5:
		work_contact_aim = resources.visual_aim(work_aim,player)
		hit_applied = true
		# Resolve the contact pose even when a long frame crosses the impact moment.
		pose = preload("res://scripts/arm_rig.gd").contact(player,resources.visual_aim(work_aim,player),item)
		if item in [&"sword", &"bow"]:
			use_weapon(work_aim, true, pose)
		else:
			work_target = resources.target_at(work_aim)
			var bonus := 0
			if resources.nodes.has(work_target):
				bonus = ranks[resources.nodes[work_target]["branch"]]
			var result: Dictionary = resources.hit_at(work_aim, pose["tip"], pose["shoulder"], player, bonus)
			if result.get("miss", false):
				feedback = "Golpe al aire." if not result.get("blocked", false) else "Hay un obstáculo delante."
				feedback_time = 1
			elif result.has("cell"):
				var material := "madera"
				if resources.nodes.has(result["cell"]):
					material = resources.nodes[result["cell"]]["material"]
				else:
					material = result.get("material", "madera")
				impact_position = result.get("impact",work_aim)
				impact_time = 0.18
				arm_rig.impact_material = StringName(material)
				animate_work_rig(clampf(work_elapsed/work_duration,0,1))
				world_view.register_impact(result["cell"], impact_position, pose["direction"], material, 0.3 if result.has("reason") else 1.0)
				if result.has("reason"):
					feedback = "La mochila está llena." if result["reason"] == "mochila_llena" else "Usa manos para fibra/chatarra, hacha para madera y pico para piedras (las pequeñas se recogen a mano)."
					feedback_time = 2
				elif result.has("depleted") and item != &"":
					bag.consume_use()
				if result.get("depleted", false):
					feedback = "+%d %s" % [result["amount"], result["material"]]
					if result["material"] == "fibra":
						feedback += " · +2 palos"
					feedback_time = 2
					gain_experience(10)
					focused = resources.NONE
					world_view.queue_redraw()
	gait.update_pose(0)
	if work_elapsed >= work_duration:
		cancel_work()

func use_weapon(target: Vector2, from_strike: bool = false, pose: Dictionary = {}) -> bool:
	if (working and not from_strike) or is_paused() or weapon_timer > 0 or not bag.usable():
		return false
	var id: StringName = bag.held_id()
	if id not in [&"sword", &"bow"]:
		return false
	if pose.is_empty():
		pose = preload("res://scripts/arm_rig.gd").contact(player, target, id)
	combat_aim = player.direction_to(target)
	if combat_aim == Vector2.ZERO:
		combat_aim = Vector2.from_angle(movement.heading)
	bag.consume_use()
	weapon_timer = 0.45 if id == &"sword" else 0.65
	if id == &"sword":
		for victim in get_tree().get_nodes_in_group("damageable"):
			if victim is Node2D and victim.has_method("take_damage"):
				if pose["reachable"] and victim.global_position.distance_to(target) <= 18 and clear_combat_path(victim.global_position):
					victim.take_damage(24.0)
	else:
		var arrow := preload("res://scripts/arrow.gd").new()
		arrow.world = world
		arrow.game = self
		arrow.position = pose["tip"]
		arrow.velocity = arrow.position.direction_to(target) * 650
		if arrow.velocity == Vector2.ZERO:
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
	var velocity: Vector2 = movement.step(direction, delta, (220.0 + ranks[2] * 22.0)*nutrition.speed_multiplier())
	if locomotion.sliding():
		movement.step(locomotion.slide_direction,delta,220)
	velocity = locomotion.velocity(velocity,nutrition.speed_multiplier())
	var motion := velocity * delta
	player = world.move_actor(player, motion)
	camera.position = player
	var moving := player.distance_squared_to(previous) > 0.00001
	var turn: StringName = movement.turn_animation()
	if moving and movement.is_turning() and character.sprite_frames.has_animation(turn):
		character.speed_scale = 1.0
		character.play(turn)
		var count := character.sprite_frames.get_frame_count(turn)
		character.set_frame_and_progress(roundi(movement.turn_progress() * (count - 1)), 0)
		character.pause()
		sync_character()
		return
	var animation := StringName(("walk_" if moving else "idle_") + movement.facing())
	character.speed_scale = movement.speed_factor*nutrition.speed_multiplier() if moving else 1.0
	character.play(animation)
	sync_character()

func sync_character() -> void:
	if character == null or not character.sprite_frames.has_animation(character.animation):
		return
	var frames := character.sprite_frames
	var texture: AtlasTexture = frames.get_frame_texture(character.animation, mini(character.frame, frames.get_frame_count(character.animation) - 1))
	var frame_data = preload("res://scripts/survivor_frames.gd")
	var factor: float = frame_data.CHARACTER_HEIGHT / texture.region.size.y
	character.scale = Vector2.ONE * factor
	character.position = player + Vector2(0, 17 - (frame_data.BASELINE - frame_data.CANVAS.y / 2) * factor)
	var work_view := str(character.animation).begins_with("work_")
	character.material = head_mask if work_view else null
	original_head.visible = work_view
	if work_view:
		head_mask.set_shader_parameter("head_bottom",player.y-22)
		var facing: StringName = StringName(str(character.animation).trim_prefix("work_"))
		var index: int = frame_data.DIRECTIONS.find(facing)
		var data: Array = preload("res://assets/characters/survivor_regions.gd").IDLE[index]
		var head_factor: float = 64.0/data[3]
		if not head_textures.has(facing):
			var atlas := AtlasTexture.new()
			atlas.atlas = frame_data.IDLE_SHEET
			atlas.region = Rect2(data[0],data[1],data[2],ceili(25/head_factor))
			head_textures[facing] = atlas
		original_head.texture = head_textures[facing]
		original_head.scale = Vector2.ONE*head_factor
		original_head.position = player+Vector2((data[0]-data[4])*head_factor,-47)

func update_hud() -> void:
	hud.text = "DAY ZERO · NIVEL %d · EXP %d/%d · PUNTOS %d\nMadera %d · Piedras %d · Palos %d · Fibra %d · Cuerda %d m\nWASD: moverse · Clic/E: golpear · I: inventario y fabricar\nEsc: menú · Tab: habilidades · R: reiniciar · F2: otro mapa" % [level, experience, level * 20, skill_points, bag.count(&"madera"), bag.count(&"piedra"), bag.count(&"palo"), bag.count(&"fibra"), bag.count(&"cuerda")]
	var held: Dictionary = bag.equipment[&"hands"]
	hud.text += "\nManos: %s · 1 Espada / 2 Arco / 3 Pico / 4 Hacha / 0 Vaciar" % ("Libres" if held.is_empty() else "%s [%d usos]" % [bag.DEFINITIONS[held["id"]]["name"], held["uses"]])
	hud_backdrop.size = hud.get_combined_minimum_size() + Vector2(24, 18)
	interaction.text = "Clic/E: golpear · Ctrl: agacharse · Espacio: saltar · Shift al moverse: deslizarse"
	if resources.nodes.has(focused):
		var node: Dictionary = resources.nodes[focused]
		interaction.text = "%s · Golpes restantes %d/%d · Clic / E" % [node["name"], node["remaining"], node["hits"]]
	if feedback_time > 0:
		interaction.text += "\n" + feedback
	minimap.player = player
	minimap.queue_redraw()
	skill_panel.visible = skills_open
	var effects := ["+1 madera por árbol", "+1 piedra por roca", "+22 velocidad", "+1 chatarra por máquina", "+12% ritmo de trabajo", "+20% experiencia"]
	for i in skill_buttons.size():
		skill_buttons[i].text = "%s %d/5 → %s" % [BRANCHES[i], ranks[i], effects[i]]
		skill_buttons[i].disabled = skill_points <= 0 or ranks[i] >= 5
