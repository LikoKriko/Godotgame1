extends Control
## Shared isolated glyphs and frames; active areas use Control rectangles.
const Icons = preload("res://scripts/item_icons.gd")
var game
var quick_buttons: Array[Button] = []
var skill_buttons: Array[Button] = []
var skill_labels: Array[Label] = []
var shortcuts: Array[Button] = []
var setting_button: Button
var pause_button: Button
var map_button: Button
var life: Label
var food: Label
var water: Label
var clock: Label
var weight: Label
var level_label: Label
var placement_bar: Panel
var placement_fill: ColorRect
var quick_bar: Control
var skill_bar: Control
var map_frame: Control
var refresh_elapsed := 0.0
var map_terrain: Texture2D
var map_seed := -1
var map_prop_count := -1
var terrain_rebuilds := 0
var displayed_state: Array = []
var displayed_map: Array = []

func configure(owner_game) -> void:
	game = owner_game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = preload("res://scripts/ui_style.gd").theme()
	setting_button = framed_button("⚙", Rect2(40,37,57,52))
	setting_button.text = ""; setting_button.icon = load("res://assets/ui/styles/settings_icon.png")
	setting_button.tooltip_text = "Configuración"
	setting_button.pressed.connect(game.request_settings)
	pause_button = framed_button("Ⅱ", Rect2(116,37,55,52))
	pause_button.text = ""; pause_button.icon = load("res://assets/ui/styles/pause_icon.png")
	pause_button.tooltip_text = "Pausa"
	pause_button.pressed.connect(func(): game.menu_requested.emit())
	map_frame = Control.new()
	map_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_frame.size = Vector2(195,183)
	add_child(map_frame)
	map_frame.draw.connect(draw_map)
	map_button = framed_button("M", Rect2(1596,46,42,42),map_frame)
	map_button.position = Vector2(144,16)
	map_button.size = Vector2(42,42)
	map_button.text = ""; map_button.icon = load("res://assets/ui/styles/map_icon.png")
	map_button.tooltip_text = "Abrir mapa (M)"
	map_button.pressed.connect(open_map)
	clock = framed_label(Vector2(195,34))
	level_label = framed_label(Vector2(120,34))
	quick_bar = bar("INVENTARIO RÁPIDO",Vector2(420,98),Rect2(554,805,420,98))
	var quick_layer := CanvasLayer.new()
	quick_layer.layer = 9
	add_child(quick_layer)
	quick_bar.reparent(quick_layer,false)
	placement_bar = Panel.new(); placement_bar.position = Vector2(80,-30); placement_bar.size = Vector2(260,22)
	placement_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placement_bar.add_theme_stylebox_override("panel",preload("res://scripts/ui_style.gd").frame(&"game",true,6))
	quick_bar.add_child(placement_bar)
	placement_fill = ColorRect.new(); placement_fill.color = Color("c9e5b3")
	placement_fill.position = Vector2(6,6); placement_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placement_bar.add_child(placement_fill); placement_bar.hide()
	for i in 6:
		var button := framed_button("",Rect2(),quick_bar,true)
		button.game = game; button.kind = &"quick"; button.slot = i
		button.position = Vector2(13+i*67,32)
		button.size = Vector2(60,58)
		button.pressed.connect(func():
			if game.inventory_panel.visible: game.inventory_panel.select_quick(i)
			else: game.use_quick_item(i)
		)
		preload("res://scripts/ui_style.gd").set_font_size(button,14)
		var key := Label.new()
		key.text = str(i+1); key.position = Vector2(4,1)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preload("res://scripts/ui_style.gd").set_font_size(key,12)
		key.visible = true
		button.add_child(key)
		var icon := TextureRect.new()
		icon.name = "ItemIcon"; icon.position = Vector2(10,8); icon.size = Vector2(40,40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		var count := Label.new()
		count.name = "Amount"; count.position = Vector2(4,39); count.size = Vector2(51,15)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		preload("res://scripts/ui_style.gd").set_font_size(count,12)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(count)
		quick_buttons.append(button)
	skill_bar = bar("HABILIDADES",Vector2(238,98),Rect2(992,805,238,98))
	for i in 4:
		var button := framed_button("",Rect2(),skill_bar,true)
		var caption := Label.new(); caption.text = ["Z","X","—","—"][i]
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preload("res://scripts/ui_style.gd").set_font_size(caption,16); button.add_child(caption); skill_labels.append(caption)
		button.position = Vector2(12+i*55,34); button.size = Vector2(50,54)
		preload("res://scripts/ui_style.gd").set_font_size(button,16)
		if i < 2: button.pressed.connect(func(): game.activate_skill(&"speed" if i == 0 else &"power"))
		else: button.disabled = true; button.tooltip_text = "Sin habilidad asignada"
		skill_buttons.append(button)
	life = framed_label(Vector2(156,40),Rect2(40,814,121,41))
	food = framed_label(Vector2(180,40),Rect2(40,860,156,40))
	water = framed_label(Vector2(180,40))
	preload("res://scripts/ui_style.gd").set_font_size(water,14)
	weight = framed_label(Vector2(100,28))
	preload("res://scripts/ui_style.gd").set_font_size(weight,12)
	for pair in [["Inventario (I)",0],["Crear (T)",1],["Mapa (M)",2]]:
		var button := framed_button(pair[0],Rect2())
		button.size = Vector2(174,34)
		preload("res://scripts/ui_style.gd").set_font_size(button,16)
		button.pressed.connect(func(): open_shortcut(pair[1]))
		shortcuts.append(button)
	resized.connect(fit)
	game.gameplay_settings.changed.connect(fit)
	fit()
	refresh()

func frame(node: Control, _region: Rect2 = Rect2()) -> void:
	var panel := Panel.new(); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE; panel.show_behind_parent = true
	panel.add_theme_stylebox_override("panel",preload("res://scripts/ui_style.gd").frame())
	node.add_child(panel)

func framed_button(text: String, _region: Rect2, parent: Node = self, _over_art: bool = false) -> Button:
	var button := preload("res://scripts/item_slot.gd").new() if parent == quick_bar else preload("res://scripts/menu_button.gd").new()
	button.text = text; parent.add_child(button)
	preload("res://scripts/ui_style.gd").skin_button(button)
	return button

func framed_label(dimensions: Vector2, region: Rect2 = Rect2()) -> Label:
	var label := Label.new()
	label.size = dimensions
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preload("res://scripts/ui_style.gd").set_font_size(label,16)
	add_child(label)
	# Labels must be live, not the example values printed in the reference.
	var fill := StyleBoxEmpty.new()
	fill.content_margin_left = 10 if region.size == Vector2.ZERO else 38
	fill.content_margin_right = 10
	label.add_theme_stylebox_override("normal",fill)
	frame(label)
	if region.size != Vector2.ZERO:
		var icon := TextureRect.new()
		icon.texture = load("res://assets/ui/styles/life_icon.png" if region.position.y == 814 else "res://assets/ui/styles/food_icon.png")
		icon.position = Vector2(9,6); icon.size = Vector2(28,28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE; label.add_child(icon)

	return label

func bar(text: String, dimensions: Vector2, _region: Rect2) -> Control:
	var node := Control.new()
	node.size = dimensions; node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	frame(node)
	var label := Label.new(); label.text = text; label.position = Vector2(0,4); label.size = Vector2(dimensions.x,24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preload("res://scripts/ui_style.gd").set_font_size(label,14); node.add_child(label)

	return node

func fit() -> void:
	var factor: float = preload("res://scripts/game_settings.gd").hud_scale(game.gameplay_settings.values.hud_size)
	var screen := get_viewport_rect().size
	for node in [setting_button,pause_button,map_frame,quick_bar,skill_bar,life,food,water,clock,weight,level_label]+shortcuts:
		node.scale = Vector2.ONE*factor
	setting_button.position = Vector2(18,18); setting_button.size = Vector2(52,48)
	pause_button.position = setting_button.position+Vector2(64*factor,0); pause_button.size = Vector2(52,48)
	map_frame.position = Vector2(screen.x-18-195*factor,18)
	level_label.position = map_frame.position-Vector2(126*factor,0)
	clock.position = map_frame.position+Vector2(0,189*factor)
	var total := (420+18+238)*factor
	quick_bar.position = Vector2((screen.x-total)/2,screen.y-18-98*factor)
	skill_bar.position = quick_bar.position+Vector2(438*factor,0)
	life.position = Vector2(18,screen.y-18-120*factor)
	game.interaction.position = life.position-Vector2(0,game.interaction.get_theme_font("font").get_height(game.interaction.get_theme_font_size("font_size"))*factor+8)
	food.position = life.position+Vector2(0,40*factor)
	water.position = food.position+Vector2(0,40*factor)
	weight.position = Vector2(screen.x-18-100*factor,screen.y-18-28*factor)
	for i in shortcuts.size():
		shortcuts[i].fit_text()
		shortcuts[i].position = Vector2(screen.x-18-shortcuts[i].size.x*factor,screen.y-18-(140-i*36)*factor)

func draw_map() -> void:
	preload("res://scripts/ui_style.gd").frame().draw(map_frame.get_canvas_item(),Rect2(Vector2.ZERO,map_frame.size))
	map_frame.draw_string(preload("res://scripts/ui_style.gd").menu_font(),Vector2(10,24),"MAPA",HORIZONTAL_ALIGNMENT_LEFT,-1,16)
	var terrain_rect := Rect2(10,44,175,127)
	if map_terrain != null: map_frame.draw_texture_rect(map_terrain,terrain_rect,false)
	var point: Vector2 = terrain_rect.position+((game.hut.outside_player if game.hut.inside else game.player)-game.world.bounds.position)/game.world.bounds.size*terrain_rect.size
	map_frame.draw_circle(point,2.5,Color("ffe078"))

func open_map() -> void:
	game.cancel_work(); game.inventory_panel.hide(); game.world_map.open_map()

func open_shortcut(index: int) -> void:
	if index == 2: open_map(); return
	game.cancel_work(); game.world_map.hide(); game.inventory_panel.open_section(index)

func refresh_terrain() -> void:
	if map_seed == game.world.seed_value and map_prop_count == game.world.props.size(): return
	map_seed = game.world.seed_value; map_prop_count = game.world.props.size()
	var pixels := Image.create(game.world.SIZE.x,game.world.SIZE.y,false,Image.FORMAT_RGB8)
	for cell in game.world.cells:
		var data: Dictionary = game.world.cells[cell]
		var color := Color("737968") if data.blocked else Color("414a39")
		if data.road and not data.blocked: color = Color("6a6351")
		pixels.set_pixelv(cell-game.world.FIRST,color)
	map_terrain = ImageTexture.create_from_image(pixels)
	terrain_rebuilds += 1

func refresh() -> void:
	refresh_terrain()
	var map_state := [game.player,terrain_rebuilds,map_frame.size]
	if map_state != displayed_map:
		displayed_map = map_state; map_frame.queue_redraw()
	var held_uid: int = game.bag.held_item().get("uid",-1)
	var quick_state := []
	for item in game.bag.quick_slots:
		if item.is_empty(): quick_state.append(-1)
		else: quick_state.append([item.uid,item.id,item.quantity,item.uses,item.get("water_ml",0) > 0])
	var skill_state := []
	for id in [&"speed",&"power"]: skill_state.append([ceilf(game.progression.cooldowns[id]),game.progression.skills[id] == 0])
	# Compare displayed values, rather than raw hydration/cooldown floats: their
	# hidden fractional changes must not rebuild identical labels and icons.
	var state := ["%.0f / %.0f" % [game.progression.health,game.progression.max_health()],game.nutrition.calories_today,roundi(game.nutrition.speed_penalty()*100),"Agua: %.0f / 2000 ml" % game.nutrition.hydration_ml,game.day_cycle.clock_text(),quick_state,held_uid,skill_state,game.bag.count(&"flecha"),game.level]
	if state == displayed_state: return
	displayed_state = state
	life.text = "%.0f / %.0f" % [game.progression.health,game.progression.max_health()]
	food.text = "%d kcal" % game.nutrition.calories_today
	food.tooltip_text = "Calorías de hoy / 1600 kcal. Velocidad: −%d%%" % roundi(game.nutrition.speed_penalty()*100)
	water.text = "Agua: %.0f / 2000 ml" % game.nutrition.hydration_ml
	weight.text = "60 kg"
	clock.text = game.day_cycle.clock_text()
	level_label.text = "NIVEL: %d" % game.level
	for i in 6:
		var item: Dictionary = game.bag.quick_slots[i]
		var icon: TextureRect = quick_buttons[i].get_node("ItemIcon")
		var amount: Label = quick_buttons[i].get_node("Amount")
		if item.is_empty():
			quick_buttons[i].modulate = Color.WHITE
			icon.texture = null; amount.text = ""
			quick_buttons[i].tooltip_text = "Espacio rápido %d vacío. Arrastra un objeto desde el inventario." % (i+1)
		else:
			icon.texture = Icons.for_item(item)
			amount.text = str(item.quantity) if item.quantity > 1 else ""
			quick_buttons[i].tooltip_text = "%s · %d" % [game.bag.DEFINITIONS[item.id].name,i+1]
			var definition: Dictionary = game.bag.DEFINITIONS[item.id]
			if definition.has("damage"): quick_buttons[i].tooltip_text += "\nDaño base: %d" % definition.damage
			if item.uses >= 0: quick_buttons[i].tooltip_text += "\nUsos: %d / %d" % [item.uses,definition.uses]
			if item.id == &"bow": quick_buttons[i].tooltip_text += "\nFlechas disponibles: %d" % game.bag.count(&"flecha")
			quick_buttons[i].modulate = Color("d6c895") if item.uid == held_uid else Color.WHITE
	for i in 2:
		var id: StringName = &"speed" if i == 0 else &"power"
		var remaining: float = game.progression.cooldowns[id]
		skill_labels[i].text = ("Z" if i == 0 else "X") if remaining <= 0 else "%.0f s" % ceilf(remaining)
		skill_buttons[i].disabled = game.progression.skills[id] == 0 or remaining > 0
		skill_buttons[i].tooltip_text = game.progression.SKILLS[id].name

func _process(delta: float) -> void:
	if game.workbenches != null:
		placement_bar.visible = game.workbenches.placing()
		placement_fill.size = Vector2(248*(1-game.workbenches.remaining/3.0),10)
	quick_bar.visible = not game.world_map.visible
	refresh_elapsed += delta
	if refresh_elapsed >= 0.1:
		refresh_elapsed = 0
		refresh()
