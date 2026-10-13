extends Control
const Model = preload("res://scripts/inventory.gd")
const Icons = preload("res://scripts/item_icons.gd")
var game
var panel: Panel
var entries: VBoxContainer
var search: LineEdit
var quantity: SpinBox
var selected: StringName = &""
var selected_name: Label
var status: Label
var buttons: Dictionary = {}

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
	entries = VBoxContainer.new(); entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries.add_theme_constant_override("separation",5); scroll.add_child(entries)
	for id in Model.DEFINITIONS:
		if not Model.DEFINITIONS[id].get("catalogue",true): continue
		var button := preload("res://scripts/menu_button.gd").new()
		button.text = Model.DEFINITIONS[id].name
		button.icon = Icons.get_icon(id); button.expand_icon = true
		button.add_theme_constant_override("icon_max_width",36)
		button.custom_minimum_size.y = 44; button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(select_item.bind(id)); entries.add_child(button); buttons[id] = button
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
	show(); fit(); status.text = "Los objetos se añaden sin gastar materiales."
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
