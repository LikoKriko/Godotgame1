extends Node2D
## Separate room: the exterior never draws the interior scene.
const Style = preload("res://scripts/visual_style.gd")
const ROOM_CENTER := Vector2(10000,10000)
const ROOM_SIZE := Vector2(360,270)
const ROOM_BOUNDS := Rect2(ROOM_CENTER-ROOM_SIZE/2,ROOM_SIZE)
const ROOM_DOOR := ROOM_CENTER+Vector2(0,105)
const DRAW_SIZE := Vector2(280,233)
const ROOM_SCENE = preload("res://scenes/hut_interior.tscn")
var game
var inside := false
var outside_player := Vector2.ZERO
var base := Vector2.ZERO
var door := Vector2.ZERO
var footprint := Rect2()
var exterior: Sprite2D
var room: Node2D
var timber: Texture2D
var image: Texture2D

func configure(owner_game) -> void:
	game = owner_game
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image = Style.normalized(load("res://assets/environment/imported/hut_01.png"),DRAW_SIZE)
	timber = load("res://assets/environment/imported/hut_timber.png")
	exterior = Sprite2D.new(); exterior.centered = false; exterior.texture = image
	exterior.scale = DRAW_SIZE/image.get_size(); exterior.z_index = -1; add_child(exterior)
	reset()

func reset() -> void:
	inside = false
	if is_instance_valid(room): room.free(); room = null
	game.world_view.show()
	choose_location()
	exterior.position = base+Vector2(-DRAW_SIZE.x/2,17-DRAW_SIZE.y)
	exterior.show()
	outside_player = door+Vector2(0,28)

func choose_location() -> void:
	# Reserve a natural clearing close to the initial crossroads. Do not remove props.
	var found := false
	for y in range(-120,-601,-32):
		for x in range(180,701,32):
			var candidate := Vector2(x,y)
			var occupied := Rect2(candidate+Vector2(-140,-170),Vector2(280,220))
			var clear := true
			for platform in game.world.platforms:
				if occupied.intersects(platform.rect.grow(16)): clear = false
			for cell in game.world.props:
				if game.world_view.presentation(cell).rect.grow(12).intersects(occupied): clear = false; break
			for puddle in game.world.puddles:
				if occupied.grow(puddle.width).has_point(puddle.position): clear = false
			if clear and game.world.walkable(candidate+Vector2(40,42),24):
				base = candidate; found = true; break
		if found: break
	footprint = Rect2(base+Vector2(-112,-88),Vector2(224,98))
	# Source doorway sits slightly right of the facade center.
	door = base+Vector2(40,-17)
	game.world.building_collisions.clear()
	var opening_left := door.x-26; var opening_right := door.x+26
	game.world.building_collisions.append(Rect2(footprint.position,Vector2(opening_left-footprint.position.x,footprint.size.y)))
	game.world.building_collisions.append(Rect2(Vector2(opening_right,footprint.position.y),Vector2(footprint.end.x-opening_right,footprint.size.y)))
	game.world.building_collisions.append(Rect2(footprint.position,Vector2(footprint.size.x,54)))
	game.world.navigation_revision += 1
	if game.world_view.terrain_chunks != null:
		game.world_view.terrain_chunks.sampler.add_influence(&"hut",&"dirt",footprint.grow(18),1.0)
		game.world_view.terrain_chunks.refresh_influences()

func near_door(point: Vector2) -> bool:
	return point.distance_to(ROOM_DOOR if inside else door) <= 48

func interact() -> bool:
	if not near_door(game.player): return false
	game.cancel_work(); game.interaction_motion.reset(); game.locomotion.reset(); game.ground_height = 0; game.rock_support = game.world.NO_SUPPORT; game.previously_airborne = false
	if inside:
		inside = false; game.player = outside_player
	else:
		outside_player = game.player; inside = true; game.player = ROOM_DOOR-Vector2(0,24)
		game.enemies.parry.pending.clear()
	apply_visibility()
	game.movement.reset(); game.camera.position = game.player; game.full_avatar.reset()
	game.feedback = "E · salir de la choza" if inside else "Has salido de la choza."
	game.feedback_time = 2; game.update_hud()
	return true

func apply_visibility() -> void:
	exterior.visible = not inside; game.world_view.visible = not inside
	if inside:
		if not is_instance_valid(room):
			room = ROOM_SCENE.instantiate(); room.host = self; add_child(room)
		room.show()
	elif is_instance_valid(room):
		room.queue_free(); room = null
	if is_instance_valid(game.enemies.enemy): game.enemies.enemy.visible = not inside
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
	for sign in [-1,1]:
		var wall := Rect2(Vector2(floor_rect.position.x if sign == -1 else ROOM_CENTER.x+24,floor_rect.end.y),Vector2(floor_rect.size.x/2-24,16))
		surface.draw_texture_rect(timber,wall,false,Color("81705b"))
	surface.draw_texture_rect(timber,Rect2(ROOM_CENTER.x-24,floor_rect.end.y,48,16),false,Color("c2ac86"))

func snapshot() -> Dictionary:
	return {"inside":inside,"outside_player":outside_player}
static func valid_snapshot(data) -> bool:
	return data is Dictionary and data.get("inside") is bool and data.get("outside_player") is Vector2 and data.outside_player.is_finite()

func _process(_delta: float) -> void:
	if inside: return
	var in_doorway: bool = absf(game.player.x-door.x) < 26 and game.player.y > base.y-34
	exterior.z_index = 1 if game.player.y+17 < base.y and not in_doorway else -1
