extends Node2D
## Separate room: the exterior never draws the interior scene.
const Style = preload("res://scripts/visual_style.gd")
const ROOM_CENTER := Vector2(10000,10000)
const ROOM_SIZE := Vector2(360,270)
const ROOM_BOUNDS := Rect2(ROOM_CENTER-ROOM_SIZE/2,ROOM_SIZE)
const ROOM_DOOR := ROOM_CENTER+Vector2(0,105)
static var SHADOW_CONTACTS := PackedVector2Array([Vector2(0.086,0.802),Vector2(0.37,0.989),Vector2(0.69,0.95),Vector2(0.90,0.877)])
const DRAW_SIZE := Vector2(280,233)
const ROOM_SCENE = preload("res://scenes/hut_interior.tscn")
var game
var inside := false
var outside_player := Vector2.ZERO
var base := Vector2.ZERO
var door := Vector2.ZERO
var footprint := Rect2()
var exterior: Sprite2D
var buildings: Array[Dictionary] = []
var active_building := 0
var room: Node2D
var timber: Texture2D
var image: Texture2D

func configure(owner_game) -> void:
	game = owner_game
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preload("res://scripts/camp_art.gd").prepare()
	timber = load("res://assets/environment/imported/hut_timber.png")
	reset()

func reset() -> void:
	inside = false
	if is_instance_valid(room): room.free(); room = null
	game.world_view.show()
	choose_location()
	for record in buildings:
		record.sprite.free()
	buildings.clear()
	for data in game.world.camp_buildings:
		var record: Dictionary = data.duplicate(true)
		var sprite := Sprite2D.new()
		sprite.centered = false; sprite.texture = preload("res://scripts/camp_art.gd").textures[data.id]
		sprite.position = data.rect.position; sprite.scale = data.rect.size/sprite.texture.get_size()
		sprite.z_as_relative = false; sprite.z_index = -1
		add_child(sprite); record["sprite"] = sprite; buildings.append(record)
	active_building = 0
	choose_location()
	outside_player = door+Vector2(0,28)

func choose_location() -> void:
	if buildings.is_empty(): return
	var record: Dictionary = buildings[active_building]
	base = record.base; door = record.door; footprint = record.footprint
	exterior = record.sprite; image = exterior.texture
	if game.world_view.terrain_chunks != null:
		for building in buildings:
			game.world_view.terrain_chunks.sampler.add_influence(StringName("camp_%d" % building.id),&"dirt",building.footprint.grow(18),1.0)
		game.world_view.terrain_chunks.refresh_influences()

func near_door(point: Vector2) -> bool:
	if inside: return point.distance_to(ROOM_DOOR) <= 48
	var closest := 48.000001; var selected := -1
	for building in buildings:
		var distance := point.distance_to(building.door)
		if distance < closest: closest = distance; selected = building.id
	if selected < 0: return false
	active_building = selected; choose_location()
	return true

func interact() -> bool:
	if not near_door(game.player): return false
	game.cancel_work(); game.interaction_motion.reset(); game.locomotion.reset(); game.ground_height = 0; game.rock_support = game.world.NO_SUPPORT; game.previously_airborne = false
	if inside:
		inside = false; game.player = outside_player
	else:
		outside_player = game.player; inside = true; game.player = ROOM_DOOR-Vector2(0,24)
		game.enemies.parry.pending.clear()
	apply_visibility()
	game.movement.reset(); game.update_camera_position(); game.full_avatar.reset()
	game.feedback = "E · salir de la choza" if inside else "Has salido de la choza."
	game.feedback_time = 2; game.update_hud()
	return true

func apply_visibility() -> void:
	for building in buildings: building.sprite.visible = not inside
	game.world_view.visible = not inside
	if inside:
		if not is_instance_valid(room):
			room = ROOM_SCENE.instantiate(); room.host = self; room.z_index = -10; add_child(room)
		room.show()
	elif is_instance_valid(room):
		room.queue_free(); room = null
	for creature in get_tree().get_nodes_in_group("creatures"): creature.visible = not inside
	var bounds: Rect2 = ROOM_BOUNDS.grow(120) if inside else game.world.bounds
	game.camera.limit_left = floori(bounds.position.x); game.camera.limit_top = floori(bounds.position.y)
	game.camera.limit_right = ceili(bounds.end.x); game.camera.limit_bottom = ceili(bounds.end.y)
	if is_instance_valid(room): room.queue_redraw()
	game.solar_lighting.shadows.queue_redraw()

func move_inside(point: Vector2, displacement: Vector2) -> Vector2:
	var bounds := ROOM_BOUNDS.grow(-20.001)
	return (point+displacement).clamp(bounds.position,bounds.end)

func draw_room(surface: Node2D) -> void:
	var floor_rect := ROOM_BOUNDS
	surface.draw_rect(floor_rect.grow(2000),Color("121510"))
	for y in range(int(floor_rect.position.y),int(floor_rect.end.y),18):
		for x in range(int(floor_rect.position.x),int(floor_rect.end.x),60):
			var board := Rect2(x,y,60,18)
			var tone := Color("6d4d37")*(0.94+0.12*preload("res://scripts/terrain_sampler.gd").hash_at(x,y,game.world.seed_value))
			surface.draw_rect(board,tone)
			surface.draw_texture_rect(timber,board,false,Color(0.38,0.38,0.34,0.14))
			surface.draw_line(board.position,Vector2(board.position.x,board.end.y),Color("473b30"),1.0/Style.PIXELS_PER_WORLD)
		surface.draw_line(Vector2(floor_rect.position.x,y),Vector2(floor_rect.end.x,y),Color("473b30"),1.0/Style.PIXELS_PER_WORLD)
	var walls := [Rect2(floor_rect.position-Vector2(18,28),Vector2(floor_rect.size.x+36,28)),Rect2(floor_rect.position-Vector2(18,0),Vector2(18,floor_rect.size.y)),Rect2(Vector2(floor_rect.end.x,floor_rect.position.y),Vector2(18,floor_rect.size.y))]
	for wall in walls:
		surface.draw_texture_rect(timber,wall,false,Color("81705b")); surface.draw_rect(wall,Color("30271e"),false,1.0/Style.PIXELS_PER_WORLD)
	for wall_side in [-1,1]:
		var wall := Rect2(Vector2(floor_rect.position.x if wall_side == -1 else ROOM_CENTER.x+24,floor_rect.end.y),Vector2(floor_rect.size.x/2-24,16))
		surface.draw_texture_rect(timber,wall,false,Color("81705b"))
	surface.draw_texture_rect(timber,Rect2(ROOM_CENTER.x-24,floor_rect.end.y,48,16),false,Color("c2ac86"))

func snapshot() -> Dictionary:
	return {"inside":inside,"outside_player":outside_player,"active_building":active_building}
static func valid_snapshot(data) -> bool:
	return data is Dictionary and data.get("inside") is bool and data.get("outside_player") is Vector2 and data.outside_player.is_finite() and data.get("active_building",0) is int and data.get("active_building",0) >= 0 and data.get("active_building",0) < 6

func _process(_delta: float) -> void:
	if inside: return
	for building in buildings:
		var sprite: Sprite2D = building.sprite
		sprite.z_index = preload("res://scripts/world_depth.gd").layer(building.rect.end.y)
		sprite.modulate.a = preload("res://scripts/world_depth.gd").opacity(game,building.rect,building.rect.end.y)
