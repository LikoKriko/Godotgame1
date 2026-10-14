extends CharacterBody3D
const SPEED := 2.0
const RUN_MULTIPLIER := 1.6
const GRAVITY := 18.0
const Anatomy = preload("res://scripts/prototype_3d/survivor_anatomy.gd")
const Clips = preload("res://scripts/prototype_3d/survivor_animation.gd")
const WORLD_SCALE := Anatomy.HEIGHT_METRES/64.0
var game
var model: Node3D
var phase := 0.0
var equipped := true
var action_elapsed := -1.0
var equip_elapsed := -1.0
var unequipping:=false
var equip_recovery:=0.0
var contact_done := false
var action_heading := 0.0
var action_target: Dictionary = {}
var locomotion = preload("res://scripts/locomotion.gd").new()
var jump_was_pressed := false
var control_was_pressed := false
var parry_elapsed := -1.0
var parry_cooldown := 0.0
var preview_state: StringName = &""
var preview_elapsed := 0.0
var preview_family: StringName = &""
var action_point := Vector3.ZERO
var death_elapsed:=-1.0
var guard_point:=Vector3.INF
const ACTION_SECONDS := 0.75
func configure(owner_game) -> void:
 game = owner_game
 var capsule := CapsuleShape3D.new(); capsule.radius = 0.20; capsule.height = Anatomy.HEIGHT_METRES
 var collision := CollisionShape3D.new(); collision.shape = capsule; collision.position.y = 0.875; add_child(collision)
 collision_layer = 2; collision_mask = 9
 model = preload("res://scripts/prototype_3d/survivor_model.gd").new(); add_child(model)
 var bounds: AABB=model.mesh_node.mesh.get_aabb()
 var unit:=Anatomy.HEIGHT_METRES/bounds.size.y
 model.scale=Vector3.ONE*unit;model.position.y=-bounds.position.y*unit;model.rotation.y=PI
 model.animate(&"idle",0,equipped)
func toggle_tool() -> void:
 if action_elapsed >= 0: return
 if game.bag.quick_slots[0].get("id",&"")!=&"axe":game.status.text="Acceso rápido vacío";return
 equipped = not equipped; equip_elapsed = 0;unequipping=not equipped
 if equipped:equip_recovery=1.0
 game.bag.active_quick_uid=game.bag.quick_slots[0].uid if equipped else -1
func strike() -> bool:
 if action_elapsed >= 0 or equip_elapsed >= 0 or game.player_health<=0: return false
 action_elapsed = 0; contact_done = false
 action_target = game.camera_rig.target()
 action_point = game.camera_rig.aim_point()
 var forward: Vector3 = action_point-global_position
 action_heading = atan2(forward.x,forward.z)
 return true
func can_reach_contact(point: Vector3) -> bool:
 if not equipped:
  var local_point:=model.to_local(point)
  return local_point.distance_to(model.rig.posed[7].origin)<18.6
 return model.can_reach_contact(model.to_local(point))
func begin_parry() -> bool:
 if action_elapsed>=0:return false
 parry_elapsed=0;parry_cooldown=4.0;return true
func play_preview(family: StringName,state: StringName) -> void:
 preview_family=family;preview_state=state;preview_elapsed=0
func _physics_process(delta: float) -> void:
 if game == null or game.paused: return
 if game.player_health<=0:
  death_elapsed=maxf(0,death_elapsed)+delta;model.family_override=&"";model.aim_contact=Vector3.INF
  model.animate(&"death",minf(1,death_elapsed/3),false,delta);game.camera_rig.update(delta)
  if death_elapsed>=3 and not game.paused:game.toggle_pause()
  return
 parry_cooldown=maxf(0,parry_cooldown-delta)
 equip_recovery=maxf(0,equip_recovery-delta)
 var input := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
 var direction: Vector3 = game.camera_rig.movement_direction(input)
 var control := Input.is_physical_key_pressed(KEY_CTRL)
 var running: bool = (Input.is_physical_key_pressed(KEY_SHIFT) or game.settings.values.auto_run) and action_elapsed < 0 and not input.is_zero_approx()
 if preview_state in [&"eat",&"eat_walk",&"drink",&"drink_walk"]:running=false
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
 var movement_multiplier:float=game.nutrition.speed_multiplier()*game.progression.speed_multiplier()*(1-0.05*equip_recovery)
 var speed:float = SPEED*(RUN_MULTIPLIER if running else 1.0)*movement_multiplier
 var planar: Vector2 = locomotion.velocity(Vector2(direction.x,direction.z)*speed,WORLD_SCALE)
 if locomotion.from_slide: planar *= WORLD_SCALE
 velocity.x = planar.x; velocity.z = planar.y
 if not is_on_floor(): velocity.y -= GRAVITY*delta
 move_and_slide()
 var forward: Vector3 = game.camera_rig.facing()
 model.rotation.y = lerp_angle(model.rotation.y,action_heading if action_elapsed >= 0 else atan2(forward.x,forward.z),1-exp(-delta*15))
 var state: StringName = &"idle"; var progress := 0.0
 if input.length_squared()>0:
  phase = fposmod(phase+delta/(0.45 if running else 0.60)*locomotion.speed_factor()*movement_multiplier,1)
 if action_elapsed >= 0:
  action_elapsed += delta; state = &"action"; progress = clampf(action_elapsed/ACTION_SECONDS,0,1)
  if not contact_done and progress >= 0.5: contact_done = true; game.resolve_hit(action_target)
  if action_elapsed >= ACTION_SECONDS: action_elapsed = -1
 elif parry_elapsed>=0:
  parry_elapsed+=delta;state=&"parry";progress=clampf(parry_elapsed/0.5,0,1)
  if parry_elapsed>=0.5:parry_elapsed=-1
 elif locomotion.sliding():
  state = &"slide"; progress = locomotion.slide_elapsed/locomotion.SLIDE_SECONDS
 elif not is_on_floor():
  state = &"slide_jump" if locomotion.from_slide else &"jump"
  progress = locomotion.jump_elapsed/locomotion.JUMP_SECONDS
 elif equip_elapsed >= 0:
  equip_elapsed += delta; state = &"equip"; progress = clampf(equip_elapsed/0.42,0,1)
  if input.length_squared()>0:
   state = &"equip_crouch_walk" if locomotion.crouch>0.01 else (&"equip_run" if running else &"equip_walk")
  if unequipping:state=&"unequip"
  if equip_elapsed >= 0.42: equip_elapsed = -1
 elif input.length_squared() > 0:
  state = &"crouch_walk" if locomotion.crouch>0.01 else (&"run" if running else &"walk")
  progress = phase
 elif locomotion.crouch>0:
  state = &"crouch"; progress = locomotion.crouch
 if state==&"idle":progress=fposmod(Time.get_ticks_msec()/4000.0,1)
 model.family_override=&"default"
 if preview_state!=&"":
  preview_elapsed+=delta;model.family_override=preview_family;state=preview_state
  if state in [&"eat",&"drink"] and input.length_squared()>0:state=StringName(String(state)+"_walk")
  progress=clampf(preview_elapsed/Clips.duration(state,preview_family),0,1)
  if progress>=1:preview_state=&""
 model.aim_contact=model.to_local(action_point) if state==&"action" else Vector3.INF
 if state==&"parry" and guard_point.is_finite():model.aim_contact=model.to_local(guard_point)
 var local_travel: Vector3 = (model.global_basis.inverse()*direction).normalized()
 model.animate(state,progress,equipped or (unequipping and state==&"unequip"),delta,phase,local_travel)
 game.camera_rig.update(delta)
