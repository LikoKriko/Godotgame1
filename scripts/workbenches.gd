extends Node2D
const Art = preload("res://scripts/workbench_art.gd")
const PLACE_SECONDS := 3.0
const REACH := 96.0
var game
var window: Control
var tables: Array[Dictionary] = []
var remaining := 0.0
var pending_uid := -1
var pending_point := Vector2.ZERO
func configure(owner_game, canvas: CanvasLayer) -> void:
	game = owner_game; texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	window = preload("res://scripts/workbench_window.gd").new(); canvas.add_child(window); window.configure(game)
func graphic_rect(point: Vector2) -> Rect2: return Rect2(point-Vector2(Art.dimensions().x/2,Art.HEIGHT),Art.dimensions())
static func collider(point: Vector2) -> Rect2: return Rect2(point-Vector2(Art.dimensions().x*0.4,Art.HEIGHT*0.3),Vector2(Art.dimensions().x*0.8,Art.HEIGHT*0.3))
func placing() -> bool: return pending_uid > 0
func cancel_placement() -> void: remaining = 0; pending_uid = -1; queue_redraw()
func reset() -> void:
	cancel_placement(); window.hide()
	for table in tables:
		game.world.building_collisions.erase(table.collider)
		if is_instance_valid(table.sprite): table.sprite.queue_free()
	tables.clear()
func can_place(point: Vector2) -> bool:
	if not point.is_finite() or game.hut.inside or game.progression.health <= 0: return false
	if game.player.distance_to(point) > REACH: return false
	var area := collider(point)
	if not game.world.bounds.grow(-16).encloses(area): return false
	if area.grow(game.world.PLAYER_RADIUS).has_point(game.player): return false
	for rect in game.world.building_collisions:
		if area.grow(4).intersects(rect): return false
	for rect in game.world.prop_collisions.values():
		if area.grow(4).intersects(rect): return false
	for platform in game.world.platforms:
		if area.intersects(platform.rect): return false
	for y in 3:
		for x in 3:
			var sample := area.position+area.size*Vector2(x/2.0,y/2.0)
			if not game.world.walkable(sample,2) or game.world_view.water_at(sample).has_area(): return false
	return true
func begin_placement(point: Vector2) -> bool:
	if placing() or game.is_paused() or game.locomotion.airborne() or game.locomotion.sliding(): return false
	if game.bag.held_id() != &"basic_workbench": return false
	if not can_place(point): game.feedback = "Elige suelo libre y cercano para colocar la mesa."; game.feedback_time = 2; return false
	game.cancel_work(); game.interaction_motion.reset(); game.equipping = false
	pending_uid = game.bag.held_item().uid; pending_point = point; remaining = PLACE_SECONDS
	game.movement.target_direction = Vector2.ZERO; queue_redraw(); return true
func advance_placement(delta: float) -> void:
	if not placing(): return
	if game.bag.held_item().get("uid",-1) != pending_uid or not can_place(pending_point): cancel_placement(); return
	remaining = maxf(0,remaining-maxf(0,delta))
	if remaining > 0.000001: return
	var location: Dictionary = game.bag.location(pending_uid)
	var item: Dictionary = game.bag.at(location.kind,location.index)
	if item.get("id") != &"basic_workbench": cancel_placement(); return
	var uid := pending_uid; var point := pending_point
	if location.kind == &"quick": game.bag.quick_slots[location.index] = {}
	elif location.kind == &"bag": game.bag.slots[location.index] = {}
	else: cancel_placement(); return
	game.bag.active_quick_uid = -1; cancel_placement(); add_table(point,uid)
	game.feedback = "Mesa colocada · apunta a ella y pulsa E."; game.feedback_time = 3
	game.inventory_panel.refresh(); game.update_hud()
func add_table(point: Vector2, uid: int) -> void:
	var sprite := Sprite2D.new(); sprite.centered = false; sprite.texture = Art.texture()
	var rect := graphic_rect(point); sprite.position = rect.position; sprite.scale = rect.size/sprite.texture.get_size()
	sprite.z_as_relative = false; add_child(sprite)
	var collision := collider(point)
	tables.append({"point":point,"uid":uid,"sprite":sprite,"collider":collision})
	game.world.building_collisions.append(collision); game.world.navigation_revision += 1
func interact(aim: Vector2) -> bool:
	for table in tables:
		if not Art.contains(aim,graphic_rect(table.point)): continue
		if game.player.distance_to(table.point) > REACH:
			game.feedback = "Acércate a la mesa de fabricación."; game.feedback_time = 2; return true
		game.cancel_work(); game.inventory_panel.hide(); game.item_catalog.hide(); game.world_map.hide()
		window.open_window(); return true
	return false
func _process(delta: float) -> void:
	if game == null: return
	if not game.is_paused(): advance_placement(delta)
	for table in tables:
		table.sprite.visible = not game.hut.inside
		table.sprite.z_index = preload("res://scripts/world_depth.gd").layer(table.point.y)
		table.sprite.modulate.a = preload("res://scripts/world_depth.gd").opacity(game,Rect2(table.sprite.position,table.sprite.texture.get_size()*table.sprite.scale),table.point.y)
	if game.bag.held_id() == &"basic_workbench" or placing(): queue_redraw()
func _draw() -> void:
	if game == null or game.is_paused() or game.hut.inside: return
	if game.bag.held_id() != &"basic_workbench" and not placing(): return
	var point: Vector2 = pending_point if placing() else game.cursor_world_position()
	var allowed := can_place(point)
	draw_texture_rect(Art.texture(),graphic_rect(point),false,Color(0.7,1.0,0.7,0.5) if allowed else Color(1.0,0.45,0.45,0.5))
func snapshot() -> Array:
	var result := []
	for table in tables: result.append({"point":table.point,"uid":table.uid})
	return result
static func valid_snapshot(data) -> bool:
	if not data is Array or data.size() > 128: return false
	var ids := {}
	for table in data:
		if not table is Dictionary or not table.get("point") is Vector2 or not table.point.is_finite() or not table.get("uid") is int or table.uid < 1 or ids.has(table.uid): return false
		ids[table.uid] = true
	return true
func restore(data: Array) -> void:
	reset()
	for table in data: add_table(table.point,table.uid)
