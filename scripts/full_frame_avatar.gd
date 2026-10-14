extends Sprite2D
## Runtime presentation is one complete image: no live skin/limb deformation.
const Clips = preload("res://scripts/complete_sprite_clips.gd")
const MANIFEST := "res://assets/characters/complete/manifest.json"
const WALK_SECONDS := 0.60
const START_SECONDS := 0.14
const STOP_SECONDS := 0.18
var game
var catalogue: Dictionary
var sheets: Dictionary = {}
var sheet_order: Array[String] = []
var cache_bytes := 0
const CACHE_BYTES := 128*1024*1024
var atlas := AtlasTexture.new()
var phase := 0.0
var state: StringName = &"idle"
var direction := 4
var frame_index := 0
var active_data: Dictionary = {}
var transition_elapsed := 0.0
var stop_clip: StringName = &"stop_00"
var previous_player := Vector2.ZERO
var was_moving := false
var selected_item: StringName = &"axe"

func configure(owner_game) -> void:
	game = owner_game
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visibility_layer = 1 << 19
	catalogue = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	reset()

func reset() -> void:
	phase = 0
	state = &"idle"
	transition_elapsed = 0
	was_moving = false
	previous_player = game.player
	selected_item = game.bag.held_id()
	update_pose(0)

func item_key() -> String:
	var id := "bare" if game.bag.held_id() == &"" else String(game.bag.held_id())
	if id == "bow" and game.bag.count(&"flecha") == 0 and catalogue.items.has("bow_unloaded"): id = "bow_unloaded"
	if id == "botella": id = "bottle_full" if game.bag.held_item().get("water_ml",0) > 0 else "bottle_empty"
	if not catalogue.items.has(id): id = "bare"
	var armor: StringName = game.bag.equipment[&"torso"].get("id",&"")
	return String(armor)+"__"+id if catalogue.items.has(String(armor)+"__"+id) else id

func data_for(clip: StringName) -> Dictionary:
	var clips: Dictionary = catalogue["items"][item_key()]["clips"]
	return clips.get(String(clip),clips["idle"])

func sheet_for(data: Dictionary, progress: float = 0.0) -> Texture2D:
	var path: String = data.paths[Clips.action_frame(progress,data.equip_frames)] if data.has("paths") else data["path"]
	if not sheets.has(path):
		var image: Texture2D = load(path)
		var canvas := Vector2i(catalogue["canvas"][0],catalogue["canvas"][1])
		if not Clips.validate_sheet(image,canvas,int(data["directions"]),int(data["frames"])):
			push_error("Invalid complete-frame sheet: "+path)
			return null
		var bytes := image.get_width()*image.get_height()*4
		while not sheet_order.is_empty() and cache_bytes+bytes > CACHE_BYTES:
			var evicted: String = sheet_order.pop_front()
			cache_bytes -= sheets[evicted].get_width()*sheets[evicted].get_height()*4
			sheets.erase(evicted)
		sheets[path] = image
		cache_bytes += bytes
	if path in sheet_order: sheet_order.erase(path)
	sheet_order.append(path)
	return sheets[path]

func update_pose(delta: float) -> void:
	var moving: bool = game.player.distance_squared_to(previous_player) > 0.000001
	previous_player = game.player
	var item: StringName = game.bag.held_id()
	if item != selected_item:
		selected_item = item

	var clip: StringName = &"idle"
	var progress := 0.0
	if game.interaction_motion.picking_up():
		clip = &"pickup_walk" if moving else &"pickup"
		progress = game.interaction_motion.pickup_phase()
		if moving: phase = fposmod(phase+delta/WALK_SECONDS*game.movement.speed_factor*game.interaction_motion.speed_multiplier(),1)
		was_moving = moving
	elif game.working:
		clip = &"action"
		progress = clampf(game.work_elapsed/game.work_duration,0,1)
		if game.bag.held_category() == &"bow":
			var draw_seconds: float = preload("res://scripts/action_motion.gd").BOW_DRAW_SECONDS
			if game.work_elapsed < draw_seconds:
				clip = &"draw"; progress = clampf(game.work_elapsed/draw_seconds,0,1)
			else: progress = 0.5+0.5*clampf((game.work_elapsed-draw_seconds)/(game.work_duration-draw_seconds),0,1)
		was_moving = false
	elif game.equipping and not game.locomotion.airborne() and not game.locomotion.sliding():
		clip = &"crouch_equip" if game.locomotion.crouch > 0.95 else &"equip"
		progress = clampf(game.equip_elapsed/(0.5 if game.bag.held_category() == &"pickaxe" else 0.42),0,1)
		if moving:
			clip = &"equip_crouch_walk" if game.locomotion.crouch > 0.95 else (&"equip_run" if game.running else &"equip_walk")
			phase = fposmod(phase+delta/(0.45 if game.running else WALK_SECONDS)*game.movement.speed_factor*game.locomotion.speed_factor()*game.nutrition.speed_multiplier()*game.progression.speed_multiplier(),1)
		was_moving = moving
	elif game.locomotion.airborne():
		clip = &"slide_jump" if game.locomotion.from_slide else &"jump"
		progress = game.locomotion.jump_elapsed/game.locomotion.JUMP_SECONDS
		was_moving = false
	elif game.locomotion.sliding():
		clip = &"slide"
		progress = game.locomotion.slide_elapsed/game.locomotion.SLIDE_SECONDS
		was_moving = false
	elif game.locomotion.crouch > 0.01:
		if moving and game.locomotion.crouch > 0.95:
			clip = &"crouch_walk"
			phase = fposmod(phase+delta/WALK_SECONDS*game.locomotion.speed_factor()*game.nutrition.speed_multiplier()*game.progression.speed_multiplier(),1)
			progress = phase
		else:
			clip = &"crouch"
			progress = game.locomotion.crouch
		was_moving = false
	elif moving:
		if not was_moving:
			state = &"start_run" if game.running else &"start"
			transition_elapsed = 0
			phase = 0
		was_moving = true
		if state in [&"start",&"start_run"] and transition_elapsed < START_SECONDS:
			clip = &"start_run" if game.running else &"start"
			transition_elapsed += delta
			progress = clampf(transition_elapsed/START_SECONDS,0,1)
		else:
			clip = &"run" if game.running else &"walk"
			phase = fposmod(phase+delta/(0.45 if game.running else WALK_SECONDS)*game.movement.speed_factor*game.nutrition.speed_multiplier()*game.progression.speed_multiplier(),1)
			progress = phase
	else:
		if was_moving:
			var prefix := "stop_run" if state in [&"run",&"start_run",&"equip_run"] else "stop"
			stop_clip = StringName((prefix+"_start_%02d" if state in [&"start",&"start_run"] else prefix+"_%02d") % (frame_index%12 if String(state).begins_with("equip_") else frame_index))
			transition_elapsed = 0
			state = &"stop"
			was_moving = false
		if state == &"stop" and transition_elapsed < STOP_SECONDS:
			clip = stop_clip
			transition_elapsed += delta
			progress = clampf(transition_elapsed/STOP_SECONDS,0,1)
	state = &"stop" if String(clip).begins_with("stop_") else clip
	var data := data_for(clip)
	active_data = data
	var count: int = data["frames"]
	var facing: float = game.player.direction_to(game.pickup_aim).angle() if game.interaction_motion.picking_up() else game.movement.heading
	direction = Clips.direction_index(facing,int(data["directions"]))
	if data.has("equip_frames"):
		frame_index = Clips.action_frame(phase,data.gait_frames)
	else:
		frame_index = Clips.action_frame(progress,count)
	var canvas := Vector2(catalogue["canvas"][0],catalogue["canvas"][1])
	atlas.atlas = sheet_for(data,progress)
	atlas.region = Rect2(Vector2(frame_index*canvas.x,direction*canvas.y),canvas)
	atlas.filter_clip = true
	texture = atlas
	var factor: float = 1.0/catalogue["pixels_per_world"]
	scale = Vector2.ONE*factor
	var foot := Vector2(catalogue["foot"][0],catalogue["foot"][1])
	position = game.player+Vector2(0,17-game.ground_height-game.locomotion.height())-foot*factor
	show()

func shot_origin() -> Vector2:
	var armor: StringName = game.bag.equipment[&"torso"].get("id",&"")
	var key := String(armor)+"__bow" if catalogue.items.has(String(armor)+"__bow") else "bow"
	var data: Dictionary = catalogue.items[key].clips.action
	var facing := Clips.direction_index(game.movement.heading,16)
	var point: Array = data["release_anchors"][facing]
	var foot := Vector2(catalogue["foot"][0],catalogue["foot"][1])
	return game.player+Vector2(0,17-game.ground_height)+(Vector2(point[0],point[1])-foot)/float(catalogue["pixels_per_world"])

func held_tip() -> Vector2:
	if not active_data.has("tip_anchors"): return Vector2.INF
	var point: Array = active_data.tip_anchors[direction][frame_index]
	return to_global(Vector2(point[0],point[1]))
