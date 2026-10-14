extends Control
signal crafted(message: String)
const Workshop = preload("res://scripts/workshop.gd")
const Model = preload("res://scripts/inventory.gd")
const Icons = preload("res://scripts/item_icons.gd")
const Style = preload("res://scripts/ui_style.gd")
var creation_seconds := 2.0
var model
var station_level := 0
var selected: StringName = &"pickaxe"
var recipe_buttons: Dictionary = {}
var object_name: Label
var preview: TextureRect
var result_label: Label
var materials: VBoxContainer
var create_button: Button
var cancel_button: Button
var message: Label
var progress: ProgressBar
var animation_area: Control
var remaining := 0.0
var reservation
var pending: StringName = &""

func configure(bag, level: int = 0) -> void:
	station_level = level
	model = bag; size = Vector2(1260,780)
	var scroll := ScrollContainer.new(); scroll.position = Vector2(12,12)
	scroll.size = Vector2(380,756) if station_level > 0 else Vector2(570,508)
	add_child(scroll)
	var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",8); scroll.add_child(list)
	var heading := Label.new(); heading.text = "RECETAS"; Style.set_font_size(heading,15); list.add_child(heading)
	var candidates := Model.DEFAULT_RECIPES.duplicate()
	for id in Workshop.RECIPES:
		if id not in candidates: candidates.append(id)
	for id in candidates:
		if not Workshop.RECIPES.has(id) and id != &"cuero": continue
		if station_level == 0 and Workshop.required_station(model,id) > 0: continue
		if station_level > 0 and id == &"basic_workbench": continue
		var button := preload("res://scripts/menu_button.gd").new()
		button.text = Model.DEFINITIONS[id].name; button.tooltip_text = button.text
		Style.set_font_size(button,15)
		button.minimum_left_padding = button.get_theme_font("font").get_string_size("M",HORIZONTAL_ALIGNMENT_LEFT,-1,15).x*0.5
		button.fit_horizontal = Control.SIZE_SHRINK_BEGIN
		button.icon = Icons.get_icon(id); button.expand_icon = true
		if button.icon != null: button.icon_display_width = 65*button.icon.get_width()/maxf(button.icon.get_width(),button.icon.get_height())
		button.add_theme_constant_override("icon_max_width",ceili(button.icon_display_width))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(select_recipe.bind(id)); list.add_child(button); recipe_buttons[id] = button
	# The sheet starts at x=55 in a 1370-wide popup: x=630 is its exact midpoint.
	object_name = make_label(Vector2(630,12),Vector2(620,28),19)
	preview = TextureRect.new(); preview.position = Vector2(630,48); preview.size = Vector2(302,256)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; preview.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(preview)
	materials = VBoxContainer.new(); materials.position = Vector2(950,48); materials.size = Vector2(300,260)
	materials.add_theme_constant_override("separation",12); add_child(materials)
	result_label = make_label(Vector2(630,320),Vector2(620,40),12)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress = ProgressBar.new(); progress.position = Vector2(630,370); progress.size = Vector2(620,20)
	progress.min_value = 0; progress.max_value = creation_seconds; progress.show_percentage = false; add_child(progress)
	create_button = preload("res://scripts/menu_button.gd").new(); create_button.text = "Crear · 2 s"
	Style.set_font_size(create_button,15)
	create_button.position = Vector2(630,412); create_button.pressed.connect(create_selected); add_child(create_button)
	cancel_button = preload("res://scripts/menu_button.gd").new(); cancel_button.text = "Cancelar"
	Style.set_font_size(cancel_button,15)
	cancel_button.position = Vector2(890,412); cancel_button.pressed.connect(cancel_creation); add_child(cancel_button)
	message = make_label(Vector2(630,460),Vector2(620,40),12); message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Deliberately empty: the final third is reserved for future crafting animation.
	animation_area = Control.new(); animation_area.name = "CreationAnimation"
	animation_area.position = Vector2(0,size.y*2.0/3.0); animation_area.size = Vector2(size.x,size.y/3.0)
	animation_area.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(animation_area)
	visibility_changed.connect(func():
		if not is_visible_in_tree(): cancel_creation()
	)
	if station_level > 0:
		object_name.hide(); preview.hide(); result_label.hide()
		materials.position = Vector2(420,12); materials.size = Vector2(380,350)
		create_button.position = Vector2(840,12); cancel_button.position = Vector2(840,70)
		progress.position = Vector2(840,120); progress.size = Vector2(400,20)
		message.position = Vector2(840,160); message.size = Vector2(400,160)
		animation_area.position = Vector2(420,390); animation_area.size = Vector2(840,390)
	refresh()

func make_label(point: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new(); label.position = point; label.size = dimensions
	Style.set_font_size(label,font_size); label.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(label); return label

func is_crafting() -> bool: return reservation != null

func select_recipe(id: StringName) -> void:
	if is_crafting() or id not in Workshop.recipe_ids(model,station_level): return
	selected = id; message.text = ""; refresh()

func refresh() -> void:
	if model == null: return
	var available := Workshop.recipe_ids(model,station_level)
	if selected not in available and not available.is_empty(): selected = available[0]
	if available.is_empty():
		object_name.text = "Sin recetas desbloqueadas"; preview.texture = null; result_label.text = ""
		create_button.disabled = true; cancel_button.hide(); progress.hide()
		for button in recipe_buttons.values(): button.hide()
		for child in materials.get_children(): materials.remove_child(child); child.queue_free()
		return
	var known := Workshop.RECIPES.has(selected)
	object_name.text = Model.DEFINITIONS[selected].name
	preview.texture = Icons.get_icon(selected)
	result_label.text = "Resultado: %s × %d" % [Model.DEFINITIONS[selected].name,Workshop.OUTPUT_COUNTS.get(selected,1)] if known else "Receta pendiente de definir."
	if selected == &"cuerda": result_label.text = "Resultado: 1 metro de cuerda"
	elif selected == &"botella": result_label.text = "Resultado: 1 botella vacía · capacidad 500 ml"
	for id in recipe_buttons:
		recipe_buttons[id].self_modulate = Color("d9bf72") if id == selected else Color.WHITE
		recipe_buttons[id].disabled = is_crafting()
		recipe_buttons[id].visible = id in Workshop.recipe_ids(model,station_level)
	for child in materials.get_children(): materials.remove_child(child); child.queue_free()
	var heading := Label.new(); heading.text = "RESERVADOS / NECESARIOS" if is_crafting() else "DISPONIBLES / NECESARIOS"; Style.set_font_size(heading,12); materials.add_child(heading)
	for id in Workshop.RECIPES.get(selected,{}):
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation",10)
		var icon := TextureRect.new(); icon.texture = Icons.get_icon(id); icon.custom_minimum_size = Vector2(65,65)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; icon.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_child(icon)
		var amount := Label.new(); amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL; amount.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var have: int = Workshop.RECIPES[selected][id] if is_crafting() else model.count(id); var need: int = Workshop.RECIPES[selected][id]
		amount.text = "%s: %d / %d%s" % [Model.DEFINITIONS[id].name,have,need," m" if id in [&"cuerda",&"hilo"] else ""]
		Style.set_font_size(amount,13); amount.modulate = Color("c6d5a3") if have >= need else Color("d19c91")
		row.add_child(amount); materials.add_child(row)
	create_button.disabled = is_crafting() or not known or not Workshop.affordable(model,Workshop.RECIPES.get(selected,{}))
	create_button.tooltip_text = "Receta pendiente de definir." if not known else ("Faltan materiales." if create_button.disabled and not is_crafting() else "Fabricar en 2 segundos y guardar en la mochila.")
	cancel_button.visible = is_crafting(); progress.visible = is_crafting()

func create_selected() -> void:
	if is_crafting(): return
	var trial = model.fork()
	var error := Workshop.craft(trial,selected,station_level)
	if not error.is_empty(): message.text = error; return
	reservation = model.fork(); pending = selected
	for material_id in Workshop.RECIPES[pending]: model.remove_amount(material_id,Workshop.RECIPES[pending][material_id])
	creation_seconds = Workshop.CREATION_TIMES[pending]; progress.max_value = creation_seconds
	remaining = creation_seconds; progress.value = 0
	message.text = "Creando · 2,0 s"; refresh(); crafted.emit(message.text)

func _process(delta: float) -> void:
	if not is_crafting(): return
	if not is_visible_in_tree(): cancel_creation(); return
	advance_creation(delta)

func advance_creation(delta: float) -> void:
	if not is_crafting(): return
	remaining = maxf(0,remaining-maxf(0,delta)); progress.value = creation_seconds-remaining
	message.text = "Creando · %.1f s" % remaining
	if remaining > 0.000001: return
	if not model.add(pending,Workshop.OUTPUT_COUNTS.get(pending,1)):
		cancel_creation(); message.text = "La mochila está llena. Materiales devueltos."; return
	reservation = null; pending = &""; remaining = 0
	refresh(); message.text = "Objeto creado y guardado en la mochila."; crafted.emit(message.text)

func cancel_creation() -> void:
	if not is_crafting(): return
	# Item movement is locked during this short reservation; exact UID/location
	# restoration preserves both backpack and physical quick-bar ingredients.
	model.slots = reservation.slots; model.quick_slots = reservation.quick_slots
	reservation = null; remaining = 0; pending = &""
	refresh(); message.text = "Creación cancelada. Materiales devueltos."; crafted.emit(message.text)
