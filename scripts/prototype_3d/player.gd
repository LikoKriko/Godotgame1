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
 var running := Input.is_physical_key_pressed(KEY_SHIFT) and action_elapsed < 0
 var speed := SPEED*(RUN_MULTIPLIER if running else 1.0)
 velocity.x = direction.x*speed; velocity.z = direction.z*speed
 if not is_on_floor(): velocity.y -= GRAVITY*delta
 elif Input.is_physical_key_pressed(KEY_SPACE): velocity.y = 5.5
 move_and_slide()
 var forward: Vector3 = game.camera_rig.facing()
 model.rotation.y = lerp_angle(model.rotation.y,action_heading if action_elapsed >= 0 else atan2(forward.x,forward.z),1-exp(-delta*15))
 var state: StringName = &"idle"; var progress := 0.0
 if action_elapsed >= 0:
  action_elapsed += delta; state = &"action"; progress = clampf(action_elapsed/ACTION_SECONDS,0,1)
  if not contact_done and progress >= 0.5: contact_done = true; game.resolve_hit(action_target)
  if action_elapsed >= ACTION_SECONDS: action_elapsed = -1
 elif equip_elapsed >= 0:
  equip_elapsed += delta; state = &"equip"; progress = clampf(equip_elapsed/0.42,0,1)
  if equip_elapsed >= 0.42: equip_elapsed = -1
 elif input.length_squared() > 0:
  state = &"run" if running else &"walk"
  phase = fposmod(phase+delta/(0.45 if running else 0.60),1); progress = phase
 model.animate(state,progress,equipped)
 game.camera_rig.update(delta)
