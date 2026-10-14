extends Control
const Model = preload("res://scripts/inventory.gd")
const Icons = preload("res://scripts/item_icons.gd")
var game
var panel: Panel
var entries: GridContainer
var search: LineEdit
var quantity: SpinBox
var selected: StringName = &""
var selected_name: Label
var status: Label
var buttons: Dictionary = {}
var spawn_button: Button

func configure(owner_game) -> void:
	game = owner_game
	theme = preload("res://scripts/ui_style.gd").theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new(); veil.color = Color(0,0,0,0.7)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(veil)
	panel = Panel.new(); add_child(panel)
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 24; layout.offset_right = -24; layout.offset_top = 20; layout.offset_bottom = -20
	layout.add_theme_constant_override("separation",14); panel.add_child(layout)
	var top := HBoxContainer.new(); layout.add_child(top)
	var heading := Label.new(); heading.text = "OBJETOS · MODO DE PRUEBA"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(heading)
	var close := preload("res://scripts/menu_button.gd").new()
	close.text = "Cerrar"; close.pressed.connect(hide); top.add_child(close)
	search = LineEdit.new(); search.placeholder_text = "Buscar un objeto..."
	search.text_changed.connect(filter_entries); layout.add_child(search)
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	entries = GridContainer.new(); entries.columns = 4; entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries.add_theme_constant_override("h_separation",12); entries.add_theme_constant_override("v_separation",12); scroll.add_child(entries)
	for id in Model.DEFINITIONS:
		if not Model.DEFINITIONS[id].get("catalogue",true): continue
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(140,126)
		button.tooltip_text = Model.DEFINITIONS[id].name
		var artwork := TextureRect.new(); artwork.name = "Artwork"
		artwork.texture = Icons.get_icon(id); artwork.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		artwork.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		artwork.position = Vector2(-36,10); artwork.size = Vector2(72,72)
		artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE; button.add_child(artwork)
		var caption := Label.new(); caption.name = "Caption"; caption.text = Model.DEFINITIONS[id].name
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		caption.offset_left = 8; caption.offset_right = -8; caption.offset_top = 86; caption.offset_bottom = -8
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preload("res://scripts/ui_style.gd").set_font_size(caption,16); button.add_child(caption)
		button.pressed.connect(select_item.bind(id)); entries.add_child(button); buttons[id] = button
	var debug := HBoxContainer.new(); debug.add_theme_constant_override("separation",18); layout.add_child(debug)
	var level_button := preload("res://scripts/menu_button.gd").new(); level_button.text = "+1 nivel"
	level_button.pressed.connect(add_level); debug.add_child(level_button)
	spawn_button = preload("res://scripts/menu_button.gd").new(); spawn_button.text = "Añadir enemigo joven"
	spawn_button.pressed.connect(spawn_enemy); debug.add_child(spawn_button)
	var bottom := HBoxContainer.new(); layout.add_child(bottom)
	selected_name = Label.new(); selected_name.text = "Selecciona un objeto"
	selected_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bottom.add_child(selected_name)
	quantity = SpinBox.new(); quantity.min_value = 1; quantity.max_value = 999; quantity.step = 1; quantity.value = 1
	bottom.add_child(quantity)
	var add := preload("res://scripts/menu_button.gd").new()
	add.text = "Añadir a la mochila"; add.pressed.connect(add_selected); bottom.add_child(add)
	status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 42; layout.add_child(status)
	get_viewport().size_changed.connect(fit); fit(); hide()

func fit() -> void:
	var screen := get_viewport_rect().size
	panel.size = Vector2(minf(900,screen.x*0.8),minf(740,screen.y*0.84))
	panel.position = (screen-panel.size)/2

func open_catalog() -> void:
	show(); fit(); status.text = ""
	spawn_button.disabled = game.hut != null and game.hut.inside
	spawn_button.tooltip_text = "Sal al exterior para añadir un enemigo." if spawn_button.disabled else "Añadir un enemigo joven cerca del personaje."
	search.grab_focus()

func filter_entries(query: String) -> void:
	var text := query.strip_edges().to_lower()
	for id in buttons:
		buttons[id].visible = text.is_empty() or String(id).to_lower().contains(text) or Model.DEFINITIONS[id].name.to_lower().contains(text)

func select_item(id: StringName) -> void:
	selected = id; selected_name.text = Model.DEFINITIONS[id].name

func add_selected() -> bool:
	if not Model.DEFINITIONS.has(selected) or not Model.DEFINITIONS[selected].get("catalogue",true):
		status.text = "Selecciona un objeto."; return false
	var amount := int(quantity.value)
	if not game.bag.add(selected,amount):
		status.text = "No hay espacio suficiente; no se ha añadido ningún objeto."; return false
	status.text = "%s × %d añadido a la mochila." % [Model.DEFINITIONS[selected].name,amount]
	game.inventory_panel.refresh(); game.update_hud(); return true

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE or (event.keycode == KEY_K and not search.has_focus()):
		hide(); get_viewport().set_input_as_handled()

func add_level() -> void:
	game.level += 1; game.skill_points += 1
	game.update_hud(); game.inventory_panel.refresh()
	status.text = "Nivel %d · +1 punto de mejora." % game.level

func spawn_enemy() -> void:
	status.text = "Enemigo joven añadido cerca del personaje." if game.enemies.spawn_debug_enemy() else "No hay una posición libre para añadir al enemigo."
