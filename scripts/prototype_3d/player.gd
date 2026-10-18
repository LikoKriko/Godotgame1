extends CharacterBody3D
const SPEED := 2.0
const RUN_MULTIPLIER := preload("res://scripts/prototype_3d/movement_response.gd").SPRINT_MULTIPLIER
const GRAVITY := 18.0
const Anatomy = preload("res://scripts/prototype_3d/survivor_anatomy.gd")
const Clips = preload("res://scripts/prototype_3d/survivor_animation.gd")
const WORLD_SCALE := Anatomy.HEIGHT_METRES/64.0
var game
var model: Node3D
var phase := 0.0
var equipped := true
var action_elapsed := -1.0
var bow_follow_elapsed:=-1.0
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
var action_family:StringName=&"axe"
var action_uid:=-1
var stowed_family:StringName=&"axe"
var pickup_recovery:=0.0
var pickup_target:Dictionary={}
var pickup_point:=Vector3.INF
var pickup_completed:=false
var visual_motion:=0.0
var facing_history=preload("res://scripts/prototype_3d/facing_delay.gd").new()
var delayed_aim:=Vector3.INF
var movement_response=preload("res://scripts/prototype_3d/movement_response.gd").new()
var slide_backward:=false
var slide_side:=0
var slide_forward_axis:=1
var slide_facing:=0.0
var punch_side:=1
var next_punch_side:=1
static func attack_speed_scale(elapsed:float,attack_family:StringName) -> float:
 if elapsed<0 or attack_family==&"bow":return 1.0
 var seconds:=Clips.duration(&"action",attack_family)
 # Ease into the extra slowdown during preparation and out during recovery.
 var effort:=smoothstep(0,.08,elapsed)*(1-smoothstep(seconds-.12,seconds,elapsed))
 return lerpf(1.0,.5,effort)

func reset_motion_state() -> void:
 if game.camera_rig!=null:game.camera_rig.reset_free_look()
 locomotion.reset();velocity=Vector3.ZERO;visual_motion=0
 movement_response=preload("res://scripts/prototype_3d/movement_response.gd").new()
 facing_history=preload("res://scripts/prototype_3d/facing_delay.gd").new()
 facing_history.sample(model.basis.z*4,0)
 slide_backward=false;slide_side=0;slide_forward_axis=1;slide_facing=model.rotation.y
func configure(owner_game) -> void:
 game = owner_game
 var capsule := CapsuleShape3D.new(); capsule.radius = 0.20; capsule.height = Anatomy.HEIGHT_METRES
 var collision := CollisionShape3D.new(); collision.shape = capsule; collision.position.y = 0.875; add_child(collision)
 collision_layer = 2; collision_mask = 9
 model = preload("res://scripts/prototype_3d/survivor_model.gd").new(); add_child(model)
 var bounds: AABB=model.author_bounds()
 var unit:=Anatomy.HEIGHT_METRES/bounds.size.y
 model.scale=Vector3.ONE*unit;model.position.y=-bounds.position.y*unit;model.rotation.y=PI
 model.animate(&"idle",0,equipped)
 facing_history.sample(model.basis.z*4,0)
func family() -> StringName:
 if not equipped:return &""
 var item:Dictionary=game.bag.held_item()
 if item.is_empty():return &""
 if game.bag.DEFINITIONS[item.id].has("kcal"):return &"food"
 var category:StringName=game.bag.held_category()
 return category if category in Clips.FAMILIES else &"carried"
func toggle_tool() -> void:select_quick(0)
func select_quick(index:int) -> bool:
 if action_elapsed>=0 or preview_state==&"pickup" or not game.pending_consumption.is_empty() or game.player_health<=0:return false
 var item:Dictionary=game.bag.at(&"quick",index)
 if item.is_empty():game.status.text="Acceso rápido vacío";return false
 var definition:Dictionary=game.bag.DEFINITIONS[item.id]
 if definition.slot!=&"tool" and not definition.has("kcal"):game.status.text="Este material se guarda en la barra, pero no se usa en la mano.";return false
 model.begin_equipment_transition()
 stowed_family=family()
 if game.bag.active_quick_uid==item.uid:game.bag.active_quick_uid=-1;equipped=false
 else:game.bag.active_quick_uid=item.uid;equipped=true;equip_recovery=1.0
 equip_elapsed=0;unequipping=not equipped
 return true
func strike() -> bool:
 if action_elapsed>=0 or equip_elapsed>=0 or parry_elapsed>=0 or preview_state!=&"" or game.player_health<=0:return false
 var item:Dictionary=game.bag.held_item() if equipped else {}
 if item.get("id")==&"basic_workbench":
  var target:Dictionary=game.camera_rig.target()
  return not target.is_empty() and game.workbenches.begin_placement(target.position)
 if not item.is_empty() and (item.id==&"botella" or game.bag.DEFINITIONS[item.id].has("kcal")):
  var location:Dictionary=game.bag.location(item.uid)
  return game.consume_item(location.index,location.kind==&"quick")
 action_family=family()
 if action_family not in [&"",&"axe",&"pickaxe",&"sword",&"bow"]:return false
 if action_family!=&"bow" and (not is_on_floor() or locomotion.airborne()):return false
 if not item.is_empty() and item.uses<=0:game.status.text="El objeto está roto; repáralo.";return false
 if action_family==&"bow":
  if game.bag.count(&"flecha")<=0:game.status.text="Necesitas flechas para disparar el arco";return false
  game.bag.consume_use()
 if action_family==&"":
  punch_side=next_punch_side;next_punch_side=1-next_punch_side
  model.punch_side=punch_side
 action_uid=item.get("uid",-1)
 action_elapsed=0;contact_done=false;bow_follow_elapsed=-1
 var aim:Dictionary=game.camera_rig.aim_sample() if action_family==&"bow" else game.camera_rig.action_sample()
 action_target=aim.hit;action_point=aim.point
 action_heading=heading_to(action_point)
 return true
func heading_to(point:Vector3) -> float:
 var toward:=Vector2(point.x-global_position.x,point.z-global_position.z)
 # At the vertical poles the reticle can be directly over our own feet. Keep
 # camera yaw there instead of making tiny surface offsets flip the whole body.
 if toward.length_squared()<.04:
  var forward:Vector3=game.camera_rig.facing()
  return atan2(forward.x,forward.z)
 return atan2(toward.x,toward.y)
func update_facing(point:Vector3,delta:float) -> void:
 delayed_aim=global_position+facing_history.sample(point-global_position,delta)
 var contact:Vector3=pickup_point if preview_state==&"pickup" and pickup_point.is_finite() else delayed_aim
 var visual_heading:=heading_to(action_point if action_elapsed>=0 else contact)
 if action_elapsed>=0:action_heading=visual_heading
 elif locomotion.sliding():visual_heading=slide_facing
 elif locomotion.airborne() and locomotion.from_slide:visual_heading=slide_facing-wrapf(locomotion.jump_heading-locomotion.launch_heading,-PI,PI)
 model.rotation.y=lerp_angle(model.rotation.y,visual_heading,1-exp(-maxf(0,delta)*15))
func advance_action(delta:float) -> void:
 if action_elapsed<0:return
 if action_family!=&"bow" and (not is_on_floor() or locomotion.airborne()):
  cancel_action();return
 var seconds:=0.5 if action_family==&"bow" else Clips.duration(&"action",action_family)
 action_elapsed+=maxf(0,delta)
 var impact_time:=seconds if action_family==&"bow" else seconds*0.5
 if not contact_done and action_elapsed+0.000001>=impact_time:
  contact_done=true
  if action_family==&"bow":
   action_point=game.camera_rig.aim_point()
   model.family_override=&"bow";model.aim_contact=model.to_local(action_point);model.nock_visible=true
   model.animate(&"draw",1,true)
   game.release_arrow(action_point,action_uid)
   bow_follow_elapsed=0
  else:game.resolve_hit(action_target)
 if action_elapsed+0.000001>=seconds:action_elapsed=-1
func cancel_action() -> void:
 action_elapsed=-1;contact_done=false;bow_follow_elapsed=-1
func can_reach_contact(point: Vector3) -> bool:
 # Gameplay reach is independent of the pose/weapon IK solver.
 var offset:=point-global_position
 return Vector2(offset.x,offset.z).length()<=1.0 and offset.y>=-0.35 and offset.y<=Anatomy.HEIGHT_METRES+0.35
func begin_parry() -> bool:
 if action_elapsed>=0:return false
 parry_elapsed=0;parry_cooldown=4.0;return true
func begin_pickup(result:Dictionary) -> bool:
 var point:Vector3=result.position
 var heading:=heading_to(point)
 var local_point:Vector3=Basis(Vector3.UP,heading).inverse()*(point-model.global_position)/model.scale.x
 var contact_pose:=Clips.sample(&"",&"pickup",0.5,0,Vector3.ZERO,local_point)
 if not contact_pose.contact_reachable:
  game.status.text="Acércate para recogerlo con la mano.";return false
 play_preview(&"",&"pickup")
 pickup_target=result.duplicate();pickup_point=point;pickup_completed=false
 return true
func advance_preview(delta:float,moving:bool=false) -> Dictionary:
 var state:=preview_state
 if state==&"":return {}
 preview_elapsed+=maxf(0,delta)
 if state in [&"eat",&"drink",&"pickup"] and moving:state=StringName(String(state)+"_walk")
 var progress:=clampf(preview_elapsed/Clips.duration(state,preview_family),0,1)
 if preview_state==&"pickup" and not pickup_completed and progress>=0.5:
  pickup_completed=true
  if not pickup_target.is_empty():game.complete_pickup(pickup_target,pickup_point)
 if progress>=1:
  if preview_state==&"pickup":pickup_recovery=0.5
  preview_state=&"";pickup_target={}
 return {"state":state,"phase":progress}
func play_preview(family: StringName,state: StringName) -> void:
 preview_family=family;preview_state=state;preview_elapsed=0
 pickup_point=Vector3.INF;pickup_target={};pickup_completed=false
func slide_clip() -> StringName:
 if not slide_backward:
  if slide_side==0:return &"slide"
  if slide_forward_axis==0:return &"slide_left" if slide_side<0 else &"slide_right"
  return &"slide_forward_left" if slide_side<0 else &"slide_forward_right"
 return &"slide_back_left" if slide_side<0 else (&"slide_back_right" if slide_side>0 else &"slide_back")
func _physics_process(delta: float) -> void:
 if game == null or game.paused: return
 if game.player_health<=0:
  death_elapsed=maxf(0,death_elapsed)+delta;model.family_override=&"";model.aim_contact=Vector3.INF
  model.animate(&"death",minf(1,death_elapsed/3),false,delta);game.camera_rig.update(delta)
  if death_elapsed>=3 and not game.paused:game.toggle_pause()
  return
 if game.workbenches!=null and game.workbenches.placing():
  velocity=Vector3.ZERO;model.family_override=&"carried";model.animate(&"idle",0,false,delta);game.camera_rig.update(delta);return
 parry_cooldown=maxf(0,parry_cooldown-delta)
 equip_recovery=maxf(0,equip_recovery-delta)
 pickup_recovery=maxf(0,pickup_recovery-delta)
 var input := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
 var direction: Vector3 = game.camera_rig.movement_direction(input)
 var control := Input.is_physical_key_pressed(KEY_CTRL)
 var running: bool = (Input.is_physical_key_pressed(KEY_SHIFT) or game.settings.values.auto_run) and action_elapsed < 0 and not input.is_zero_approx()
 if preview_state in [&"eat",&"eat_walk",&"drink",&"drink_walk"]:running=false
 if control and not control_was_pressed and running and is_on_floor():
  var backward:=input.y>0
  if locomotion.slide(Vector2(direction.x,direction.z),.6 if backward else 1.0):
   slide_backward=backward
   slide_side=int(signf(input.x));slide_forward_axis=-int(signf(input.y))
   var forward:Vector3=game.camera_rig.movement_direction(Vector2.UP)
   slide_facing=atan2(forward.x,forward.z)
 control_was_pressed = control
 var jump_pressed := Input.is_physical_key_pressed(KEY_SPACE)
 if jump_pressed and not jump_was_pressed and is_on_floor():
  if locomotion.jump():
   velocity.y = 5.5
   if action_elapsed>=0 and action_family!=&"bow":cancel_action()
 jump_was_pressed = jump_pressed
 locomotion.steer_air(Vector2(direction.x,direction.z),delta)
 locomotion.advance(delta,control and not locomotion.sliding())
 model.action_crouch=locomotion.crouch if is_on_floor() else 0.0
 running = running and locomotion.crouch < 0.01
 var movement_multiplier:float=game.nutrition.speed_multiplier()*game.progression.speed_multiplier()*(1-0.05*equip_recovery)
 movement_multiplier*=0.4 if preview_state==&"pickup" else 1-0.6*pickup_recovery/0.5
 var walk_scale:float=movement_response.walking_multiplier(input)
 var response:Vector2=movement_response.advance(Vector2(direction.x,direction.z),running,locomotion.crouch,delta,walk_scale)
 var planar:Vector2=response*SPEED*movement_multiplier*attack_speed_scale(action_elapsed,action_family)
 if locomotion.sliding() or (locomotion.airborne() and locomotion.from_slide):planar=locomotion.velocity(planar,WORLD_SCALE)
 if locomotion.from_slide: planar *= WORLD_SCALE
 if locomotion.airborne() and not game.can_cross_jump(global_position,Vector3(planar.x,0,planar.y)*delta,get_rid()):planar=Vector2.ZERO
 velocity.x = planar.x; velocity.z = planar.y
 if not is_on_floor(): velocity.y -= GRAVITY*delta
 var before_move:=global_position
 move_and_slide()
 # Also cover leaving a ledge or loading a melee windup while in the air.
 if action_elapsed>=0 and action_family!=&"bow" and (not is_on_floor() or locomotion.airborne()):cancel_action()
 game.camera_rig.update(delta)
 var live_aim:Vector3=game.camera_rig.aim_point()
 if action_elapsed>=0 and action_family==&"bow":
  action_point=live_aim
 update_facing(live_aim,delta)
 if bow_follow_elapsed>=0:
  bow_follow_elapsed+=delta
  if bow_follow_elapsed>=Clips.duration(&"bow_release") or family()!=&"bow" or not equipped:bow_follow_elapsed=-1
 var state: StringName = &"idle"; var progress := 0.0
 var travelled:=Vector2(global_position.x-before_move.x,global_position.z-before_move.z).length()
 var actual_speed:=travelled/maxf(delta,.00001)
 var local_travel:Vector3=model.global_basis.inverse()*(global_position-before_move)
 local_travel.y=0
 local_travel=local_travel.normalized()
 if actual_speed>0.03:
  # Visual gait tuning shares one clock for feet, arms and torso.
  phase=fposmod(phase+travelled*Clips.gait_playback_rate(movement_response.sprint_weight)/Clips.cycle_distance(movement_response.sprint_weight,locomotion.crouch,local_travel),1)

 visual_motion=clampf(actual_speed/maxf(SPEED*movement_multiplier*walk_scale*(.48 if locomotion.crouch>.99 else 1.0),.01),0,1)
 model.sprint_weight=movement_response.sprint_weight
 model.sprint_crouch=locomotion.crouch
 if action_elapsed >= 0:
  state=&"draw" if action_family==&"bow" else &"action"
  var seconds:=0.5 if action_family==&"bow" else Clips.duration(state,action_family)
  progress=clampf((action_elapsed+delta)/seconds,0,1)
  advance_action(delta)
 elif parry_elapsed>=0:
  parry_elapsed+=delta;state=&"parry";progress=clampf(parry_elapsed/0.5,0,1)
  if parry_elapsed>=0.5:parry_elapsed=-1
 elif locomotion.sliding():
  state = slide_clip(); progress = locomotion.slide_elapsed/locomotion.SLIDE_SECONDS
 elif not is_on_floor():
  state = &"slide_jump" if locomotion.from_slide else &"jump"
  progress = locomotion.jump_elapsed/locomotion.JUMP_SECONDS
 elif equip_elapsed >= 0:
  equip_elapsed += delta; state = &"equip_crouch" if locomotion.crouch>0.01 else &"equip"; progress = clampf(equip_elapsed/Clips.duration(&"equip",family()),0,1)
  if input.length_squared()>0:
   state = &"equip_crouch_walk" if locomotion.crouch>0.01 else (&"equip_run" if running else &"equip_walk")
  if unequipping:state=&"unequip"
  if equip_elapsed >= Clips.duration(&"equip",family()): equip_elapsed = -1
 elif movement_response.stage==&"start":state=&"start_run";progress=movement_response.phase()
 elif movement_response.stage==&"brake" and actual_speed>.01:state=&"stop_run";progress=movement_response.phase()
 elif input.length_squared() > 0:
  state = &"crouch_walk" if locomotion.crouch>0.01 else (&"run" if running else &"walk")
  progress = phase
 elif locomotion.crouch>0:
  state = &"crouch"; progress = locomotion.crouch
 if state==&"idle":progress=fposmod(Time.get_ticks_msec()/4000.0,1)
 model.family_override=stowed_family if state==&"unequip" else family()
 var held:Dictionary=game.bag.held_item()
 model.displayed_item=held.get("id",&"")
 model.item_water_ml=held.get("water_ml",0)
 model.nock_visible=state==&"draw" and not contact_done
 if bow_follow_elapsed>=0 and state not in [&"idle",&"walk",&"crouch",&"crouch_walk",&"draw"]:bow_follow_elapsed=-1
 if bow_follow_elapsed>=0 and action_elapsed<0 and state in [&"idle",&"walk",&"crouch",&"crouch_walk"]:
  state=&"bow_release";progress=bow_follow_elapsed/Clips.duration(&"bow_release")
 if preview_state!=&"":
  model.family_override=preview_family;state=preview_state
  model.displayed_item=game.pending_consumption.get("id",&"apple")
  model.item_water_ml=game.bag.item_by_uid(game.pending_consumption.get("uid",-1)).get("water_ml",0)
  var preview:Dictionary=advance_preview(delta,input.length_squared()>0)
  state=preview.state;progress=preview.phase
 model.aim_contact=model.to_local(action_point) if state in [&"action",&"draw"] else Vector3.INF
 if family()==&"bow" and equipped:model.aim_contact=model.to_local(live_aim if state in [&"action",&"draw"] else delayed_aim)
 if state==&"parry" and guard_point.is_finite():model.aim_contact=model.to_local(guard_point)
 if state in [&"pickup",&"pickup_walk"] and pickup_point.is_finite():model.aim_contact=model.to_local(pickup_point)
 model.animate(state,progress,equipped or (unequipping and state==&"unequip"),delta,phase,local_travel,visual_motion)
 _finish_visual_frame(state,progress)

func _finish_visual_frame(state:StringName,progress:float) -> void:
 if game.combat_effects!=null:
  game.combat_effects.track_tip(model.tip_socket.global_position,state==&"action" and action_family==&"sword" and progress>=0.25 and progress<=0.8)
