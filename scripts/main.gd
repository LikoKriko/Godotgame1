extends Node2D
signal menu_requested
signal main_menu_requested
signal settings_requested
var menu_open := false
var world_prepared := false
var day_cycle = preload("res://scripts/day_cycle.gd").new()
var nutrition = preload("res://scripts/nutrition.gd").new()
var solar_lighting: Node
var gameplay_settings = preload("res://scripts/game_settings.gd").new()
var progression = preload("res://scripts/progression.gd").new()
var life: Node
var loot: Node2D
var running := false
const RUN_MULTIPLIER := 1.6
var full_avatar: Sprite2D
var locomotion = preload("res://scripts/locomotion.gd").new()
var equipping := false
var equip_elapsed := 0.0
var last_tool_uid := -1

const TILE := 64
const WORLD_SEED := 73129
const WALK_SPEED := 70.0
const HARVEST_TIME := 0.6
var bag = preload("res://scripts/inventory.gd").new()
var inventory_panel: Control
var work_item_uid := -1
var bow_draw_uid := -1
var work_aim := Vector2.ZERO
var work_heading := 0.0
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
var hut: Node2D
var workbenches: Node2D
var world_map: Control
var item_catalog: Control
var previously_airborne := false
var ground_height := 0.0
var rock_support := Vector2i(99999,99999)
var player := Vector2.ZERO
var experience := 0
var level := 1
var skill_points := 0
var camera: Camera2D
var movement = preload("res://scripts/turn_motion.gd").new()
var interaction_motion = preload("res://scripts/interaction_motion.gd").new()
var pickup_cell := Vector2i(99999,99999)
var pickup_aim := Vector2.ZERO
var pickup_committed := false
var enemies = preload("res://scripts/enemy_manager.gd").new()
var combat_effects: Node2D
var quick_items: Array[int]:
	get:
		var ids: Array[int] = []
		for item in bag.quick_slots: ids.append(item.get("uid",-1))
		return ids
var styled_hud: Control

func _ready() -> void:
	if not world_prepared: world.generate(WORLD_SEED)
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
	preload("res://scripts/ui_style.gd").set_font_size(interaction,22)
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
	item_catalog = preload("res://scripts/item_catalog.gd").new()
	canvas.add_child(item_catalog); item_catalog.configure(self)
	gameplay_settings.changed.connect(fit_hud)
	get_viewport().size_changed.connect(fit_hud)
	fit_hud()
	inventory_panel.consume_requested.connect(consume_item)
	full_avatar = preload("res://scripts/full_frame_avatar.gd").new()
	add_child(full_avatar)
	solar_lighting = preload("res://scripts/solar_lighting.gd").new()
	add_child(solar_lighting)
	solar_lighting.configure(self)
	full_avatar.configure(self)
	combat_effects = preload("res://scripts/combat_effects.gd").new()
	combat_effects.game = self; combat_effects.z_index = 4090; add_child(combat_effects)
	enemies.configure(self)
	hut = preload("res://scripts/hut.gd").new(); add_child(hut); hut.configure(self)
	workbenches = preload("res://scripts/workbenches.gd").new(); add_child(workbenches); workbenches.configure(self,canvas)
	restart(false)
	fit_hud()
	styled_hud = preload("res://scripts/styled_hud.gd").new()
	canvas.add_child(styled_hud)
	styled_hud.configure(self)
	canvas.move_child(inventory_panel,canvas.get_child_count()-1)
	canvas.move_child(world_map,canvas.get_child_count()-1)
	canvas.move_child(item_catalog,canvas.get_child_count()-1)
	canvas.move_child(workbenches.window,canvas.get_child_count()-1)
	loot = preload("res://scripts/corpse_loot.gd").new(); add_child(loot); loot.configure(self,canvas)
	life = preload("res://scripts/life_cycle.gd").new(); add_child(life); life.configure(self,canvas)

func consume_item(index: int, quick: bool = false) -> void:
	var selected_storage: Array = bag.quick_slots if quick else bag.slots
	if index >= 0 and index < selected_storage.size() and not selected_storage[index].is_empty() and bag.DEFINITIONS[selected_storage[index].id].get("kcal",0) > 0:
		if life != null and life.eat(index,quick): feedback = "Comiendo..."; feedback_time = 1.2
		return
	var result: Dictionary = nutrition.consume(bag,index,quick)
	inventory_panel.status.text = result["message"]
	inventory_panel.refresh()
	if result.ok: full_avatar.update_pose(0)
	feedback = result.message; feedback_time = 2
	update_hud()

func fit_hud() -> void:
	var viewport_size := get_viewport_rect().size
	if camera != null:
		camera.zoom = Vector2.ONE*1.95*minf(viewport_size.x/1920.0,viewport_size.y/1080.0)
	update_camera_position()
	var factor: float = preload("res://scripts/game_settings.gd").hud_scale(gameplay_settings.values["hud_size"])
	interaction.scale = Vector2.ONE*factor
	interaction.position = Vector2(24,viewport_size.y-18-110*factor)
	if styled_hud != null: styled_hud.fit()

func restart(regenerate: bool = true) -> void:
	if life != null: life.reset()
	if loot != null: loot.reset()
	if workbenches != null: workbenches.reset()
	running = false
	locomotion.reset()
	interaction_motion.reset()
	pickup_cell = resources.NONE; pickup_committed = false
	if regenerate: world.generate(world.seed_value)
	world_view.refresh_ground()
	bag.reset()
	for provision in [[&"apple",4],[&"berries",10],[&"ration",8]]:
		bag.add(provision[0],provision[1])
	day_cycle.reset()
	nutrition.reset()
	resources.configure(world, bag, world_view.hit_meshes)
	inventory_panel.refresh()
	inventory_panel.hide()
	world_map.hide()
	if item_catalog != null: item_catalog.hide()
	for arrow in get_tree().get_nodes_in_group("player_arrows"):
		arrow.queue_free()
	weapon_timer = 0.0
	bow_draw_uid = -1
	player = Vector2.ZERO
	ground_height = 0; rock_support = world.NO_SUPPORT; previously_airborne = false
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
	update_camera_position()
	world_view.update_trees(player, 1.0)
	if full_avatar != null:
		full_avatar.reset()
	if solar_lighting != null:
		solar_lighting.update_light()
		update_hud()
	enemies.reset()
	if hut != null: hut.reset(); hut.apply_visibility()
	if combat_effects != null: combat_effects.flashes.clear(); combat_effects.trail.clear(); combat_effects.queue_redraw(); combat_effects.trail_layer.queue_redraw()

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
	if progression.health <= 0 and life != null: life.die()

func gain_experience(amount: int, source: StringName = &"") -> bool:
	if amount <= 0 or not preload("res://scripts/experience_sources.gd").accepts(source): return false
	experience += amount
	while experience >= level * 20:
		experience -= level * 20
		level += 1
		skill_points += 1
	update_hud()
	return true

func biome_at(cell: Vector2i) -> int:
	return world.biome_at(cell)

func walkable(point: Vector2) -> bool:
	return world.walkable(point)

func _unhandled_key_input(event: InputEvent) -> void:
	if life != null and life.dying(): return
	if loot != null and loot.window.visible:
		if event.is_pressed() and event.keycode == KEY_ESCAPE: loot.close_window(); get_viewport().set_input_as_handled()
		return
	if menu_open:
		return
	if not event.is_pressed() or event.is_echo():
		return
	if event.keycode == KEY_ESCAPE:
		if workbenches.placing():
			workbenches.cancel_placement(); get_viewport().set_input_as_handled(); return
		menu_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_K:
		cancel_work(); inventory_panel.hide(); world_map.hide()
		workbenches.window.hide(); item_catalog.open_catalog(); get_viewport().set_input_as_handled(); return
	if event.keycode == KEY_M:
		cancel_work()
		item_catalog.hide()
		inventory_panel.hide()
		workbenches.window.hide(); world_map.open_map()
		get_viewport().set_input_as_handled()
		return
	if event.keycode in [KEY_I,KEY_T,KEY_TAB]:
		cancel_work()
		item_catalog.hide()
		world_map.hide()
		workbenches.window.hide()
		inventory_panel.open_section(1 if event.keycode == KEY_T else (2 if event.keycode == KEY_TAB else 0))
		update_hud()
		return
	if workbenches.window.visible or inventory_panel.visible or world_map.visible or item_catalog.visible:
		return
	if event.keycode == KEY_E:
		interact_at(cursor_world_position()); get_viewport().set_input_as_handled(); return
	if event.keycode == KEY_F:
		if not enemies.activate_parry(): feedback = "Parry: %.1f s" % enemies.parry.cooldown_remaining(); feedback_time = 1
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

func request_settings() -> void:
	settings_requested.emit()

func is_paused() -> bool:
	return (life != null and life.dying()) or (loot != null and loot.window.visible) or menu_open or (workbenches != null and workbenches.window.visible) or inventory_panel.visible or world_map.visible or (item_catalog != null and item_catalog.visible)

func cursor_world_position() -> Vector2:
	return get_canvas_transform().affine_inverse()*preload("res://scripts/pointer_coordinates.gd").viewport_position(get_viewport())

func _unhandled_input(event: InputEvent) -> void:
	if is_paused() or not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT: return
	if bag.held_id() == &"basic_workbench":
		workbenches.begin_placement(cursor_world_position()); get_viewport().set_input_as_handled(); return
	if bag.held_id() == &"botella":
		var location: Dictionary = bag.location(bag.active_quick_uid)
		if location.get("kind") == &"quick": consume_item(location.index,true)
		get_viewport().set_input_as_handled()

func interact_at(aim: Vector2) -> bool:
	if is_paused() or progression.health <= 0 or locomotion.airborne() or locomotion.sliding() or interaction_motion.picking_up(): return false
	if loot != null and loot.interact(aim): return true
	if life != null and life.eating(): return false
	if workbenches != null and workbenches.interact(aim): return true
	if hut != null and hut.interact(): return true
	if hut != null and hut.inside:
		feedback = "Acércate a la puerta para salir con E."; feedback_time = 2; return false
	var result: Dictionary = {}
	var water: Rect2 = world_view.water_at(aim)
	if bag.held_id() == &"botella" and water.has_area():
		var nearest: Vector2 = player.clamp(water.position,water.end)
		var reachable: bool = player.distance_to(nearest) <= resources.REACH
		for step in range(1,maxi(1,ceili(player.distance_to(nearest)/5))):
			if not world.walkable(player.move_toward(nearest,step*5),1): reachable = false
		result = preload("res://scripts/nutrition.gd").refill(bag.held_item()) if reachable else {"ok":false,"message":"Acércate al agua para rellenar la botella."}
	else:
		var cell: Vector2i = resources.target_at(aim)
		if resources.nodes.has(cell) and (resources.nodes[cell].hand_collectable or world.props[cell] == 5):
			if bag.held_id() != &"":
				result = {"ok":false,"message":"Deja las manos libres para recoger este objeto."}
			elif not resources.can_reach(cell,player):
				result = {"ok":false,"message":"Acércate al objeto para recogerlo."}
			else:
				cancel_work()
				pickup_cell = cell; pickup_aim = aim; pickup_committed = false
				interaction_motion.pick_up()
				result = {"ok":true,"message":"Recogiendo %s..." % resources.nodes[cell].name.to_lower()}
		else:
			result = {"ok":false,"message":"Apunta al agua para rellenar la botella." if bag.held_id() == &"botella" else "No hay un objeto para interactuar aquí."}
	feedback = result.message; feedback_time = 2
	inventory_panel.refresh(); full_avatar.update_pose(0); update_hud()
	return result.ok

func advance_pickup() -> void:
	if loot != null: loot.advance_pickup()
	if pickup_cell == resources.NONE or pickup_committed or interaction_motion.pickup_phase() < 0.5: return
	pickup_committed = true
	if bag.held_id() != &"" or not resources.can_reach(pickup_cell,player) or progression.health <= 0:
		feedback = "No se pudo recoger el objeto."; feedback_time = 2; return
	var gathered: Dictionary = resources.hit(pickup_cell,player)
	if gathered.get("depleted",false):
		feedback = "%s × %d recogido." % [bag.DEFINITIONS[StringName(gathered.material)].name,gathered.amount]
		world_view.queue_redraw(); world_view.props_layer.queue_redraw()
	else: feedback = "La mochila está llena." if gathered.get("reason") == "mochila_llena" else "No se pudo recoger el objeto."
	feedback_time = 2; inventory_panel.refresh(); update_hud()

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
	if life != null and (life.eating() or life.dying()): return false
	if progression.health <= 0 or is_paused() or not locomotion.jump(nutrition.speed_multiplier()*progression.speed_multiplier()):
		return false
	cancel_work()
	interaction_motion.cancel_pickup(); pickup_cell = resources.NONE
	equipping = false
	return true

func start_slide() -> bool:
	if life != null and (life.eating() or life.dying()): return false
	var input_direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if input_direction == Vector2.ZERO:
		input_direction = movement.target_direction
	if progression.health <= 0 or is_paused() or not running or not locomotion.slide(input_direction):
		return false
	cancel_work()
	interaction_motion.cancel_pickup(); pickup_cell = resources.NONE
	equipping = false
	return true

func _process(delta: float) -> void:
	if life != null and life.dying():
		life.advance(delta); solar_lighting.update_light(); return
	if progression.health <= 0 and life != null: life.die(); return
	if is_paused():
		return
	if life != null: life.advance(delta)
	if hut == null or not hut.inside: enemies.advance(delta)
	interaction_motion.advance(delta)
	advance_pickup()
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
		interaction_motion.cancel_pickup(); pickup_cell = resources.NONE
		last_tool_uid = uid
		equipping = bag.held_id() != &""
		equip_elapsed = 0
		if equipping: interaction_motion.draw_object()
	var direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if direction != Vector2.ZERO and working:
		cancel_work()
	running = not (life != null and life.eating()) and progression.health > 0 and direction != Vector2.ZERO and not working and not locomotion.airborne() and not locomotion.sliding() and locomotion.crouch < 0.01 and (gameplay_settings.values["auto_run"] or Input.is_physical_key_pressed(KEY_SHIFT))
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
	var pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not over_hud and bag.held_category() not in [&"bottle",&"workbench"]
	if over_hud: focused = resources.NONE
	if direction == Vector2.ZERO and not working and not equipping and pressed:
		start_work(aim)
	if working:
		advance_work(delta, aim)
	world_view.update_trees(player, delta)
	full_avatar.update_pose(delta)
	combat_effects.advance(delta)
	solar_lighting.update_light()
	interaction.text = feedback if feedback_time > 0 else ""

func cancel_work() -> void:
	if workbenches != null: workbenches.cancel_placement()
	bow_draw_uid = -1
	working = false
	work_elapsed = 0.0

func start_work(aim: Vector2) -> bool:
	if life != null and (life.eating() or life.dying()): return false
	if progression.health <= 0 or is_paused() or working or equipping or interaction_motion.picking_up() or locomotion.airborne() or locomotion.sliding():
		return false
	var item: StringName = bag.held_category()
	if item == &"bottle": return false
	if item == &"bow" and bag.count(&"flecha") == 0:
		feedback = "Necesitas flechas para disparar el arco"; feedback_time = 2; update_hud(); return false
	if item != &"" and not bag.usable():
		feedback = "La herramienta está rota."
		feedback_time = 2
		return false
	if item in [&"sword", &"bow"] and weapon_timer > 0:
		return false
	work_item_uid = bag.held_item().get("uid", -1)
	bow_draw_uid = work_item_uid if item == &"bow" else -1
	if item == &"bow": bag.consume_use(); update_hud()
	work_aim = aim
	work_contact_aim = Vector2(INF,INF)
	work_target = resources.target_at(aim)
	working = true
	work_elapsed = 0.0
	hit_applied = false
	work_duration = preload("res://scripts/action_motion.gd").DURATION.get(item,HARVEST_TIME)
	work_heading = (aim-player).angle()
	movement.heading = work_heading
	movement.target_direction = Vector2.ZERO
	return true

func advance_work(delta: float, _aim: Vector2 = Vector2(INF, INF)) -> void:
	if not working:
		return
	if bag.held_item().get("uid", -1) != work_item_uid:
		cancel_work()
		return
	work_elapsed += delta
	var target: Vector2 = work_contact_aim if hit_applied and work_contact_aim.is_finite() else resources.visual_aim(work_aim,player)
	movement.heading = work_heading
	var item: StringName = bag.held_category()
	var pose: Dictionary = preload("res://scripts/tool_contact.gd").contact(player,target,item,preload("res://scripts/turn_motion.gd").facing_at(work_heading))
	if not hit_applied and work_elapsed >= preload("res://scripts/action_motion.gd").contact_time(item,work_duration):
		work_contact_aim = resources.visual_aim(work_aim,player)
		hit_applied = true
		# Resolve the contact pose even when a long frame crosses the impact moment.
		pose = preload("res://scripts/tool_contact.gd").contact(player,resources.visual_aim(work_aim,player),item,preload("res://scripts/turn_motion.gd").facing_at(work_heading))
		if item in [&"sword", &"bow"]:
			use_weapon(work_aim, true, pose)
		else:
			resolve_melee_contact(work_aim,pose)

	if work_elapsed >= work_duration:
		cancel_work()

func use_weapon(target: Vector2, from_strike: bool = false, pose: Dictionary = {}) -> bool:
	var drawn_bow: bool = from_strike and bow_draw_uid == bag.held_item().get("uid",-2) and bag.held_category() == &"bow"
	if progression.health <= 0 or (working and not from_strike) or is_paused() or weapon_timer > 0 or (not bag.usable() and not drawn_bow):
		return false
	var id: StringName = bag.held_category()
	if id not in [&"sword", &"bow"]:
		return false
	if id == &"bow" and bag.count(&"flecha") == 0:
		feedback = "Necesitas flechas para disparar el arco"; feedback_time = 2; update_hud(); return false
	if pose.is_empty():
		pose = preload("res://scripts/tool_contact.gd").contact(player, target, id)
	combat_aim = player.direction_to(target)
	if combat_aim == Vector2.ZERO:
		combat_aim = Vector2.from_angle(movement.heading)
	weapon_timer = 0.45 if id == &"sword" else 0.65
	if id == &"sword":
		resolve_melee_contact(target,pose)
	else:
		var arrow := preload("res://scripts/arrow.gd").new()
		arrow.world = world
		arrow.game = self
		if not drawn_bow: bag.consume_use()
		bag.remove_amount(&"flecha",1)
		arrow.damage = bag.held_damage()
		arrow.position = full_avatar.shot_origin() if full_avatar != null else pose["tip"]
		arrow.velocity = arrow.position.direction_to(target) * 650
		if arrow.velocity == Vector2.ZERO:
			arrow.velocity = combat_aim * 650
		add_child(arrow)
		arrow.add_to_group("player_arrows")
	update_hud()
	return true

func resolve_melee_contact(target: Vector2, pose: Dictionary) -> bool:
	var category: StringName = bag.held_category()
	if category != &"" and not bag.usable(): return false
	if category in [&"sword",&"axe",&"pickaxe"]:
		for victim in get_tree().get_nodes_in_group("damageable"):
			if not victim is Node2D or not victim.has_method("take_damage"): continue
			var selected: bool = victim.contains_point(target) if victim.has_method("contains_point") else victim.global_position.distance_to(target) <= 18
			if selected and victim.global_position.distance_to(player) <= resources.REACH+9 and clear_combat_path(victim.global_position):
				victim.take_damage(combat_damage(bag.held_damage()))
				bag.consume_use(1 if category == &"sword" else 2)
				if not victim.has_method("hit_center"): combat_effects.flash(victim.global_position,player.direction_to(target))
				update_hud(); return true
	var cell: Vector2i = resources.target_at(target)
	if cell == resources.NONE or not resources.can_reach(cell,player):
		feedback = "Golpe al aire."; feedback_time = 1; return false
	var node: Dictionary = resources.nodes[cell]
	var material_id: String = node.material
	var impact: Vector2 = resources.visual_aim(target,player)
	var correct: bool = not node.hand_collectable and bag.can_harvest(material_id)
	var result: Dictionary = resources.hit(cell,player,0,true) if category != &"sword" else {"reason":"herramienta"}
	if category in [&"sword",&"axe",&"pickaxe"]:
		bag.consume_use(1 if category == &"sword" or correct else 2)
	impact_position = impact; impact_time = 0.18
	world_view.register_impact(cell,impact,pose.direction,material_id,1.0 if correct else 0.3)
	if category == &"sword": combat_effects.flash(impact,pose.direction)
	if result.has("reason"):
		feedback = "La mochila está llena." if result.reason == "mochila_llena" else "Ese objeto necesita otra herramienta o manos libres."
		feedback_time = 2
	elif result.get("depleted",false):
		feedback = "+%d %s" % [result.amount,result.material]
		if result.material == "fibra": feedback += " · +2 palos"
		feedback_time = 2; focused = resources.NONE
		world_view.queue_redraw()
	update_hud(); return true

func clear_combat_path(target: Vector2) -> bool:
	var distance := player.distance_to(target)
	for i in range(1, ceili(distance / 6.0)):
		if not world.walkable(player.move_toward(target, i * 6), 1):
			return false
	return true

func move_player(direction: Vector2, delta: float) -> void:
	if workbenches != null and workbenches.placing(): return
	var velocity: Vector2 = movement.step(direction, delta, WALK_SPEED*progression.speed_multiplier()*nutrition.speed_multiplier()*(RUN_MULTIPLIER if running else 1.0))
	if locomotion.sliding():
		movement.step(locomotion.slide_direction,delta,220)
	if locomotion.airborne() and locomotion.from_slide:
		locomotion.steer_air(direction,delta)
		movement.heading = locomotion.jump_heading
		movement.target_direction = Vector2.ZERO
		movement.speed_factor = 1.0
	velocity = locomotion.velocity(velocity,nutrition.speed_multiplier()*progression.speed_multiplier())
	velocity *= interaction_motion.speed_multiplier()
	var motion := velocity * delta
	player = hut.move_inside(player,motion) if hut != null and hut.inside else world.move_actor(player,motion,world.PLAYER_RADIUS,ground_height+locomotion.height(),rock_support)
	update_ground_support()
	update_camera_position()
func update_camera_position() -> void:
	if camera == null: return
	camera.position = player
	if gameplay_settings.values.get("sharp_camera",false):
		var pixels := camera.zoom*get_viewport().get_final_transform().get_scale().abs()
		if pixels.x > 0 and pixels.y > 0:
			camera.position = (player*pixels).round()/pixels

func update_hud() -> void:
	interaction.text = feedback if feedback_time > 0 else ""
	if styled_hud != null: styled_hud.refresh()

func update_ground_support() -> void:
	if hut != null and hut.inside: ground_height = 0; rock_support = world.NO_SUPPORT; return
	if locomotion.airborne(): previously_airborne = true; return
	var platform_height: float = world.surface_height(player)
	if rock_support != world.NO_SUPPORT and (not world.props.has(rock_support) or not world.prop_collisions[rock_support].grow(world.PLAYER_RADIUS).has_point(player+Vector2(0,17))):
		rock_support = world.NO_SUPPORT
	if rock_support == world.NO_SUPPORT:
		for cell in world.collision_cells.get(world.cell_at(player+Vector2(0,17)),[]):
			if world.props[cell] != 1 or world.physical_height(cell) > world.JUMP_LIMIT: continue
			if world.prop_collisions[cell].has_point(player+Vector2(0,17)) and previously_airborne:
				rock_support = cell; break
	ground_height = maxf(platform_height,world.physical_height(rock_support) if world.props.has(rock_support) and world.prop_collisions[rock_support].has_point(player+Vector2(0,17)) else 0.0)
	previously_airborne = false
