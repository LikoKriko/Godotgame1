extends Control
## Reference art is cropped at draw time; no scenery from the HUD template is
## drawn over the world. All active areas are ordinary Control rectangles.
const Icons = preload("res://scripts/item_icons.gd")
const DESIGN := Vector2(1672,941)
const REFERENCE := "res://assets/ui/hud_template.png"
var game
var source: Texture2D
var quick_buttons: Array[Button] = []
var skill_buttons: Array[Button] = []
var shortcuts: Array[Button] = []
var setting_button: Button
var pause_button: Button
var map_button: Button
var life: Label
var food: Label
var water: Label
var clock: Label
var weight: Label
var quick_bar: Control
var skill_bar: Control
var map_frame: Control
var refresh_elapsed := 0.0
var map_terrain: Texture2D
var map_seed := -1
var map_prop_count := -1
var terrain_rebuilds := 0

func configure(owner_game) -> void:
	game = owner_game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = preload("res://scripts/ui_style.gd").theme()
	if ResourceLoader.exists(REFERENCE): source = load(REFERENCE)
	setting_button = framed_button("⚙", Rect2(40,37,57,52))
	setting_button.tooltip_text = "Configuración"
	setting_button.pressed.connect(func(): game.settings_requested.emit())
	pause_button = framed_button("Ⅱ", Rect2(116,37,55,52))
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
	map_button.tooltip_text = "Abrir mapa (M)"
	map_button.pressed.connect(open_map)
	clock = framed_label(Vector2(195,34))
	quick_bar = bar("INVENTARIO RÁPIDO",Vector2(420,98),Rect2(554,805,420,98))
	var quick_layer := CanvasLayer.new()
	quick_layer.layer = 9
	add_child(quick_layer)
	quick_bar.reparent(quick_layer,false)
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
		key.visible = source == null
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
		var button := framed_button(["Z","X","—","—"][i],Rect2(),skill_bar,true)
		button.position = Vector2(12+i*55,34); button.size = Vector2(50,54)
		preload("res://scripts/ui_style.gd").set_font_size(button,16)
		if source != null:
			# Cover the printed example X, keeping the original slot's rim.
			var empty := TextureRect.new()
			empty.texture = art_region(Rect2(586,857,26,25))
			empty.position = Vector2(6,6); empty.size = Vector2(38,42)
			empty.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
			empty.show_behind_parent = true
			button.add_child(empty)
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

func art_region(region: Rect2) -> Texture2D:
	if source == null or region.size == Vector2.ZERO: return null
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(region.position*source.get_size()/DESIGN,region.size*source.get_size()/DESIGN)
	return atlas

func frame(node: Control, region: Rect2 = Rect2()) -> void:
	var texture := art_region(region)
	if texture != null:
		var art := TextureRect.new()
		art.texture = texture
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.show_behind_parent = true
		node.add_child(art)
	else:
		var panel := Panel.new()
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.show_behind_parent = true
		var style := StyleBoxFlat.new()
		style.bg_color = Color("141d18"); style.border_color = Color("828169")
		style.set_border_width_all(1)
		panel.add_theme_stylebox_override("panel",style)
		node.add_child(panel)
		if source != null:
			var border := StyleBoxTexture.new()
			border.texture = art_region(Rect2(40,814,121,41))
			border.texture_margin_left = 8; border.texture_margin_right = 8
			border.texture_margin_top = 8; border.texture_margin_bottom = 8
			border.draw_center = false
			var rim := Panel.new()
			rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rim.show_behind_parent = true
			rim.add_theme_stylebox_override("panel",border)
			node.add_child(rim)

func framed_button(text: String, region: Rect2, parent: Node = self, over_art: bool = false) -> Button:
	var button := preload("res://scripts/item_slot.gd").new() if parent == quick_bar else preload("res://scripts/menu_button.gd").new()
	button.text = "" if source != null and region.size != Vector2.ZERO else text
	parent.add_child(button)
	if not over_art: frame(button,region)
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.6,0.8,0.6,0.18) if state in ["hover","pressed"] else Color(0,0,0,0.35 if state == "disabled" else 0)
		style.border_color = Color("c4c694")
		style.set_border_width_all(1 if state == "focus" else 0)
		button.add_theme_stylebox_override(state,style)
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
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("141d18")
	fill.content_margin_left = 10 if region.size == Vector2.ZERO else 38
	fill.content_margin_right = 10
	label.add_theme_stylebox_override("normal",fill)
	if source != null:
		var style := StyleBoxTexture.new()
		style.texture = art_region(region if region.size != Vector2.ZERO else Rect2(40,814,121,41))
		style.texture_margin_left = 8; style.texture_margin_right = 8
		style.texture_margin_top = 8; style.texture_margin_bottom = 8
		style.draw_center = false
		var border := Panel.new()
		border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		border.add_theme_stylebox_override("panel",style)
		label.add_child(border)
		if region.size != Vector2.ZERO:
			var icon := TextureRect.new()
			icon.texture = art_region(Rect2(47,820,30,29) if region.position.y == 814 else Rect2(47,865,29,29))
			icon.position = Vector2(9,6); icon.size = Vector2(28,28)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.add_child(icon)
	else: frame(label)
	return label

func bar(text: String, dimensions: Vector2, region: Rect2) -> Control:
	var node := Control.new()
	node.size = dimensions; node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	if source != null:
		# Follow the frame/header silhouette instead of rendering the rectangle
		# of scenery surrounding it in the source image.
		var outline := PackedVector2Array([Vector2(0,24),Vector2(113,24),Vector2(119,7),Vector2(129,0),Vector2(291,0),Vector2(305,20),Vector2(420,24),Vector2(420,98),Vector2(0,98)]) if dimensions.x == 420 else PackedVector2Array([Vector2(0,24),Vector2(49,24),Vector2(53,11),Vector2(60,4),Vector2(179,4),Vector2(189,24),Vector2(238,24),Vector2(238,98),Vector2(0,98)])
		var mesh := Polygon2D.new()
		mesh.polygon = outline
		mesh.texture = source
		mesh.show_behind_parent = true
		var uv := PackedVector2Array()
		for point in outline: uv.append((region.position+point)*source.get_size()/DESIGN)
		mesh.uv = uv
		node.add_child(mesh)
	else: frame(node,region)
	if source == null:
		var label := Label.new()
		label.text = text; label.position = Vector2(0,4); label.size = Vector2(dimensions.x,24)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preload("res://scripts/ui_style.gd").set_font_size(label,14)
		node.add_child(label)
	return node

func fit() -> void:
	var factor: float = game.gameplay_settings.hud_scale(game.gameplay_settings.values.hud_size)
	var screen := get_viewport_rect().size
	for node in [setting_button,pause_button,map_frame,quick_bar,skill_bar,life,food,water,clock,weight]+shortcuts:
		node.scale = Vector2.ONE*factor
	setting_button.position = Vector2(18,18); setting_button.size = Vector2(52,48)
	pause_button.position = setting_button.position+Vector2(64*factor,0); pause_button.size = Vector2(52,48)
	map_frame.position = Vector2(screen.x-18-195*factor,18)
	clock.position = map_frame.position+Vector2(0,189*factor)
	var total := (420+18+238)*factor
	quick_bar.position = Vector2((screen.x-total)/2,screen.y-18-98*factor)
	skill_bar.position = quick_bar.position+Vector2(438*factor,0)
	life.position = Vector2(18,screen.y-18-120*factor)
	food.position = life.position+Vector2(0,40*factor)
	water.position = food.position+Vector2(0,40*factor)
	weight.position = Vector2(screen.x-18-100*factor,screen.y-18-28*factor)
	for i in shortcuts.size():
		shortcuts[i].position = Vector2(screen.x-18-174*factor,screen.y-18-(140-i*36)*factor)

func draw_map() -> void:
	var texture := art_region(Rect2(1452,30,195,183))
	if texture != null: map_frame.draw_texture_rect(texture,Rect2(Vector2.ZERO,map_frame.size),false)
	else:
		map_frame.draw_rect(Rect2(Vector2.ZERO,map_frame.size),Color("141d18"))
		map_frame.draw_rect(Rect2(Vector2.ZERO,map_frame.size),Color("828169"),false,1)
		map_frame.draw_string(ThemeDB.fallback_font,Vector2(10,24),"MAPA",HORIZONTAL_ALIGNMENT_LEFT,-1,16)
	var terrain_rect := Rect2(10,44,175,127)
	if map_terrain != null: map_frame.draw_texture_rect(map_terrain,terrain_rect,false)
	var point: Vector2 = terrain_rect.position+(game.player-game.world.bounds.position)/game.world.bounds.size*terrain_rect.size
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
	life.text = "%.0f / %.0f" % [game.progression.health,game.progression.max_health()]
	food.text = "%d kcal" % game.nutrition.calories_today
	food.tooltip_text = "Calorías de hoy / 1600 kcal. Velocidad: −%d%%" % roundi(game.nutrition.speed_penalty()*100)
	water.text = "Agua: %.0f / 2000 ml" % game.nutrition.hydration_ml
	weight.text = "60 kg"
	clock.text = game.day_cycle.clock_text()
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
			quick_buttons[i].modulate = Color("d6c895") if item.uid == game.bag.held_item().get("uid",-1) else Color.WHITE
	for i in 2:
		var id: StringName = &"speed" if i == 0 else &"power"
		var remaining: float = game.progression.cooldowns[id]
		skill_buttons[i].text = ("Z" if i == 0 else "X") if remaining <= 0 else "%.0f s" % ceilf(remaining)
		skill_buttons[i].disabled = game.progression.skills[id] == 0 or remaining > 0
		skill_buttons[i].tooltip_text = game.progression.SKILLS[id].name
	map_frame.queue_redraw()

func _process(delta: float) -> void:
	quick_bar.visible = not game.world_map.visible
	refresh_elapsed += delta
	if refresh_elapsed >= 0.1:
		refresh_elapsed = 0
		refresh()
