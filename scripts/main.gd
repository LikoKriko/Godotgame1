extends Node2D
signal menu_requested
signal settings_requested
var menu_open := false
var day_cycle = preload("res://scripts/day_cycle.gd").new()
var nutrition = preload("res://scripts/nutrition.gd").new()
var solar_lighting: Node
var gameplay_settings = preload("res://scripts/game_settings.gd").new()
var progression = preload("res://scripts/progression.gd").new()
var running := false
const RUN_MULTIPLIER := 1.6
var full_avatar: Sprite2D
var locomotion = preload("res://scripts/locomotion.gd").new()
var equipping := false
var equip_elapsed := 0.0
var last_tool_uid := -1

const TILE := 64
const WORLD_SEED := 73129
const HARVEST_TIME := 0.6
var bag = preload("res://scripts/inventory.gd").new()
var inventory_panel: Control
var work_item_uid := -1
var work_aim := Vector2.ZERO
var work_contact_aim := Vector2(INF,INF)
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
var world_map: Control
var player := Vector2.ZERO
var experience := 0
var level := 1
var skill_points := 0
var camera: Camera2D
var movement = preload("res://scripts/turn_motion.gd").new()
var quick_items: Array[int]:
	get:
		var ids: Array[int] = []
		for item in bag.quick_slots: ids.append(item.get("uid",-1))
		return ids
var styled_hud: Control

func _ready() -> void:
	if get_tree().get_nodes_in_group("pointer_coordinates").is_empty():
		add_child(preload("res://scripts/pointer_coordinates.gd").new())
	world.generate(WORLD_SEED)
	world_view = preload("res://scripts/world_view.gd").new()
	world_view.configure(world)
	add_child(world_view)
	camera = Camera2D.new()
	camera.zoom = Vector2(1.95, 1.95)
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
	interaction = Label.new()
	interaction.add_theme_font_size_override("font_size", 22)
	interaction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(interaction)
	inventory_panel = preload("res://scripts/inventory_panel.gd").new()
	canvas.add_child(inventory_panel)
	bag.reset()
	inventory_panel.configure(bag,self)
	inventory_panel.equipment_changed.connect(func(): cancel_work(); update_hud())
	world_map = preload("res://scripts/world_map.gd").new()
	canvas.add_child(world_map)
	world_map.configure(self)
	gameplay_settings.changed.connect(fit_hud)
	get_viewport().size_changed.connect(fit_hud)
	fit_hud()
	var cursor := preload("res://scripts/aim_cursor.gd").new()
	cursor.game = self
	canvas.add_child(cursor)
	inventory_panel.consume_requested.connect(consume_item)
	full_avatar = preload("res://scripts/full_frame_avatar.gd").new()
	add_child(full_avatar)
	solar_lighting = preload("res://scripts/solar_lighting.gd").new()
	add_child(solar_lighting)
	solar_lighting.configure(self)
	full_avatar.configure(self)
	restart()
	fit_hud()
	styled_hud = preload("res://scripts/styled_hud.gd").new()
	canvas.add_child(styled_hud)
	styled_hud.configure(self)
	canvas.move_child(cursor,canvas.get_child_count()-1)
	canvas.move_child(inventory_panel,canvas.get_child_count()-1)
	canvas.move_child(world_map,canvas.get_child_count()-1)

func consume_item(index: int, quick: bool = false) -> void:
	var result: Dictionary = nutrition.consume(bag,index,quick)
	inventory_panel.status.text = result["message"]
	inventory_panel.refresh()
	update_hud()

func fit_hud() -> void:
	var viewport_size := get_viewport_rect().size
	if camera != null:
		camera.zoom = Vector2.ONE*1.95*minf(viewport_size.x/1920.0,viewport_size.y/1080.0)
	var factor: float = gameplay_settings.hud_scale(gameplay_settings.values["hud_size"])
	interaction.scale = Vector2.ONE*factor
	interaction.position = Vector2(24,viewport_size.y-18-110*factor)

func restart() -> void:
	running = false
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
	world_map.hide()
	for arrow in get_tree().get_nodes_in_group("player_arrows"):
		arrow.queue_free()
	weapon_timer = 0.0
	player = Vector2.ZERO
	movement.reset()
	experience = 0
	level = 1
	skill_points = 0
	progression.reset()
	working = false
	equipping = false
	last_tool_uid = bag.held_item().get("uid",-1)
	work_elapsed = 0.0
	focused = resources.NONE
	feedback = ""
	feedback_time = 0.0
	impact_time = 0.0
	camera.position = player
	world_view.update_trees(player, 1.0)
	if full_avatar != null:
		full_avatar.reset()
	if solar_lighting != null:
		solar_lighting.update_light()
		update_hud()

func buy_improvement(id: StringName, ability: bool) -> bool:
	var spent: int = progression.purchase(id,ability,skill_points)
	if spent == 0: return false
	skill_points -= spent
	update_hud()
	return true

func activate_skill(id: StringName) -> bool:
	if menu_open or working or equipping: return false
	var success: bool = progression.activate(id)
	if success: update_hud()
	return success

func combat_damage(base: float) -> float:
	return progression.combat_damage(base)

func take_damage(amount: float) -> void:
	progression.take_damage(amount)
	if progression.health <= 0: cancel_work(); running = false

func gain_experience(amount: int) -> void:
	experience += amount
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
		menu_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_M:
		cancel_work()
		inventory_panel.hide()
		world_map.open_map()
		get_viewport().set_input_as_handled()
		return
	if event.keycode in [KEY_I,KEY_T,KEY_TAB]:
		cancel_work()
		world_map.hide()
		inventory_panel.open_section(1 if event.keycode == KEY_T else (2 if event.keycode == KEY_TAB else 0))
		update_hud()
		return
	if inventory_panel.visible or world_map.visible:
		return
	if event.keycode in [KEY_Z,KEY_X]:
		activate_skill(&"speed" if event.keycode == KEY_Z else &"power")
		return
	if event.keycode == KEY_SPACE:
		start_jump()
		return
	if event.keycode == KEY_CTRL:
		if running: start_slide()
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_6:
		use_quick_item(event.keycode-KEY_1)
	if event.keycode == KEY_0:
		cancel_work()
		if bag.held_id() != &"" and not bag.unequip(&"tool"):
			feedback = "La mochila está llena."
			feedback_time = 2
	if event.keycode == KEY_F2:
		world.seed_value += 1
		restart()
	if event.keycode == KEY_R:
		restart()
	update_hud()

func is_paused() -> bool:
	return menu_open or inventory_panel.visible or world_map.visible

func assign_quick_item(index: int, uid: int) -> bool:
	var source: Dictionary = bag.location(uid)
	return not source.is_empty() and bag.move_item(source.kind,source.index,&"quick",index)

func use_quick_item(index: int) -> bool:
	if index < 0 or index >= 6 or is_paused(): return false
	var item: Dictionary = bag.quick_slots[index]
	if item.is_empty(): return false
	var definition: Dictionary = bag.DEFINITIONS[item.id]
	if definition.has("kcal") or definition.has("water_ml"):
		consume_item(index,true)
		return true
	if definition.slot == &"tool":
		cancel_work()
		return bag.activate_quick(index)
	if definition.slot != &"":
		cancel_work()
		var equipped: bool = bag.move_item(&"quick",index,&"gear",definition.slot)
		inventory_panel.refresh()
		return equipped
	inventory_panel.open_section(0)
	inventory_panel.select_quick(index)
	return true

func start_jump() -> bool:
	if progression.health <= 0 or is_paused() or not locomotion.jump(nutrition.speed_multiplier()*progression.speed_multiplier()):
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
	if progression.health <= 0 or is_paused() or not running or not locomotion.slide(input_direction):
		return false
	cancel_work()
	equipping = false
	return true

func _process(delta: float) -> void:
	if is_paused():
		return
	progression.advance(delta)
	locomotion.advance(delta,Input.is_physical_key_pressed(KEY_CTRL) and not locomotion.sliding())
	if day_cycle.advance(delta) > 0:
		nutrition.new_day()
	nutrition.advance(delta,day_cycle.day_seconds)
	weapon_timer = maxf(0, weapon_timer - delta)
	feedback_time = maxf(0, feedback_time - delta)
	impact_time = maxf(0, impact_time - delta)
	var uid: int = bag.held_item().get("uid",-1)
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
	running = progression.health > 0 and direction != Vector2.ZERO and not working and not locomotion.airborne() and not locomotion.sliding() and locomotion.crouch < 0.01 and (gameplay_settings.values["auto_run"] or Input.is_physical_key_pressed(KEY_SHIFT))
	if not working and progression.health > 0:
		move_player(direction, delta)
	if equipping:
		equip_elapsed += delta
		var duration := 0.5 if bag.held_category() == &"pickaxe" else 0.42
		if equip_elapsed >= duration: equipping = false
	var aim := get_canvas_transform().affine_inverse()*preload("res://scripts/pointer_coordinates.gd").viewport_position(get_viewport())
	focused = resources.target_at(aim)
	var hovered := get_viewport().gui_get_hovered_control()
	var over_hud: bool = hovered != null and styled_hud != null and styled_hud.is_ancestor_of(hovered)
	var pressed := Input.is_physical_key_pressed(KEY_E) or (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not over_hud)
	if over_hud: focused = resources.NONE
	if direction == Vector2.ZERO and not working and not equipping and pressed:
		start_work(aim)
	if working:
		advance_work(delta, aim)
	world_view.update_trees(player, delta)
	full_avatar.update_pose(delta)
	solar_lighting.update_light()
	interaction.text = feedback if feedback_time > 0 else ""

func cancel_work() -> void:
	working = false
	work_elapsed = 0.0

func start_work(aim: Vector2) -> bool:
	if progression.health <= 0 or is_paused() or working or equipping or locomotion.airborne() or locomotion.sliding():
		return false
	var item: StringName = bag.held_category()
	if item != &"" and not bag.usable():
		feedback = "La herramienta está rota."
		feedback_time = 2
		return false
	if item in [&"sword", &"bow"] and weapon_timer > 0:
		return false
	work_item_uid = bag.held_item().get("uid", -1)
	work_aim = aim
	work_contact_aim = Vector2(INF,INF)
	work_target = resources.target_at(aim)
	working = true
	work_elapsed = 0.0
	hit_applied = false
	work_duration = preload("res://scripts/action_motion.gd").DURATION.get(item,HARVEST_TIME)
	movement.heading = (resources.visual_aim(aim,player) - player).angle()
	movement.target_direction = Vector2.ZERO
	return true

func advance_work(delta: float, aim: Vector2 = Vector2(INF, INF)) -> void:
	if not working:
		return
	if bag.held_item().get("uid", -1) != work_item_uid:
		cancel_work()
		return
	if is_finite(aim.x) and is_finite(aim.y):
		work_aim = aim
	work_elapsed += delta
	var target: Vector2 = work_contact_aim if hit_applied and work_contact_aim.is_finite() else resources.visual_aim(work_aim,player)
	movement.heading = (target-player).angle()
	var item: StringName = bag.held_category()
	var pose: Dictionary = preload("res://scripts/tool_contact.gd").contact(player,target,item)
	if not hit_applied and work_elapsed >= work_duration * 0.5:
		work_contact_aim = resources.visual_aim(work_aim,player)
		hit_applied = true
		# Resolve the contact pose even when a long frame crosses the impact moment.
		pose = preload("res://scripts/tool_contact.gd").contact(player,resources.visual_aim(work_aim,player),item)
		if item in [&"sword", &"bow"]:
			use_weapon(work_aim, true, pose)
		else:
			work_target = resources.target_at(work_aim)
			var result: Dictionary = resources.hit_at(work_aim, pose["tip"], pose["shoulder"], player, 0)
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
	if work_elapsed >= work_duration:
		cancel_work()

func use_weapon(target: Vector2, from_strike: bool = false, pose: Dictionary = {}) -> bool:
	if progression.health <= 0 or (working and not from_strike) or is_paused() or weapon_timer > 0 or not bag.usable():
		return false
	var id: StringName = bag.held_category()
	if id not in [&"sword", &"bow"]:
		return false
	if pose.is_empty():
		pose = preload("res://scripts/tool_contact.gd").contact(player, target, id)
	combat_aim = player.direction_to(target)
	if combat_aim == Vector2.ZERO:
		combat_aim = Vector2.from_angle(movement.heading)
	bag.consume_use()
	weapon_timer = 0.45 if id == &"sword" else 0.65
	if id == &"sword":
		for victim in get_tree().get_nodes_in_group("damageable"):
			if victim is Node2D and victim.has_method("take_damage"):
				if pose["reachable"] and victim.global_position.distance_to(target) <= 18 and clear_combat_path(victim.global_position):
					victim.take_damage(combat_damage(24.0))
	else:
		var arrow := preload("res://scripts/arrow.gd").new()
		arrow.world = world
		arrow.game = self
		arrow.position = full_avatar.shot_origin() if full_avatar != null else pose["tip"]
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
	var velocity: Vector2 = movement.step(direction, delta, 70.0*progression.speed_multiplier()*nutrition.speed_multiplier()*(RUN_MULTIPLIER if running else 1.0))
	if locomotion.sliding():
		movement.step(locomotion.slide_direction,delta,220)
	if locomotion.airborne() and locomotion.from_slide:
		locomotion.steer_air(direction,delta)
		movement.heading = locomotion.jump_heading
		movement.target_direction = Vector2.ZERO
		movement.speed_factor = 1.0
	velocity = locomotion.velocity(velocity,nutrition.speed_multiplier()*progression.speed_multiplier())
	var motion := velocity * delta
	player = world.move_actor(player, motion)
	camera.position = player
func update_hud() -> void:
	interaction.text = feedback if feedback_time > 0 else ""
	if styled_hud != null: styled_hud.refresh()
