extends Control
signal equipment_changed
signal consume_requested(index: int)
const Model = preload("res://scripts/inventory.gd")
const Icons = preload("res://scripts/item_icons.gd")
const Workshop = preload("res://scripts/workshop.gd")
const LABELS := {&"head": "Cabeza", &"torso": "Torso", &"legs": "Piernas", &"hands": "Manos", &"feet": "Pies"}
const ABBREV := {&"madera": "MAD", &"mineral": "MIN", &"piedra": "PIE", &"palo": "PAL", &"cuerda": "CUE", &"chatarra": "CHA", &"fibra": "FIB", &"helmet": "CAS", &"suit": "TRA", &"trousers": "PAN", &"boots": "BOT"}
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
var repair_button: Button
var craft_button: Button
var workshop_dialog: Control
var workshop_body: HBoxContainer
var workshop_title: Label
var workshop_item: Label
var workshop_materials: Label
var workshop_message: Label
var workshop_confirm: Button
var workshop_mode := ""
var repair_uid := -1
var craft_id: StringName = &"pickaxe"

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
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.size = Vector2(600,600)
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
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	remove_button.text = "Desequipar"
	remove_button.position = Vector2(400, 211)
	remove_button.size = Vector2(174, 34)
	remove_button.pressed.connect(remove_selected)
	content.add_child(remove_button)
	repair_button = Button.new()
	repair_button.text = "Reparar"
	repair_button.position = Vector2(260,254)
	repair_button.size = Vector2(130,34)
	repair_button.pressed.connect(open_repair)
	content.add_child(repair_button)
	craft_button = Button.new()
	craft_button.text = "Fabricar"
	craft_button.position = Vector2(400,254)
	craft_button.size = Vector2(174,34)
	craft_button.pressed.connect(open_crafting)
	content.add_child(craft_button)
	label("MOCHILA · 32 ESPACIOS", Vector2(16, 298), 14)
	for i in Model.CAPACITY:
		var button := make_button(Vector2(16 + (i % 8) * 71, 326 + (i / 8) * 52), Vector2(66, 47))
		button.pressed.connect(select_backpack.bind(i))
		backpack_buttons.append(button)
	status = label("I / Esc: cerrar · Clic: seleccionar · Equipar: usar en su espacio", Vector2(16, 555), 12)
	resized.connect(fit_panel)
	fit_panel()
	refresh()
	visibility_changed.connect(func():
		if not visible:
			close_workshop()
	)
	hide()

func label(text: String, position_value: Vector2, font_size: int) -> Label:
	var node := Label.new()
	node.text = text
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	count.text = str(item["quantity"])
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
	var consumable: bool = not item.is_empty() and (Model.DEFINITIONS[item["id"]].has("kcal") or Model.DEFINITIONS[item["id"]].has("water_ml"))
	equip_button.text = ("Beber" if item.get("id",&"") == &"water" else "Comer") if consumable else "Equipar"
	equip_button.disabled = chosen < 0 or item.is_empty() or (not consumable and Model.DEFINITIONS[item.get("id", &"madera")]["slot"] == &"")
	remove_button.disabled = chosen_gear == &"" or item.is_empty()
	repair_button.disabled = item.is_empty() or not Workshop.REPAIRS.has(item.get("id",&""))
	details.text = "Selecciona un objeto.\n\nHerramientas y armas: Manos.\nMateriales: Mochila."
	if not item.is_empty():
		var definition: Dictionary = Model.DEFINITIONS[item["id"]]
		details.text = "%s · Básico\n%s" % [definition["name"], definition["purpose"]]
		if item["uses"] >= 0:
			details.text += "\n%s: %d / %d%s" % ["Usos" if definition["slot"] == &"hands" else "Durabilidad",item["uses"], definition["uses"], " · ROTO" if item["uses"] == 0 else ""]
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
	var definition: Dictionary = Model.DEFINITIONS[model.slots[chosen]["id"]]
	if definition.has("kcal") or definition.has("water_ml"):
		consume_requested.emit(chosen)
		refresh()
		return
	var destination: StringName = definition["slot"]
	if model.equip(chosen, destination):
		status.text = "Objeto equipado."
		chosen = -1
		chosen_gear = destination
		equipment_changed.emit()
	refresh()

func remove_selected() -> void:
	var uid: int = model.equipment.get(chosen_gear,{}).get("uid",-1)
	if model.unequip(chosen_gear):
		status.text = "Equipo guardado en la mochila."
		chosen_gear = &""
		for i in Model.CAPACITY:
			if model.slots[i].get("uid",-1) == uid:
				chosen = i
				break
		equipment_changed.emit()
	else:
		status.text = "La mochila está llena."
	refresh()

func selected_item() -> Dictionary:
	if chosen >= 0:
		return model.slots[chosen]
	return model.equipment.get(chosen_gear,{})

func create_workshop() -> void:
	close_workshop()
	workshop_dialog = Control.new()
	workshop_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	workshop_dialog.z_index = 5
	add_child(workshop_dialog)
	var veil := ColorRect.new()
	veil.color = Color(0,0,0,0.78)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	workshop_dialog.add_child(veil)
	var window := PanelContainer.new()
	window.name = "Window"
	workshop_dialog.add_child(window)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,24)
	window.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",22)
	margin.add_child(box)
	workshop_title = Label.new()
	workshop_title.add_theme_font_size_override("font_size",28)
	box.add_child(workshop_title)
	workshop_body = HBoxContainer.new()
	workshop_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workshop_body.add_theme_constant_override("separation",40)
	box.add_child(workshop_body)
	var left := VBoxContainer.new()
	left.name = "Object"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workshop_body.add_child(left)
	workshop_item = Label.new()
	workshop_item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	workshop_item.add_theme_font_size_override("font_size",22)
	left.add_child(workshop_item)
	workshop_materials = Label.new()
	workshop_materials.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	workshop_materials.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workshop_materials.add_theme_font_size_override("font_size",22)
	workshop_body.add_child(workshop_materials)
	workshop_message = Label.new()
	workshop_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(workshop_message)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(row)
	var back := Button.new()
	back.text = "Volver"
	back.pressed.connect(close_workshop)
	row.add_child(back)
	workshop_confirm = Button.new()
	workshop_confirm.custom_minimum_size = Vector2(160,44)
	workshop_confirm.pressed.connect(confirm_workshop)
	row.add_child(workshop_confirm)
	fit_workshop()
	workshop_dialog.resized.connect(fit_workshop)

func fit_workshop() -> void:
	if not is_instance_valid(workshop_dialog):
		return
	var window: PanelContainer = workshop_dialog.get_node("Window")
	var screen := get_viewport_rect().size
	window.size = Vector2(minf(950,screen.x*0.9),minf(500,screen.y*0.85))
	window.position = (screen-window.size)/2

func open_repair() -> void:
	var item := selected_item()
	if item.is_empty() or not Workshop.REPAIRS.has(item["id"]):
		return
	repair_uid = item["uid"]
	create_workshop()
	workshop_mode = "repair"
	workshop_title.text = "REPARAR EQUIPO"
	workshop_confirm.text = "Reparar"
	update_workshop()

func open_crafting() -> void:
	create_workshop()
	workshop_mode = "craft"
	workshop_title.text = "FABRICACIÓN"
	workshop_confirm.text = "Fabricar"
	var selector := OptionButton.new()
	for id in Workshop.RECIPES:
		selector.add_item(Model.DEFINITIONS[id]["name"]+(" · 1 metro" if id == &"cuerda" else " · Básico"))
	selector.select(Workshop.RECIPES.keys().find(craft_id))
	selector.item_selected.connect(func(index): craft_id = Workshop.RECIPES.keys()[index]; update_workshop())
	workshop_body.get_node("Object").add_child(selector)
	update_workshop()

func update_workshop() -> void:
	var item: Dictionary = model.item_by_uid(repair_uid) if workshop_mode == "repair" else {}
	var id: StringName = item.get("id",&"") if workshop_mode == "repair" else craft_id
	var valid: bool = id != &""
	var cost: Dictionary = Workshop.REPAIRS.get(id,{}) if workshop_mode == "repair" else Workshop.RECIPES[id]
	workshop_item.text = Model.DEFINITIONS[id]["name"] if valid else "Objeto no disponible"
	if workshop_mode == "repair" and valid:
		workshop_item.text += "\n\nEstado: %d / %d\nTras reparar: %d / %d" % [item["uses"],Model.DEFINITIONS[id]["uses"],Model.DEFINITIONS[id]["uses"],Model.DEFINITIONS[id]["uses"]]
	elif valid:
		workshop_item.text += "\n\nResultado: 1 metro" if id == &"cuerda" else "\n\nResultado: 1 herramienta básica\nUsos: %d" % Model.DEFINITIONS[id]["uses"]
	workshop_materials.text = "MATERIALES NECESARIOS\n"
	for material in cost:
		var unit := " m" if material == &"cuerda" else ""
		workshop_materials.text += "\n%s: %d%s\nDisponible: %d%s\n" % [Model.DEFINITIONS[material]["name"],cost[material],unit,model.count(material),unit]
	var damaged: bool = workshop_mode != "repair" or (valid and item["uses"] < Model.DEFINITIONS[id]["uses"])
	workshop_confirm.disabled = not valid or not damaged or not Workshop.affordable(model,cost)
	workshop_message.text = "" if not workshop_confirm.disabled else ("El objeto está en perfecto estado." if valid and not damaged else "Faltan materiales o el objeto no está disponible.")
	var existing := workshop_body.get_node("Object").get_node_or_null("Preview")
	if existing != null:
		existing.get_parent().remove_child(existing)
		existing.queue_free()
	var icon := TextureRect.new()
	icon.name = "Preview"
	icon.texture = Icons.get_icon(id)
	icon.custom_minimum_size = Vector2(140,140)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	workshop_body.get_node("Object").add_child(icon)

func confirm_workshop() -> void:
	var result := Workshop.repair(model,repair_uid) if workshop_mode == "repair" else Workshop.craft(model,craft_id)
	var text := result if result != "" else ("Objeto reparado." if workshop_mode == "repair" else "Objeto fabricado y guardado en la mochila.")
	refresh()
	update_workshop()
	workshop_message.text = text
	status.text = text
	equipment_changed.emit()

func close_workshop() -> void:
	if is_instance_valid(workshop_dialog):
		remove_child(workshop_dialog)
		workshop_dialog.queue_free()
	workshop_dialog = null

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_I, KEY_ESCAPE]:
		if is_instance_valid(workshop_dialog):
			close_workshop()
		else:
			hide()
		get_viewport().set_input_as_handled()
