extends Control
signal crafted(message: String)
const Workshop = preload("res://scripts/workshop.gd")
const Model = preload("res://scripts/inventory.gd")
const Icons = preload("res://scripts/item_icons.gd")
const Style = preload("res://scripts/ui_style.gd")
var creation_seconds := 2.0
var model
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

func configure(bag) -> void:
	model = bag; size = Vector2(1260,780)
	var list := VBoxContainer.new(); list.position = Vector2(12,12)
	list.size = Vector2(570,480); list.add_theme_constant_override("separation",12); add_child(list)
	var heading := Label.new(); heading.text = "RECETAS"; Style.set_font_size(heading,15); list.add_child(heading)
	for id in Workshop.RECIPES:
		var button := preload("res://scripts/menu_button.gd").new()
		button.text = Model.DEFINITIONS[id].name; button.tooltip_text = button.text
		Style.set_font_size(button,15)
		button.minimum_left_padding = button.get_theme_font("font").get_string_size("M",HORIZONTAL_ALIGNMENT_LEFT,-1,15).x*0.5
		button.fit_horizontal = Control.SIZE_SHRINK_BEGIN
		button.icon = Icons.get_icon(id); button.expand_icon = true
		button.add_theme_constant_override("icon_max_width",65)
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
	refresh()

func make_label(point: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new(); label.position = point; label.size = dimensions
	Style.set_font_size(label,font_size); label.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(label); return label

func is_crafting() -> bool: return reservation != null

func select_recipe(id: StringName) -> void:
	if is_crafting() or not Workshop.RECIPES.has(id): return
	selected = id; message.text = ""; refresh()

func refresh() -> void:
	if model == null: return
	object_name.text = Model.DEFINITIONS[selected].name
	preview.texture = Icons.get_icon(selected)
	result_label.text = "Resultado: 1 metro de cuerda" if selected == &"cuerda" else ("Resultado: 1 botella vacía · capacidad 500 ml" if selected == &"botella" else ("Resultado: 1 armadura de hojas" if selected == &"burdock_armor" else "Resultado: 1 herramienta básica · %d usos" % Model.DEFINITIONS[selected].uses))
	if selected == &"flecha": result_label.text = "Resultado: 5 flechas básicas"
	for id in recipe_buttons:
		recipe_buttons[id].self_modulate = Color("d9bf72") if id == selected else Color.WHITE
		recipe_buttons[id].disabled = is_crafting()
	for child in materials.get_children(): materials.remove_child(child); child.queue_free()
	var heading := Label.new(); heading.text = "RESERVADOS / NECESARIOS" if is_crafting() else "DISPONIBLES / NECESARIOS"; Style.set_font_size(heading,12); materials.add_child(heading)
	for id in Workshop.RECIPES[selected]:
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation",10)
		var icon := TextureRect.new(); icon.texture = Icons.get_icon(id); icon.custom_minimum_size = Vector2(65,65)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; icon.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_child(icon)
		var amount := Label.new(); amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL; amount.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var have: int = Workshop.RECIPES[selected][id] if is_crafting() else model.count(id); var need: int = Workshop.RECIPES[selected][id]
		amount.text = "%s: %d / %d%s" % [Model.DEFINITIONS[id].name,have,need," m" if id in [&"cuerda",&"hilo"] else ""]
		Style.set_font_size(amount,13); amount.modulate = Color("c6d5a3") if have >= need else Color("d19c91")
		row.add_child(amount); materials.add_child(row)
	create_button.disabled = is_crafting() or not Workshop.affordable(model,Workshop.RECIPES[selected])
	create_button.tooltip_text = "Faltan materiales." if create_button.disabled and not is_crafting() else "Fabricar en 2 segundos y guardar en la mochila."
	cancel_button.visible = is_crafting(); progress.visible = is_crafting()

func create_selected() -> void:
	if is_crafting(): return
	var trial = model.fork()
	var error := Workshop.craft(trial,selected)
	if not error.is_empty(): message.text = error; return
	reservation = model.fork(); pending = selected
	for material in Workshop.RECIPES[pending]: model.remove_amount(material,Workshop.RECIPES[pending][material])
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
