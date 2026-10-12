extends Node2D
const Regions = preload("res://assets/characters/survivor_regions.gd")
const Frames = preload("res://scripts/survivor_frames.gd")
const Tools = preload("res://scripts/tool_sprites.gd")
var item: StringName = &""
var hand := Vector2.ZERO
var tip := Vector2.ZERO
var mirrored := false
var fist: AtlasTexture
var fist_size := Vector2.ZERO
static var fists: Dictionary = {}

static func metadata(texture: AtlasTexture) -> Dictionary:
	for i in 8:
		var idle: Array = Regions.IDLE[i]
		if texture.atlas == Frames.IDLE_SHEET and texture.region == Rect2(idle[0],idle[1],idle[2],idle[3]):
			return {"point": Regions.HAND_IDLE[i],"region": idle}
		for j in 4:
			var walk: Array = Regions.WALK[i][j]
			if texture.atlas == Frames.SHEET and texture.region == Rect2(walk[0],walk[1],walk[2],walk[3]):
				return {"point": Regions.HAND_WALK[i][j],"region": walk}
	return {"point": Regions.HAND_IDLE[0],"region": Regions.IDLE[0]}

static func offset(texture: AtlasTexture) -> Vector2:
	var data := metadata(texture)
	return to_world(data["point"],data["region"])

static func to_world(point: Array, region: Array) -> Vector2:
	var factor: float = Frames.CHARACTER_HEIGHT/float(region[3])
	return Vector2((point[0]-region[4])*factor,17+(point[1]-region[1]-region[3])*factor)

func update_pose(game) -> void:
	item = game.bag.held_id()
	visible = item != &"" and not game.working and not game.equipping
	if not visible:
		return
	position = game.player
	mirrored = game.movement.facing() in [&"left",&"up_left",&"down_left"]
	var texture: AtlasTexture = game.character.sprite_frames.get_frame_texture(game.character.animation,game.character.frame)
	var data := metadata(texture)
	hand = to_world(data["point"],data["region"])
	var key := texture.get_instance_id()
	if not fists.has(key):
		var patch := AtlasTexture.new()
		patch.atlas = texture.atlas
		patch.region = Rect2(Vector2(data["point"][0],data["point"][1])-Vector2(8,8),Vector2(16,16))
		fists[key] = patch
	fist = fists[key]
	fist_size = Vector2(16,16)*64.0/data["region"][3]
	var direction: Vector2 = preload("res://scripts/arm_rig.gd").rest_direction(game.movement.facing(),item)
	tip = hand+direction*preload("res://scripts/arm_rig.gd").TOOL_LENGTHS.get(item,0.0)
	queue_redraw()

func _draw() -> void:
	if item != &"":
		Tools.draw(self,item,hand,tip,mirrored)
		# Original fist pixels cover the grip, so the handle sits inside the hand.
		if fist != null:
			draw_texture_rect(fist,Rect2(hand-fist_size/2,fist_size),false)
