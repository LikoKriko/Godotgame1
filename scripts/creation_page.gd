extends Control
signal crafted(message: String)
const Workshop = preload("res://scripts/workshop.gd")
const Model = preload("res://scripts/inventory.gd")
const Icons = preload("res://scripts/item_icons.gd")
var model
var selected: StringName = &"pickaxe"
var recipe_buttons: Dictionary = {}
var object_name: Label
var preview: TextureRect
var result_label: Label
var materials: VBoxContainer
var create_button: Button
var message: Label

func configure(bag) -> void:
	model = bag
	size = Vector2(568,488)
	var list := VBoxContainer.new()
	list.position = Vector2.ZERO
	list.size = Vector2(174,440)
	list.add_theme_constant_override("separation",10)
	add_child(list)
	var heading := Label.new()
	heading.text = "RECETAS"
	preload("res://scripts/ui_style.gd").set_font_size(heading,16)
	list.add_child(heading)
	for id in Workshop.RECIPES:
		var button := preload("res://scripts/menu_button.gd").new()
		button.text = Model.DEFINITIONS[id]["name"]
		button.tooltip_text = button.text
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.icon = Icons.get_icon(id)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width",28)
		button.custom_minimum_size = Vector2(174,48)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(select_recipe.bind(id))
		list.add_child(button)
		recipe_buttons[id] = button
	var right := VBoxContainer.new()
	right.position = Vector2(196,0)
	right.size = Vector2(372,488)
	right.add_theme_constant_override("separation",10)
	add_child(right)
	object_name = Label.new()
	preload("res://scripts/ui_style.gd").set_font_size(object_name,20)
	right.add_child(object_name)
	preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(130,110)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(preview)
	result_label = Label.new()
	preload("res://scripts/ui_style.gd").set_font_size(result_label,13)
	right.add_child(result_label)
	materials = VBoxContainer.new()
	materials.add_theme_constant_override("separation",8)
	right.add_child(materials)
	create_button = preload("res://scripts/menu_button.gd").new()
	create_button.text = "Crear"
	create_button.custom_minimum_size.y = 40
	create_button.pressed.connect(create_selected)
	right.add_child(create_button)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preload("res://scripts/ui_style.gd").set_font_size(message,13)
	right.add_child(message)
	refresh()

func select_recipe(id: StringName) -> void:
	if not Workshop.RECIPES.has(id): return
	selected = id
	message.text = ""
	refresh()

func refresh() -> void:
	if model == null: return
	object_name.text = Model.DEFINITIONS[selected]["name"]
	preview.texture = Icons.get_icon(selected)
	result_label.text = "Resultado: 1 metro de cuerda" if selected == &"cuerda" else ("Resultado: 1 botella vacía · capacidad 500 ml" if selected == &"botella" else ("Resultado: 1 armadura de hojas" if selected == &"burdock_armor" else "Resultado: 1 herramienta básica · %d usos" % Model.DEFINITIONS[selected]["uses"]))
	for id in recipe_buttons:
		recipe_buttons[id].self_modulate = Color("d9bf72") if id == selected else Color.WHITE
	for child in materials.get_children():
		materials.remove_child(child)
		child.queue_free()
	var heading := Label.new()
	heading.text = "MATERIALES · DISPONIBLES / NECESARIOS"
	preload("res://scripts/ui_style.gd").set_font_size(heading,12)
	materials.add_child(heading)
	for id in Workshop.RECIPES[selected]:
		var row := HBoxContainer.new()
		var icon := TextureRect.new()
		icon.texture = Icons.get_icon(id)
		icon.custom_minimum_size = Vector2(28,28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var amount := Label.new()
		var have: int = model.count(id)
		var need: int = Workshop.RECIPES[selected][id]
		amount.text = "%s: %d / %d%s" % [Model.DEFINITIONS[id]["name"],have,need," m" if id in [&"cuerda",&"hilo"] else ""]
		preload("res://scripts/ui_style.gd").set_font_size(amount,14)
		amount.modulate = Color("c6d5a3") if have >= need else Color("d19c91")
		row.add_child(amount)
		materials.add_child(row)
	create_button.disabled = not Workshop.affordable(model,Workshop.RECIPES[selected])
	create_button.tooltip_text = "Faltan materiales." if create_button.disabled else "Crear y guardar en la mochila."

func create_selected() -> void:
	var error := Workshop.craft(model,selected)
	refresh()
	message.text = error if not error.is_empty() else "Objeto creado y guardado en la mochila."
	crafted.emit(message.text)
