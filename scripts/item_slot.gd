extends "res://scripts/menu_button.gd"
var game
var kind: StringName = &"bag"
var slot
func source() -> Dictionary:
	if game == null: return {}
	var item: Dictionary = game.bag.at(kind,slot)
	return game.bag.location(item.get("uid",-1))
func _get_drag_data(_point: Vector2):
	if crafting_locked(): return null
	var location := source()
	if location.is_empty(): return null
	var item: Dictionary = game.bag.at(location.kind,location.index)
	var preview := TextureRect.new()
	preview.texture = preload("res://scripts/item_icons.gd").for_item(item)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(48,48)
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_drag_preview(preview)
	return {"type":&"day_zero_item","bag":game.bag.get_instance_id(),"uid":item.uid}
func _can_drop_data(_point: Vector2, data) -> bool:
	if crafting_locked(): return false
	if game == null or not data is Dictionary or data.get("type") != &"day_zero_item" or data.get("bag") != game.bag.get_instance_id(): return false
	var location: Dictionary = game.bag.location(data.get("uid",-1))
	return not location.is_empty() and game.bag.can_move(location.kind,location.index,kind,slot)
func _drop_data(point: Vector2, data) -> void:
	if not _can_drop_data(point,data): return
	var location: Dictionary = game.bag.location(data.uid)
	game.cancel_work()
	game.bag.move_item(location.kind,location.index,kind,slot)
	changed()
func changed() -> void:
	game.inventory_panel.refresh()
	game.inventory_panel.equipment_changed.emit()
	game.styled_hud.refresh()
func _gui_input(event: InputEvent) -> void:
	if crafting_locked(): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.shift_pressed:
		var location := source()
		if not location.is_empty():
			game.cancel_work()
			if not game.bag.shift_transfer(location.kind,location.index): game.inventory_panel.status.text = "No hay un espacio disponible."
			changed()
		accept_event()

func crafting_locked() -> bool:
	return game != null and game.inventory_panel != null and game.inventory_panel.creation_page != null and game.inventory_panel.creation_page.is_crafting()
