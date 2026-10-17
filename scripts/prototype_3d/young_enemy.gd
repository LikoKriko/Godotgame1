extends CharacterBody3D
const Motion=preload("res://scripts/prototype_3d/young_rig_motion.gd")
const SPEED:=1.7
const WANDER_SPEED:=0.85
const ALERT_RADIUS:=7.5
const WAKE_RADIUS:=20.0
const REACH:=0.65
const CREATURE_SPACING:=1.02
var body_radius:=0.27
const BOXING_CHANCE:=0.5
const BOXING_RETRY_SECONDS:=10.0
const BOXING_SECONDS:=20.0
var game
var model:Node3D
var brain=preload("res://scripts/prototype_3d/creature_brain.gd").new()
var effects=preload("res://scripts/status_effects.gd").new()
var indicator:MeshInstance3D
var health:=10.0
var loot_slots:Array[Dictionary]=[{},{},{},{},{},{},{},{}]
var corpse_area:Area3D
var phase:=0.0
var attack_elapsed:=-1.0
var impact_done:=false
var punch_left:=true
var rise_elapsed:=-1.0
var lower_elapsed:=-1.0
var standing:=false
# The first damaging hit arms one persistent ten-second schedule.
var damage_received:=0.0
var boxing_unlocked:=false
var boxing_check_remaining:=BOXING_RETRY_SECONDS
var boxing_remaining:=0.0
var attack_boxing:=false
var lower_from_boxing:=false
var death_elapsed:=-1.0
var avoid_remaining:=0.0
var avoid_direction:=Vector3.ZERO
var profile=preload("res://scripts/creature_profile.gd").new()
var hurt_area:=Area3D.new()
var hurt_shapes:Array[CollisionShape3D]=[]
var distance_suspended:=false
var suspended_visual:Dictionary={}
const VISUAL_STATE:=["last_pose","previous_state","interruption_pose","facial_open","facial_elapsed","facial_state","facial_phase","facial_close_time","facial_close_weights"]
func suspend_distance() -> void:
 if distance_suspended:return
 suspended_visual={"transform":model.transform,"visible":visible,"physics":is_physics_processing(),"layer":collision_layer,"mask":collision_mask,"hurt_layer":hurt_area.collision_layer,"corpse_layer":corpse_area.collision_layer if corpse_area!=null else 0,"state":{},"blend":[]}
 for key in VISUAL_STATE:
  var value=model.get(key)
  suspended_visual.state[key]=value.duplicate(true) if value is Dictionary or value is Array else value
 for i in model.mesh_node.mesh.get_blend_shape_count():suspended_visual.blend.append(model.mesh_node.get_blend_shape_value(i))
 var placeholder:=Node3D.new();placeholder.transform=model.transform
 model.free();model=placeholder;add_child(model)
 distance_suspended=true;collision_layer=0;collision_mask=0;hurt_area.collision_layer=0
 if corpse_area!=null:corpse_area.collision_layer=0
 hide();set_physics_process(false)
func resume_distance() -> void:
 if not distance_suspended:return
 var actor=preload("res://scripts/prototype_3d/young_model.gd").new();add_child(actor);actor.transform=suspended_visual.transform
 var state:Dictionary=suspended_visual.state
 if not state.last_pose.is_empty():actor.apply_pose(state.last_pose.duplicate(true))
 for key in VISUAL_STATE:actor.set(key,state[key])
 for i in suspended_visual.blend.size():actor.mesh_node.set_blend_shape_value(i,suspended_visual.blend[i])
 model.free();model=actor
 collision_layer=suspended_visual.layer;collision_mask=suspended_visual.mask;hurt_area.collision_layer=suspended_visual.hurt_layer
 if corpse_area!=null:corpse_area.collision_layer=suspended_visual.corpse_layer
 visible=suspended_visual.visible;set_physics_process(suspended_visual.physics)
 distance_suspended=false;suspended_visual.clear()
func configure(owner_game) -> void:
 game=owner_game;collision_layer=8;collision_mask=43;add_to_group("prototype_enemies");add_to_group("creatures")
 model=preload("res://scripts/prototype_3d/young_model.gd").new();add_child(model)
 var bounds:AABB=model.mesh_node.mesh.get_aabb();var unit:=0.875/bounds.size.y
 model.scale=Vector3.ONE*unit;model.position.y=-bounds.position.y*unit
 # A rotation-independent footprint encloses the model, including its off-centre
 # muzzle. The extra 2% is physical spacing, separate from damage hurtboxes.
 body_radius=maxf(maxf(absf(bounds.position.x),absf(bounds.end.x)),maxf(absf(bounds.position.z),absf(bounds.end.z)))*unit*CREATURE_SPACING
 var collision:=CollisionShape3D.new();var body:=CylinderShape3D.new()
 body.radius=body_radius;body.height=0.875;collision.shape=body;collision.position.y=body.height*0.5;add_child(collision)
 indicator=preload("res://scripts/prototype_3d/status_indicator.gd").new();add_child(indicator)
 profile.posture_seconds=0.28
 brain.body_radius=body_radius
 brain.configure(4127+get_tree().get_nodes_in_group("prototype_enemies").size(),profile);model.animate(&"idle",0)
 hurt_area.collision_layer=16;hurt_area.collision_mask=0;hurt_area.monitoring=false;hurt_area.set_meta("creature",self);add_child(hurt_area)
 for radius in [0.22,0.105,0.14,0.14]:
  var shape:=CollisionShape3D.new();var sphere:=SphereShape3D.new();sphere.radius=radius+0.15;shape.shape=sphere;hurt_area.add_child(shape);hurt_shapes.append(shape)
 update_hurtboxes()
func update_hurtboxes() -> void:
 if hurt_shapes.is_empty():return
 hurt_shapes[0].position=to_local(model.to_global(model.socket(&"head")))
 hurt_shapes[1].position=to_local(model.to_global(model.socket(&"snout")))
 hurt_shapes[2].position=to_local(model.to_global(model.socket(&"left_fist")))
 hurt_shapes[3].position=to_local(model.to_global(model.socket(&"right_fist")))
func clock_hour() -> float:
 var clock=game.get("day_cycle")
 return clock.hour if clock!=null else 12.0
func sees_player() -> bool:
 var radius:=WAKE_RADIUS if brain.night(clock_hour()) or brain.sleeping() else ALERT_RADIUS
 if global_position.distance_to(game.player.global_position)>radius or game.player_health<=0:return false
 var from:=global_position+Vector3.UP*0.48;var to:Vector3=game.player.global_position+Vector3.UP*0.7
 var query:=PhysicsRayQueryParameters3D.create(from,to,1,[get_rid()])
 return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func stun(seconds:float) -> void:
 effects.apply(&"stun",seconds);attack_elapsed=-1;rise_elapsed=-1;lower_elapsed=-1;standing=false
func take_damage(amount:float) -> void:
 if health<=0 or not is_finite(amount) or amount<=0:return
 var previous:=health
 health=maxf(0,health-amount)
 if health>=previous:return
 damage_received+=previous-health
 brain.alert_to(game.player.global_position)
 if health>0 and amount>0 and not boxing_unlocked:
  boxing_unlocked=true
  boxing_check_remaining=0.0 if brain.sleeping() else BOXING_RETRY_SECONDS
  if not brain.sleeping():roll_boxing()
 if health==0:
  boxing_remaining=0
  death_elapsed=0;collision_layer=0;collision_mask=0;hurt_area.collision_layer=0;effects.active.clear()
  loot_slots[0]=game.bag.make_item(&"cuero_sin_refinar",1)
func boxing_active() -> bool:return damage_received>0 and boxing_unlocked and health>0 and boxing_remaining>0
func roll_boxing() -> void:
 if damage_received<=0 or not boxing_unlocked or health<=0 or boxing_remaining>0 or brain.sleeping():return
 if brain.rng.randf()<BOXING_CHANCE:
  boxing_remaining=BOXING_SECONDS
  attack_elapsed=-1;lower_elapsed=-1;rise_elapsed=0;standing=false
func advance_boxing(delta:float) -> void:
 if damage_received<=0:boxing_unlocked=false
 if not boxing_unlocked:
  if attack_boxing:attack_elapsed=-1
  boxing_remaining=0;attack_boxing=false;lower_from_boxing=false
  return
 if brain.sleeping():return
 var was_boxing:=boxing_remaining>0
 boxing_remaining=maxf(0,boxing_remaining-delta)
 if was_boxing and boxing_remaining<=0:
  attack_elapsed=-1;rise_elapsed=-1;lower_elapsed=0;lower_from_boxing=true
 boxing_check_remaining-=delta
 while boxing_check_remaining<=0:
  boxing_check_remaining+=BOXING_RETRY_SECONDS
  roll_boxing()
func start_attack() -> void:
 attack_elapsed=0;impact_done=false;attack_boxing=boxing_active()
func attack_clip() -> StringName:
 return &"hook" if attack_boxing and boxing_active() else &"attack"
func obstacle(direction:Vector3) -> bool:
 var query:=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*0.35,global_position+Vector3.UP*0.35+direction*(body_radius+0.35),41,[get_rid()])
 return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func steer(direction:Vector3,delta:float) -> Vector3:
 avoid_remaining=maxf(0,avoid_remaining-delta)
 if avoid_remaining>0:return avoid_direction
 if not obstacle(direction):return direction
 var a:=direction.rotated(Vector3.UP,PI/3);var b:=direction.rotated(Vector3.UP,-PI/3)
 avoid_direction=a if not obstacle(a) else (b if not obstacle(b) else direction.rotated(Vector3.UP,PI*0.75))
 avoid_remaining=0.7;return avoid_direction
func _physics_process(delta:float) -> void:
 if game==null or game.paused or distance_suspended:return
 if health<=0:
  death_elapsed+=delta;model.animate(&"death" if death_elapsed<2 else &"corpse",minf(1,death_elapsed/2),punch_left,delta);indicator.hide()
  if death_elapsed>=2:ensure_corpse_area()
  if death_elapsed>=182:queue_free()
  return
 advance_boxing(delta)
 var stunned:=effects.remaining(&"stun")>0
 effects.advance(delta)
 if stunned:
  var remaining:float=effects.remaining(&"stun");var elapsed:=1.5-remaining
  var clip:StringName=&"stun_fall" if elapsed<0.24 else (&"stun_rise" if remaining<0.24 else &"stun_hold")
  var progress:float=elapsed/0.24 if clip==&"stun_fall" else (1-remaining/0.24 if clip==&"stun_rise" else 0)
  model.animate(clip,clampf(progress,0,1),true,delta)
  update_hurtboxes()
  indicator.position.y=model.position.y+(model.socket(&"head").y+.5)*model.scale.y+0.185
  indicator.show_status(remaining,1.5,Color("e6dfa6"),game.camera_rig.camera);return
 indicator.hide()
 var visible_player:=sees_player()
 var mode:StringName=brain.advance(delta,global_position,game.player.global_position,visible_player,get_tree().get_nodes_in_group("prototype_trees"),clock_hour())
 var distance:=global_position.distance_to(game.player.global_position)
 var clip:StringName=&"idle";var progress:=0.0;var direction:=Vector3.ZERO;var speed:=0.0
 if brain.sleeping():
  attack_elapsed=-1;rise_elapsed=-1;lower_elapsed=-1;standing=false;boxing_remaining=0;attack_boxing=false;lower_from_boxing=false
  clip=mode;progress=behaviour_phase(mode)
 elif attack_elapsed>=0:
  var duration:=Motion.seconds(attack_clip())
  var contact:=duration*.5
  attack_elapsed+=delta;clip=attack_clip();progress=minf(1,attack_elapsed/duration)
  if not impact_done and attack_elapsed>=contact:
   impact_done=true
   if distance<=maxf(REACH+0.15,body_radius+0.25) and visible_player:game.enemy_contact(self,4.0 if attack_boxing else 2.0,game.parry.time-maxf(0,attack_elapsed-contact))
  if attack_elapsed>=duration:
   punch_left=not punch_left
   if visible_player and distance<=maxf(REACH+0.15,body_radius+0.25):
    attack_elapsed=maxf(0,attack_elapsed-duration);impact_done=false;progress=attack_elapsed/duration
   else:
    attack_elapsed=-1
    if boxing_remaining<=0:lower_elapsed=0;lower_from_boxing=false
    else:clip=&"boxing_guard";progress=0
 elif rise_elapsed>=0:
  rise_elapsed+=delta;clip=&"boxing_rise" if boxing_remaining>0 else &"rise";progress=minf(1,rise_elapsed/0.28)
  if rise_elapsed>=0.28:rise_elapsed=-1;standing=true
  if rise_elapsed<0 and visible_player and distance<=maxf(REACH+.15,body_radius+.25):start_attack()
 elif lower_elapsed>=0:
  lower_elapsed+=delta;clip=&"boxing_lower" if lower_from_boxing else &"lower";progress=minf(1,lower_elapsed/0.28)
  if lower_elapsed>=0.28:lower_elapsed=-1;standing=false;lower_from_boxing=false
 elif visible_player and distance<maxf(REACH,body_radius+0.22):
  if standing:start_attack();clip=attack_clip()
  else:rise_elapsed=0;clip=&"boxing_rise" if boxing_remaining>0 else &"rise"
 elif mode in [&"chase",&"investigate",&"walk"]:
  direction=brain.goal-global_position;direction.y=0
  if direction.length()>0.1:direction=steer(direction.normalized(),delta)
  speed=WANDER_SPEED if mode==&"walk" else SPEED;clip=&"walk" if mode==&"walk" else &"run"
 else:
  clip=mode if mode in [&"sit_down",&"sit",&"sit_up",&"feed"] else &"idle"
  progress=behaviour_phase(clip)
  if clip==&"feed" and is_instance_valid(brain.tree):
   var toward:Vector3=brain.tree.global_position-global_position
   if toward.length()>0.001:model.rotation.y=lerp_angle(model.rotation.y,atan2(toward.x,toward.z),1-exp(-delta*7))
 if boxing_active() and clip in [&"idle",&"sit_down",&"sit",&"sit_up",&"feed",&"walk",&"run"]:
  if not standing:rise_elapsed=0;clip=&"boxing_rise";progress=0;direction=Vector3.ZERO;speed=0
  else:clip=&"boxing_walk" if speed>0 else &"boxing_guard"
 velocity.x=direction.x*speed;velocity.z=direction.z*speed
 if not is_on_floor():velocity.y-=18*delta
 var before_move:=global_position
 move_and_slide()
 if clip in [&"walk",&"run",&"boxing_walk"]:
  var travelled:=Vector2(global_position.x-before_move.x,global_position.z-before_move.z).length()
  var cycle_distance:float=Motion.seconds(clip)*(Motion.WALK_SPEED if clip==&"walk" else Motion.RUN_SPEED)
  phase=fposmod(phase+travelled/cycle_distance,1);progress=phase
 if direction.length_squared()>0.01:model.rotation.y=lerp_angle(model.rotation.y,atan2(direction.x,direction.z),1-exp(-delta*7))
 elif clip in [&"attack",&"rise",&"hook",&"boxing_rise",&"boxing_guard"]:
  var toward:Vector3=game.player.global_position-global_position
  if toward.length()>0.001:model.rotation.y=lerp_angle(model.rotation.y,atan2(toward.x,toward.z),1-exp(-delta*7))
 model.animate(clip,progress,punch_left,delta)
 update_hurtboxes()

func behaviour_phase(clip:StringName) -> float:
 return fposmod(brain.elapsed/Motion.seconds(clip),1) if clip in [&"idle",&"sit",&"feed",&"sleep"] else minf(1,brain.elapsed/Motion.seconds(clip))
func ensure_corpse_area() -> void:
 if corpse_area!=null:return
 corpse_area=Area3D.new();corpse_area.collision_layer=16;corpse_area.collision_mask=0;corpse_area.monitoring=false;corpse_area.set_meta("creature",self);add_child(corpse_area)
 var shape:=CollisionShape3D.new();var volume:=BoxShape3D.new();var bounds:=AABB(to_local(model.to_global(model.posed[0].origin)),Vector3.ZERO)
 for transform in model.posed:bounds=bounds.expand(to_local(model.to_global(transform.origin)))
 bounds=bounds.expand(to_local(model.to_global(model.socket(&"snout")))).grow(.15)
 volume.size=bounds.size;shape.shape=volume;shape.position=bounds.get_center();corpse_area.add_child(shape)
func restore_presentation() -> void:
 advance_boxing(0)
 if health<=0:
  collision_layer=0;collision_mask=0;hurt_area.collision_layer=0
  model.animate(&"death" if death_elapsed<2 else &"corpse",minf(1,death_elapsed/2))
  if death_elapsed>=2:ensure_corpse_area()
 elif effects.remaining(&"stun")>0:
  var remaining:float=effects.remaining(&"stun");var elapsed:=1.5-remaining
  var clip:StringName=&"stun_fall" if elapsed<0.24 else (&"stun_rise" if remaining<0.24 else &"stun_hold")
  model.animate(clip,clampf(elapsed/0.24 if clip==&"stun_fall" else (1-remaining/0.24 if clip==&"stun_rise" else 0),0,1))
 elif brain.sleeping():model.animate(brain.mode,behaviour_phase(brain.mode),punch_left)
 elif attack_elapsed>=0:model.animate(attack_clip(),attack_elapsed/Motion.seconds(attack_clip()),punch_left)
 elif rise_elapsed>=0:model.animate(&"boxing_rise" if boxing_remaining>0 else &"rise",rise_elapsed/0.28,punch_left)
 elif lower_elapsed>=0:model.animate(&"boxing_lower" if lower_from_boxing else &"lower",lower_elapsed/0.28,punch_left)
 elif boxing_active():model.animate(&"boxing_guard",phase,punch_left)
 else:
  var clip:StringName=brain.mode if brain.mode in [&"sit_down",&"sit",&"sit_up",&"feed",&"walk"] else (&"run" if brain.mode in [&"chase",&"investigate"] else &"idle")
  model.animate(clip,phase if clip in [&"walk",&"run"] else behaviour_phase(clip),punch_left)
 update_hurtboxes()
