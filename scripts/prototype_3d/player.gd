extends CharacterBody3D
const SPEED := 2.0
const RUN_MULTIPLIER := 1.6
const GRAVITY := 18.0
const WORLD_SCALE := 1.8/64.0
var game
var model: Node3D
var phase := 0.0
var equipped := true
var action_elapsed := -1.0
var equip_elapsed := -1.0
var contact_done := false
var action_heading := 0.0
var action_target: Dictionary = {}
var locomotion = preload("res://scripts/locomotion.gd").new()
var jump_was_pressed := false
var control_was_pressed := false
const ACTION_SECONDS := 0.75
func configure(owner_game) -> void:
 game = owner_game
 var capsule := CapsuleShape3D.new(); capsule.radius = 0.24; capsule.height = 1.75
 var collision := CollisionShape3D.new(); collision.shape = capsule; collision.position.y = 0.875; add_child(collision)
 collision_layer = 2; collision_mask = 1
 model = preload("res://scripts/prototype_3d/survivor_model.gd").new(); add_child(model); model.scale = Vector3.ONE*WORLD_SCALE; model.rotation.y = PI
 model.animate(&"idle",0,equipped)
func toggle_tool() -> void:
 if action_elapsed >= 0: return
 equipped = not equipped; equip_elapsed = 0 if equipped else -1.0
func strike() -> bool:
 if not equipped or action_elapsed >= 0 or equip_elapsed >= 0: return false
 action_elapsed = 0; contact_done = false
 action_target = game.camera_rig.target()
 var forward: Vector3 = game.camera_rig.facing(); action_heading = atan2(forward.x,forward.z)
 return true
func _physics_process(delta: float) -> void:
 if game == null or game.paused: return
 var input := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
 var direction: Vector3 = game.camera_rig.movement_direction(input)
 var control := Input.is_physical_key_pressed(KEY_CTRL)
 var running := Input.is_physical_key_pressed(KEY_SHIFT) and action_elapsed < 0 and not input.is_zero_approx()
 if control and not control_was_pressed and running and is_on_floor():
  locomotion.slide(Vector2(direction.x,direction.z))
 control_was_pressed = control
 var jump_pressed := Input.is_physical_key_pressed(KEY_SPACE)
 if jump_pressed and not jump_was_pressed and is_on_floor():
  locomotion.jump(); velocity.y = 5.5
 jump_was_pressed = jump_pressed
 locomotion.steer_air(Vector2(direction.x,direction.z),delta)
 locomotion.advance(delta,control and not locomotion.sliding())
 running = running and locomotion.crouch < 0.01
 var speed := SPEED*(RUN_MULTIPLIER if running else 1.0)
 var planar: Vector2 = locomotion.velocity(Vector2(direction.x,direction.z)*speed,WORLD_SCALE)
 if locomotion.from_slide: planar *= WORLD_SCALE
 velocity.x = planar.x; velocity.z = planar.y
 if not is_on_floor(): velocity.y -= GRAVITY*delta
 move_and_slide()
 var forward: Vector3 = game.camera_rig.facing()
 model.rotation.y = lerp_angle(model.rotation.y,action_heading if action_elapsed >= 0 else atan2(forward.x,forward.z),1-exp(-delta*15))
 var state: StringName = &"idle"; var progress := 0.0
 if input.length_squared()>0:
  phase = fposmod(phase+delta/(0.45 if running else 0.60),1)
 if action_elapsed >= 0:
  action_elapsed += delta; state = &"action"; progress = clampf(action_elapsed/ACTION_SECONDS,0,1)
  if not contact_done and progress >= 0.5: contact_done = true; game.resolve_hit(action_target)
  if action_elapsed >= ACTION_SECONDS: action_elapsed = -1
 elif locomotion.sliding():
  state = &"slide"; progress = locomotion.slide_elapsed/locomotion.SLIDE_SECONDS
 elif not is_on_floor():
  state = &"slide_jump" if locomotion.from_slide else &"jump"
  progress = locomotion.jump_elapsed/locomotion.JUMP_SECONDS
 elif equip_elapsed >= 0:
  equip_elapsed += delta; state = &"equip"; progress = clampf(equip_elapsed/0.42,0,1)
  if input.length_squared()>0:
   state = &"equip_crouch_walk" if locomotion.crouch>0.01 else (&"equip_run" if running else &"equip_walk")
  if equip_elapsed >= 0.42: equip_elapsed = -1
 elif input.length_squared() > 0:
  state = &"crouch_walk" if locomotion.crouch>0.01 else (&"run" if running else &"walk")
  progress = phase
 elif locomotion.crouch>0:
  state = &"crouch"; progress = locomotion.crouch
 var local_travel: Vector3 = (model.global_basis.inverse()*direction).normalized()
 model.animate(state,progress,equipped,delta,phase,local_travel)
 game.camera_rig.update(delta)
