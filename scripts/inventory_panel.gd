extends Control
signal equipment_changed
signal consume_requested(index: int)
const Model = preload("res://scripts/inventory.gd")
const Icons = preload("res://scripts/item_icons.gd")
const Workshop = preload("res://scripts/workshop.gd")
const LABELS := {&"head": "Cabeza", &"torso": "Torso", &"legs": "Piernas", &"hands": "Guantes", &"feet": "Pies"}
const ABBREV := {&"madera": "MAD", &"mineral": "MIN", &"piedra": "PIE", &"palo": "PAL", &"cuerda": "CUE", &"chatarra": "CHA", &"fibra": "FIB", &"helmet": "CAS", &"suit": "TRA", &"trousers": "PAN", &"boots": "BOT"}
var model
var game
var portrait: TextureRect
var portrait_key := ""
var panel_heading: Label
var navigation
var inventory_page: Control
var creation_page: Control
var sections: Array[Control] = []
var panel: Panel
var content: Control
var backpack_buttons: Array[Button] = []
var gear_buttons: Dictionary = {}
var details: Label
var status: Label
var chosen := -1
var chosen_gear: StringName = &""
var equip_button: Button
var repair_button: Button
var craft_button: Button
var workshop_dialog: Control
var workshop_body: HBoxContainer
var workshop_title: Label
var workshop_item: Label
var workshop_materials: Label
var workshop_message: Label
var workshop_confirm: Button
var repair_uid := -1
var chosen_quick := -1
var improve_button: Button
var dismantle_button: Button
var capacity_label: Label
const Art = preload("res://scripts/inventory_art.gd")

func configure(inventory, owner_game = null) -> void:
	game = owner_game
	theme = preload("res://scripts/ui_style.gd").theme()
	model = inventory
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new(); veil.color = Color(0,0,0,0.65)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(veil)
	panel = Panel.new(); panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new()); add_child(panel)
	content = Control.new(); content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.size = Art.SIZE; panel.add_child(content)
	Art.patch(content,Rect2(Vector2.ZERO,Art.SIZE),Art.BOUNDS)
	# Replace baked text with live buttons, retaining the original rim and texture.
	Art.patch(content,Rect2(76,29,1232,87))
	panel_heading = Label.new(); panel_heading.hide(); content.add_child(panel_heading)
	inventory_page = Control.new(); inventory_page.size = Art.SIZE
	inventory_page.mouse_filter = Control.MOUSE_FILTER_IGNORE; content.add_child(inventory_page)
	var root_content := content
	content = inventory_page
	Art.patch(content,Rect2(61,647,852,278))
	Art.patch(content,Rect2(790,604,105,42))
	capacity_label = label("",Vector2(798,609),24)
	capacity_label.size = Vector2(114,39); capacity_label.clip_text = true
	capacity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var positions := {&"head":Vector2(139,184),&"hands":Vector2(139,329),&"feet":Vector2(139,470),&"torso":Vector2(527,184),&"legs":Vector2(527,364)}
	for slot in Model.EQUIPMENT_SLOTS:
		var button := make_button(positions[slot],Vector2(116,101))
		button.pressed.connect(select_gear.bind(slot)); button.kind = &"gear"; button.slot = slot
		gear_buttons[slot] = button
	portrait = TextureRect.new(); portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = Vector2(299,169); portrait.size = Vector2(166,397); content.add_child(portrait)
	details = label("Selecciona un objeto.",Vector2(970,664),18)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; details.size = Vector2(310,205)
	# The two undefined actions are deliberately disabled. Repair remains live.
	for rect in [Rect2(831,190,415,108),Rect2(831,303,415,108),Rect2(831,416,415,108)]: Art.patch(content,rect,Art.ACTION_PAPER)
	improve_button = action_button("MEJORAR",Vector2(834,194)); improve_button.disabled = true
	improve_button.icon = Art.crop(Rect2(924,278,52,47))
	improve_button.tooltip_text = "Las mejoras de objetos aún no están disponibles."
	repair_button = action_button("REPARAR",Vector2(834,307)); repair_button.pressed.connect(open_repair)
	repair_button.icon = Art.crop(Rect2(924,391,52,49))
	dismantle_button = action_button("DESMONTAR",Vector2(834,420)); dismantle_button.disabled = true
	dismantle_button.icon = Art.crop(Rect2(924,503,52,49))
	dismantle_button.tooltip_text = "El desmontaje aún no está disponible."
	# This action is exclusively for consumables; equipment moves by dragging.
	equip_button = action_button("",Vector2(970,872)); equip_button.size = Vector2(309,46)
	equip_button.pressed.connect(equip_selected)
	for i in Model.CAPACITY:
		var button := make_button(Vector2(194+(i%8)*72,648+(i/8)*72),Vector2(64,64))
		button.pressed.connect(select_backpack.bind(i)); button.kind = &"bag"; button.slot = i
		backpack_buttons.append(button)
	status = label("Arrastra para mover · Shift + clic: transferir",Vector2(834,543),14)
	status.size = Vector2(409,28); status.clip_text = true
	content = root_content
	build_sections()
	var close := preload("res://scripts/menu_button.gd").new()
	close.text = "×"; close.position = Vector2(1325,7); close.size = Vector2(36,36)
	preload("res://scripts/ui_style.gd").set_font_size(close,24)
	close.pressed.connect(hide); content.add_child(close)
	resized.connect(fit_panel); fit_panel(); refresh()
	visibility_changed.connect(func():
		if not visible: close_workshop()
	)
	hide()

func action_button(text: String, point: Vector2) -> Button:
	var button := preload("res://scripts/menu_button.gd").new()
	button.text = text; button.position = point; button.size = Vector2(409,86)
	button.expand_icon = true; button.add_theme_constant_override("icon_max_width",42)
	preload("res://scripts/ui_style.gd").set_font_size(button,34)
	Art.skin(button,Art.ACTION); content.add_child(button); return button

func label(text: String, position_value: Vector2, font_size: int) -> Label:
	var node := Label.new()
	node.text = text
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = position_value
	preload("res://scripts/ui_style.gd").set_font_size(node,font_size)
	node.add_theme_color_override("font_color", Color("d9d6c9"))
	content.add_child(node)
	return node

func make_button(point: Vector2, dimensions: Vector2) -> Button:
	var button := preload("res://scripts/item_slot.gd").new()
	button.game = game
	button.position = point
	button.size = dimensions
	preload("res://scripts/ui_style.gd").set_font_size(button,14)
	Art.skin(button,Art.SLOT,true)
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
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_child(icon)
	var count := Label.new()
	count.name = "Amount"
	count.position = Vector2(3, dimensions.y - 23)
	count.size = Vector2(dimensions.x - 7, 22)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	preload("res://scripts/ui_style.gd").set_font_size(count,14)
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
	var factor := minf(sqrt(viewport_size.x*viewport_size.y*0.6/(Art.SIZE.x*Art.SIZE.y)),minf(viewport_size.x*0.95/Art.SIZE.x,viewport_size.y*0.84/Art.SIZE.y))
	panel.size = Art.SIZE*factor
	panel.position = (viewport_size-panel.size)/2
	content.scale = Vector2.ONE*factor

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
		if button.kind == &"gear": icon.texture = Art.crop(Art.GEAR_ICONS[button.slot])
		return
	var id: StringName = item["id"]
	var definition: Dictionary = Model.DEFINITIONS[id]
	icon.texture = Icons.for_item(item)
	if icon.texture == null and button.kind == &"gear": icon.texture = Art.crop(Art.GEAR_ICONS[button.slot])
	button.text = "" if icon.texture != null else ABBREV.get(id, "")
	count.text = str(item["quantity"])
	button.tooltip_text = "%s · Básico\n%s" % [definition["name"], definition["purpose"]]
	if definition.has("damage"): button.tooltip_text += "\nDaño base: %d" % definition.damage
	if id == &"botella": button.tooltip_text += "\nContenido: %d / 500 ml" % item.get("water_ml",0)
	if item["uses"] >= 0:
		button.tooltip_text += "\nUsos: %d / %d" % [item["uses"], definition["uses"]]
	button.modulate = Color("bd8585") if item["uses"] == 0 else Color.WHITE

func refresh() -> void:
	if model == null:
		return
	var appearance := "burdock_armor__bare" if model.equipment[&"torso"].get("id") == &"burdock_armor" else "bare"
	if appearance != portrait_key:
		portrait_key = appearance
		var image := AtlasTexture.new()
		image.atlas = load("res://assets/characters/complete/"+appearance+"_idle.png")
		var cell := Rect2i(0,4*192,192,192)
		var used := image.atlas.get_image().get_region(cell).get_used_rect()
		image.region = Rect2(used.position+cell.position,used.size)
		portrait.texture = image
	for i in Model.CAPACITY:
		show_item(backpack_buttons[i], model.slots[i])
		backpack_buttons[i].self_modulate = Color("d9bf72") if chosen == i else Color.WHITE
	for slot in gear_buttons:
		show_item(gear_buttons[slot], model.equipment[slot])
		gear_buttons[slot].self_modulate = Color("d9bf72") if chosen_gear == slot else Color.WHITE
	var item: Dictionary = {}
	if chosen >= 0:
		item = model.slots[chosen]
	elif chosen_gear != &"":
		item = model.equipment[chosen_gear]
	elif chosen_quick >= 0:
		item = model.quick_slots[chosen_quick]
	var consumable: bool = not item.is_empty() and (item.id == &"botella" or Model.DEFINITIONS[item["id"]].has("kcal") or Model.DEFINITIONS[item["id"]].has("water_ml"))
	equip_button.text = "Beber" if item.get("id",&"") in [&"water",&"botella"] else "Comer"
	equip_button.visible = consumable
	equip_button.disabled = not consumable
	capacity_label.text = "%d / 32" % model.slots.filter(func(slot): return not slot.is_empty()).size()
	repair_button.disabled = item.is_empty() or not Workshop.REPAIRS.has(item.get("id",&""))
	details.text = "Selecciona un objeto.\n\nManos: solo guantes.\nHerramientas: barra rápida o en uso.\nMateriales: Mochila."
	if not item.is_empty():
		var definition: Dictionary = Model.DEFINITIONS[item["id"]]
		details.text = "%s · Básico\n%s" % [definition["name"], definition["purpose"]]
		if item["uses"] >= 0:
			details.text += "\n%s: %d / %d%s" % ["Usos" if definition["slot"] == &"tool" else "Durabilidad",item["uses"], definition["uses"], " · ROTO" if item["uses"] == 0 else ""]
		else:
			details.text += "\nCantidad: %d" % item["quantity"]
		if definition.has("damage"): details.text += "\nDaño base: %d" % definition.damage
		if item.id == &"botella": details.text += "\nContenido: %d / 500 ml" % item.get("water_ml",0)
	if creation_page != null: creation_page.refresh()

func select_backpack(index: int) -> void:
	chosen = index
	chosen_quick = -1
	chosen_gear = &""
	refresh()

func select_gear(slot: StringName) -> void:
	chosen = -1
	chosen_quick = -1
	chosen_gear = slot
	refresh()

func select_quick(index: int) -> void:
	chosen = -1; chosen_gear = &""; chosen_quick = index
	refresh()

func equip_selected() -> void:
	var item := selected_item()
	if item.is_empty() or (chosen < 0 and chosen_quick < 0): return
	var definition: Dictionary = Model.DEFINITIONS[item.id]
	if item.id == &"botella" or definition.has("kcal") or definition.has("water_ml"):
		if chosen_quick >= 0: game.consume_item(chosen_quick,true)
		else: consume_requested.emit(chosen)
		refresh(); return
	var destination: StringName = definition.slot
	var success: bool
	if destination == &"tool":
		success = model.activate_quick(chosen_quick) if chosen_quick >= 0 else model.equip(chosen,destination)
	else:
		success = model.move_item(&"quick",chosen_quick,&"gear",destination) if chosen_quick >= 0 else model.equip(chosen,destination)
	if success:
		status.text = "Objeto guardado." if model.held_id() == &"" and destination == &"tool" else "Objeto equipado."
		if destination == &"tool":
			var location: Dictionary = model.location(item.uid)
			chosen = -1; chosen_gear = &""
			chosen_quick = location.index if location.get("kind") == &"quick" else -1
		else:
			chosen = -1; chosen_quick = -1; chosen_gear = destination
		equipment_changed.emit()
	elif destination == &"tool":
		status.text = "Libera un espacio de la barra rápida para equipar el arma."
	refresh()

func selected_item() -> Dictionary:
	if chosen >= 0:
		return model.slots[chosen]
	if chosen_quick >= 0: return model.quick_slots[chosen_quick]
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
	preload("res://scripts/ui_style.gd").set_font_size(workshop_title,28)
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
	preload("res://scripts/ui_style.gd").set_font_size(workshop_item,22)
	left.add_child(workshop_item)
	workshop_materials = Label.new()
	workshop_materials.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	workshop_materials.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preload("res://scripts/ui_style.gd").set_font_size(workshop_materials,22)
	workshop_body.add_child(workshop_materials)
	workshop_message = Label.new()
	workshop_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(workshop_message)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(row)
	var back := preload("res://scripts/menu_button.gd").new()
	back.text = "Volver"
	back.pressed.connect(close_workshop)
	row.add_child(back)
	workshop_confirm = preload("res://scripts/menu_button.gd").new()
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
	workshop_title.text = "REPARAR EQUIPO"
	workshop_confirm.text = "Reparar"
	update_workshop()

func open_crafting() -> void:
	open_section(1)

func update_workshop() -> void:
	var item: Dictionary = model.item_by_uid(repair_uid)
	var id: StringName = item.get("id",&"")
	var valid: bool = id != &""
	var cost: Dictionary = Workshop.REPAIRS.get(id,{})
	workshop_item.text = Model.DEFINITIONS[id]["name"] if valid else "Objeto no disponible"
	if valid:
		workshop_item.text += "\n\nEstado: %d / %d\nTras reparar: %d / %d" % [item["uses"],Model.DEFINITIONS[id]["uses"],Model.DEFINITIONS[id]["uses"],Model.DEFINITIONS[id]["uses"]]
	workshop_materials.text = "MATERIALES NECESARIOS\n"
	for material in cost:
		var unit := " m" if material in [&"cuerda",&"hilo"] else ""
		workshop_materials.text += "\n%s: %d%s\nDisponible: %d%s\n" % [Model.DEFINITIONS[material]["name"],cost[material],unit,model.count(material),unit]
	var damaged: bool = valid and item["uses"] < Model.DEFINITIONS[id]["uses"]
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
	var result := Workshop.repair(model,repair_uid)
	var text := result if result != "" else "Objeto reparado."
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
		elif event.keycode == KEY_I and navigation.current_tab != 0:
			open_section(0)
		else:
			hide()
		get_viewport().set_input_as_handled()

func build_sections() -> void:
	sections.append(inventory_page)
	creation_page = preload("res://scripts/creation_page.gd").new()
	content.add_child(creation_page); creation_page.configure(model)
	creation_page.crafted.connect(func(text): status.text = text; refresh(); equipment_changed.emit())
	sections.append(creation_page)
	for is_ability in [true,false]:
		var page := preload("res://scripts/trait_page.gd").new()
		content.add_child(page); page.configure(game,is_ability); sections.append(page)
	for page in sections.slice(1):
		page.position = Vector2(245,147); page.scale = Vector2.ONE*1.55
		var background := Art.patch(page,Rect2(-112,-8,792,505))
		page.move_child(background,0)
	var map_page := Control.new(); map_page.size = Art.SIZE; map_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(map_page); Art.patch(map_page,Rect2(69,132,1232,802))
	var map_view = preload("res://scripts/world_map.gd").TerrainView.new()
	map_view.name = "Terrain"; map_view.game = game; map_view.position = Vector2(99,148)
	map_view.size = Vector2(1170,780); map_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_view.mouse_filter = Control.MOUSE_FILTER_IGNORE; map_page.add_child(map_view); sections.append(map_page)
	navigation = preload("res://scripts/inventory_tabs.gd").new()
	navigation.position = Vector2(82,32); content.add_child(navigation); navigation.configure()
	craft_button = navigation.buttons[1]
	navigation.tab_changed.connect(select_section); select_section(0)

func select_section(index: int) -> void:
	if index < 0 or index >= sections.size(): return
	panel_heading.text = ["INVENTARIO","CREACIÓN","HABILIDADES","PERKS","MAPA"][index]
	close_workshop()
	for i in sections.size(): sections[i].visible = i == index
	if index == 1: creation_page.refresh()
	elif index in [2,3]: sections[index].refresh()
	elif index == 4: sections[4].get_node("Terrain").refresh()

func open_section(index: int) -> void:
	refresh(); navigation.current_tab = index; select_section(index); show()
