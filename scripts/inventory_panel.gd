extends Control
signal equipment_changed
const Model = preload("res://scripts/inventory.gd")
const Icons = preload("res://scripts/item_icons.gd")
const LABELS := {&"head": "Cabeza", &"torso": "Torso", &"legs": "Piernas", &"hands": "Manos", &"feet": "Pies"}
const ABBREV := {&"madera": "MAD", &"mineral": "MIN", &"chatarra": "CHA", &"helmet": "CAS", &"suit": "TRA", &"trousers": "PAN", &"boots": "BOT"}
var model
var panel: Panel
var content: Control
var backpack_buttons: Array[Button] = []
var gear_buttons: Dictionary = {}
var details: Label
var status: Label
var chosen := -1
var chosen_gear: StringName = &""
var equip_button: Button
var remove_button: Button

func configure(inventory) -> void:
	model = inventory
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.65)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	panel = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("20232b")
	style.border_color = Color("6c6753")
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	content = Control.new()
	panel.add_child(content)
	label("INVENTARIO", Vector2(14, 12), 19)
	var close := Button.new()
	close.text = "×"
	close.position = Vector2(548, 10)
	close.size = Vector2(38, 30)
	close.pressed.connect(func(): hide())
	content.add_child(close)
	label("PERSONAJE", Vector2(16, 48), 13)
	var portrait := TextureRect.new()
	var portrait_texture: AtlasTexture = preload("res://scripts/survivor_frames.gd").build().get_frame_texture(&"idle_down", 0).duplicate()
	portrait_texture.margin = Rect2()
	portrait.texture = portrait_texture
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = Vector2(68, 110)
	portrait.size = Vector2(108, 118)
	content.add_child(portrait)
	var positions := {&"head": Vector2(98, 65), &"torso": Vector2(18, 123), &"hands": Vector2(18, 185), &"legs": Vector2(184, 185), &"feet": Vector2(98, 235)}
	for slot in Model.EQUIPMENT_SLOTS:
		var button := make_button(positions[slot], Vector2(44, 44))
		button.pressed.connect(select_gear.bind(slot))
		gear_buttons[slot] = button
		label(LABELS[slot], positions[slot] + Vector2(-2, -15), 11)
	details = label("Selecciona un objeto", Vector2(260, 74), 16)
	details.size = Vector2(320, 125)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equip_button = Button.new()
	equip_button.text = "Equipar"
	equip_button.position = Vector2(260, 211)
	equip_button.size = Vector2(130, 34)
	equip_button.pressed.connect(equip_selected)
	content.add_child(equip_button)
	remove_button = Button.new()
	remove_button.text = "Quitar equipo"
	remove_button.position = Vector2(400, 211)
	remove_button.size = Vector2(174, 34)
	remove_button.pressed.connect(remove_selected)
	content.add_child(remove_button)
	label("MOCHILA · 32 ESPACIOS", Vector2(16, 298), 14)
	for i in Model.CAPACITY:
		var button := make_button(Vector2(16 + (i % 8) * 71, 326 + (i / 8) * 52), Vector2(66, 47))
		button.pressed.connect(select_backpack.bind(i))
		backpack_buttons.append(button)
	status = label("I / Esc: cerrar · Clic: seleccionar · Equipar: usar en su espacio", Vector2(16, 555), 12)
	resized.connect(fit_panel)
	fit_panel()
	refresh()
	hide()

func label(text: String, position_value: Vector2, font_size: int) -> Label:
	var node := Label.new()
	node.text = text
	node.position = position_value
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", Color("d9d6c9"))
	content.add_child(node)
	return node

func make_button(point: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.position = point
	button.size = dimensions
	button.add_theme_font_size_override("font_size", 11)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var icon := TextureRect.new()
	icon.name = "ItemIcon"
	icon.position = Vector2(6, 4)
	icon.size = dimensions - Vector2(12, 10)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var count := Label.new()
	count.name = "Amount"
	count.position = Vector2(3, dimensions.y - 17)
	count.size = Vector2(dimensions.x - 7, 14)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.add_theme_font_size_override("font_size", 11)
	count.add_theme_color_override("font_shadow_color", Color.BLACK)
	count.add_theme_constant_override("shadow_offset_x", 1)
	count.add_theme_constant_override("shadow_offset_y", 1)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(count)
	content.add_child(button)
	return button

func fit_panel() -> void:
	if panel == null:
		return
	var viewport_size := get_viewport_rect().size
	var side := minf(sqrt(viewport_size.x * viewport_size.y * 0.6), minf(viewport_size.x, viewport_size.y) * 0.95)
	panel.size = Vector2.ONE * side
	panel.position = (viewport_size - panel.size) / 2
	content.scale = Vector2.ONE * side / 600.0

func show_item(button: Button, item: Dictionary, empty_label: String = "") -> void:
	button.icon = null
	button.text = empty_label
	button.tooltip_text = empty_label
	button.modulate = Color.WHITE
	var icon: TextureRect = button.get_node("ItemIcon")
	var count: Label = button.get_node("Amount")
	icon.texture = null
	count.text = ""
	if item.is_empty():
		return
	var id: StringName = item["id"]
	var definition: Dictionary = Model.DEFINITIONS[id]
	icon.texture = Icons.get_icon(id)
	button.text = "" if icon.texture != null else ABBREV.get(id, "")
	count.text = str(item["uses"]) if item["uses"] >= 0 else (str(item["quantity"]) if item["quantity"] > 1 else "")
	button.tooltip_text = "%s · Básico\n%s" % [definition["name"], definition["purpose"]]
	if item["uses"] >= 0:
		button.tooltip_text += "\nUsos: %d / %d" % [item["uses"], definition["uses"]]
	button.modulate = Color("bd8585") if item["uses"] == 0 else Color.WHITE

func refresh() -> void:
	if model == null:
		return
	for i in Model.CAPACITY:
		show_item(backpack_buttons[i], model.slots[i])
		backpack_buttons[i].self_modulate = Color("d9bf72") if chosen == i else Color.WHITE
	for slot in gear_buttons:
		show_item(gear_buttons[slot], model.equipment[slot], "—")
		gear_buttons[slot].self_modulate = Color("d9bf72") if chosen_gear == slot else Color.WHITE
	var item: Dictionary = {}
	if chosen >= 0:
		item = model.slots[chosen]
	elif chosen_gear != &"":
		item = model.equipment[chosen_gear]
	equip_button.disabled = chosen < 0 or item.is_empty() or Model.DEFINITIONS[item.get("id", &"madera")]["slot"] == &""
	remove_button.disabled = chosen_gear == &"" or item.is_empty()
	details.text = "Selecciona un objeto.\n\nHerramientas y armas: Manos.\nMateriales: Mochila."
	if not item.is_empty():
		var definition: Dictionary = Model.DEFINITIONS[item["id"]]
		details.text = "%s · Básico\n%s" % [definition["name"], definition["purpose"]]
		if item["uses"] >= 0:
			details.text += "\nUsos: %d / %d%s" % [item["uses"], definition["uses"], " · ROTO" if item["uses"] == 0 else ""]
		else:
			details.text += "\nCantidad: %d" % item["quantity"]

func select_backpack(index: int) -> void:
	chosen = index
	chosen_gear = &""
	refresh()

func select_gear(slot: StringName) -> void:
	chosen = -1
	chosen_gear = slot
	refresh()

func equip_selected() -> void:
	if chosen < 0 or model.slots[chosen].is_empty():
		return
	var destination: StringName = Model.DEFINITIONS[model.slots[chosen]["id"]]["slot"]
	if model.equip(chosen, destination):
		status.text = "Objeto equipado."
		equipment_changed.emit()
	refresh()

func remove_selected() -> void:
	if model.unequip(chosen_gear):
		status.text = "Equipo guardado en la mochila."
		equipment_changed.emit()
	else:
		status.text = "La mochila está llena."
	refresh()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_I, KEY_ESCAPE]:
		hide()
		get_viewport().set_input_as_handled()
