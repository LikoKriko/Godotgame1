extends Node2D
const MAX_HEALTH := 10.0
const SPEED := 56.0
const AGGRO_RADIUS := 250.0
const ATTACK_REACH := 30.0
const ATTACK_PERIOD := 1.0
const IMPACT_PHASE := 0.5
const DAMAGE := 2.0
const CLIPS_PATH := "res://assets/enemies/first/manifest.json"
var game
var manager
var health := MAX_HEALTH
var heading := PI/2
var attack_elapsed := -1.0
var impact_done := false
var punch_left := true
var stun_remaining := 0.0
var walk_phase := 0.0
var state: StringName = &"idle"
var sprite := Sprite2D.new()
var atlas := AtlasTexture.new()
var clips: Dictionary = {}
var sheets: Dictionary = {}
var alpha_masks: Dictionary = {}
var current_sheet := ""

static func artwork_ready() -> bool: return FileAccess.file_exists(CLIPS_PATH)
func configure(owner_game, owner_manager) -> void:
	game = owner_game; manager = owner_manager
	add_to_group("damageable")
	add_child(sprite); sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if artwork_ready(): clips = JSON.parse_string(FileAccess.get_file_as_string(CLIPS_PATH))
	update_sprite()
func stun(seconds: float) -> void:
	stun_remaining = maxf(stun_remaining,seconds)
	attack_elapsed = -1; impact_done = true; state = &"idle"
func hit_center() -> Vector2: return global_position+Vector2(0,-1)
func contains_point(point: Vector2) -> bool:
	if sprite.texture == null: return point.distance_to(hit_center()) < 18
	var local := sprite.to_local(point)+sprite.texture.get_size()/2
	if not Rect2(Vector2.ZERO,sprite.texture.get_size()).has_point(local): return false
	return alpha_masks[current_sheet].get_bitv(Vector2i(atlas.region.position+local))
func take_damage(amount: float) -> void:
	if health <= 0: return
	health = maxf(0,health-maxf(amount,0))
	game.combat_effects.flash(hit_center(),game.player.direction_to(position))
	if health == 0:
		manager.defeated = true; remove_from_group("damageable"); hide(); queue_free()
func advance(delta: float) -> void:
	if health <= 0 or game.progression.health <= 0: return
	if stun_remaining > 0:
		stun_remaining = maxf(0,stun_remaining-delta); state = &"idle"; return
	var distance: float = position.distance_to(game.player)
	if attack_elapsed >= 0:
		attack_elapsed += delta
		state = &"attack"
		if not impact_done and attack_elapsed+0.000000001 >= IMPACT_PHASE:
			impact_done = true
			if distance <= ATTACK_REACH and game.clear_combat_path(position):
				# Use the instant within this simulation step when the punch landed.
				# Frame rate must not enlarge the 0.2 s retrospective parry window.
				var contact_time: float = manager.parry.time-maxf(0,attack_elapsed-IMPACT_PHASE)
				var parried: bool = manager.parry.impact(self,DAMAGE,contact_time)
				game.combat_effects.flash(game.player+Vector2(0,-22),position.direction_to(game.player),parried)
		if attack_elapsed+0.000000001 >= ATTACK_PERIOD and stun_remaining <= 0:
			if distance <= ATTACK_REACH and game.clear_combat_path(position):
				attack_elapsed = maxf(0,attack_elapsed-ATTACK_PERIOD); impact_done = false; punch_left = not punch_left
				heading = position.direction_to(game.player).angle()
			else: attack_elapsed = -1
		return
	if distance > AGGRO_RADIUS: state = &"idle"; return
	heading = position.direction_to(game.player).angle()
	if distance <= ATTACK_REACH and game.clear_combat_path(position):
		attack_elapsed = 0; impact_done = false; state = &"attack"; return
	var direction: Vector2 = manager.chase_direction(position,game.player)
	var before := position
	position = game.world.move_actor(position,direction*SPEED*delta,9)
	var moved := position.distance_to(before)
	state = &"walk" if moved > 0.00001 else &"idle"
	if moved > 0:
		heading = (position-before).angle(); walk_phase = fposmod(walk_phase+moved/20,1)
func update_sprite() -> void:
	if clips.is_empty(): return
	var name := ("attack_left" if punch_left else "attack_right") if state == &"attack" else String(state)
	var clip: Dictionary = clips.get(name,clips.idle)
	if not sheets.has(clip.path):
		sheets[clip.path] = load(clip.path)
		var mask := BitMap.new(); mask.create_from_image_alpha(sheets[clip.path].get_image(),0.5)
		alpha_masks[clip.path] = mask
	current_sheet = clip.path
	var phase := walk_phase if state == &"walk" else (clampf(attack_elapsed/ATTACK_PERIOD,0,1) if state == &"attack" else 0.0)
	var frame := preload("res://scripts/complete_sprite_clips.gd").action_frame(phase,clip.frames)
	var direction := preload("res://scripts/complete_sprite_clips.gd").direction_index(heading,int(clip.directions))
	var cell: Vector2 = Vector2(clips.canvas[0],clips.canvas[1])
	atlas.atlas = sheets[clip.path]; atlas.region = Rect2(Vector2(frame,direction)*cell,cell); atlas.filter_clip = true
	sprite.texture = atlas; sprite.scale = Vector2.ONE/clips.pixels_per_world
	sprite.position = Vector2(0,17)-Vector2(clips.foot[0],clips.foot[1])/clips.pixels_per_world+cell/(2*clips.pixels_per_world)
	z_index = 1 if position.y > game.player.y else -1
