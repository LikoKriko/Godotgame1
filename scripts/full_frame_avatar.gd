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
var atlas := AtlasTexture.new()
var phase := 0.0
var state: StringName = &"idle"
var direction := 4
var frame_index := 0
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
	return "bare" if game.bag.held_id() == &"" else String(game.bag.held_id())

func data_for(clip: StringName) -> Dictionary:
	return catalogue["items"][item_key()]["clips"][String(clip)]

func sheet_for(data: Dictionary) -> Texture2D:
	var path: String = data["path"]
	if not sheets.has(path):
		var image: Texture2D = load(path)
		var canvas := Vector2i(catalogue["canvas"][0],catalogue["canvas"][1])
		if not Clips.validate_sheet(image,canvas,int(data["directions"]),int(data["frames"])):
			push_error("Invalid complete-frame sheet: "+path)
			return null
		sheets[path] = image
		sheet_order.append(path)
		if sheet_order.size() > 4:
			sheets.erase(sheet_order.pop_front())
	return sheets[path]

func update_pose(delta: float) -> void:
	var moving: bool = game.player.distance_squared_to(previous_player) > 0.000001
	previous_player = game.player
	var item: StringName = game.bag.held_id()
	if item != selected_item:
		selected_item = item
		sheets.clear()
		sheet_order.clear()
	var clip: StringName = &"idle"
	var progress := 0.0
	if game.working:
		clip = &"action"
		progress = clampf(game.work_elapsed/game.work_duration,0,1)
		was_moving = false
	elif game.equipping:
		clip = &"equip"
		progress = clampf(game.equip_elapsed/(0.5 if game.bag.held_category() == &"pickaxe" else 0.42),0,1)
		was_moving = false
	elif game.locomotion.airborne():
		clip = &"jump"
		progress = game.locomotion.jump_elapsed/game.locomotion.JUMP_SECONDS
		was_moving = false
	elif game.locomotion.sliding():
		clip = &"slide"
		progress = game.locomotion.slide_elapsed/game.locomotion.SLIDE_SECONDS
		was_moving = false
	elif game.locomotion.crouch > 0.01:
		clip = &"crouch"
		progress = game.locomotion.crouch
		was_moving = false
	elif moving:
		if not was_moving:
			state = &"start"
			transition_elapsed = 0
			phase = 0
		was_moving = true
		if state == &"start" and transition_elapsed < START_SECONDS:
			clip = &"start"
			transition_elapsed += delta
			progress = clampf(transition_elapsed/START_SECONDS,0,1)
		else:
			clip = &"walk"
			phase = fposmod(phase+delta/WALK_SECONDS*game.movement.speed_factor*game.nutrition.speed_multiplier()*(1+game.ranks[2]*0.1),1)
			progress = phase
	else:
		if was_moving:
			stop_clip = StringName(("stop_start_%02d" if state == &"start" else "stop_%02d") % frame_index)
			transition_elapsed = 0
			state = &"stop"
			was_moving = false
		if state == &"stop" and transition_elapsed < STOP_SECONDS:
			clip = stop_clip
			transition_elapsed += delta
			progress = clampf(transition_elapsed/STOP_SECONDS,0,1)
	state = &"stop" if String(clip).begins_with("stop_") else clip
	var data := data_for(clip)
	var count: int = data["frames"]
	direction = Clips.direction_index(game.movement.heading,int(data["directions"]))
	frame_index = Clips.action_frame(progress,count)
	var canvas := Vector2(catalogue["canvas"][0],catalogue["canvas"][1])
	atlas.atlas = sheet_for(data)
	atlas.region = Rect2(Vector2(frame_index*canvas.x,direction*canvas.y),canvas)
	atlas.filter_clip = true
	texture = atlas
	var factor: float = 1.0/catalogue["pixels_per_world"]
	scale = Vector2.ONE*factor
	var foot := Vector2(catalogue["foot"][0],catalogue["foot"][1])
	position = game.player+Vector2(0,17-game.locomotion.height())-foot*factor
	show()

func shot_origin() -> Vector2:
	var data := data_for(&"action")
	var facing := Clips.direction_index(game.movement.heading,16)
	var point: Array = data["anchors"][facing][8]
	var foot := Vector2(catalogue["foot"][0],catalogue["foot"][1])
	return game.player+Vector2(0,17)+(Vector2(point[0],point[1])-foot)/float(catalogue["pixels_per_world"])
