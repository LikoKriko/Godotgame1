extends CharacterBody3D
const Motion=preload("res://scripts/prototype_3d/young_pose.gd")
const SPEED:=1.7
const WANDER_SPEED:=0.85
const ALERT_RADIUS:=7.5
const REACH:=0.65
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
func configure(owner_game) -> void:
 game=owner_game;collision_layer=8;collision_mask=35;add_to_group("prototype_enemies");add_to_group("creatures")
 var collision:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=0.27;capsule.height=0.65;collision.shape=capsule;collision.position.y=0.325;add_child(collision)
 model=preload("res://scripts/prototype_3d/young_model.gd").new();add_child(model)
 var bounds:AABB=model.mesh_node.mesh.get_aabb();var unit:=0.875/bounds.size.y
 model.scale=Vector3.ONE*unit;model.position.y=-bounds.position.y*unit
 indicator=preload("res://scripts/prototype_3d/status_indicator.gd").new();add_child(indicator)
 profile.posture_seconds=0.28
 brain.configure(4127+get_tree().get_nodes_in_group("prototype_enemies").size(),profile);model.animate(&"idle",0)
 hurt_area.collision_layer=16;hurt_area.collision_mask=0;hurt_area.monitoring=false;hurt_area.set_meta("creature",self);add_child(hurt_area)
 for radius in [0.22,0.105,0.14,0.14]:
  var shape:=CollisionShape3D.new();var sphere:=SphereShape3D.new();sphere.radius=radius;shape.shape=sphere;hurt_area.add_child(shape);hurt_shapes.append(shape)
 update_hurtboxes()
func update_hurtboxes() -> void:
 if hurt_shapes.is_empty():return
 hurt_shapes[0].position=to_local(model.to_global(model.posed[1].origin))
 hurt_shapes[1].position=to_local(model.to_global(model.posed[1]*preload("res://scripts/prototype_3d/young_pose.gd").SNOUT_OFFSET))
 hurt_shapes[2].position=to_local(model.to_global(model.posed[10].origin))
 hurt_shapes[3].position=to_local(model.to_global(model.posed[13].origin))
func sees_player() -> bool:
 if global_position.distance_to(game.player.global_position)>ALERT_RADIUS or game.player_health<=0:return false
 var from:=global_position+Vector3.UP*0.48;var to:Vector3=game.player.global_position+Vector3.UP*0.7
 var query:=PhysicsRayQueryParameters3D.create(from,to,1,[get_rid()])
 return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func stun(seconds:float) -> void:
 effects.apply(&"stun",seconds);attack_elapsed=-1;rise_elapsed=-1;lower_elapsed=-1;standing=false
func take_damage(amount:float) -> void:
 if health<=0:return
 health=maxf(0,health-amount)
 if health>0 and amount>0 and not boxing_unlocked:
  boxing_unlocked=true
  boxing_check_remaining=BOXING_RETRY_SECONDS
  roll_boxing()
 if health==0:
  boxing_remaining=0
  death_elapsed=0;collision_layer=0;collision_mask=0;hurt_area.collision_layer=0;effects.active.clear()
  loot_slots[0]=game.bag.make_item(&"cuero_sin_refinar",1)
func roll_boxing() -> void:
 if boxing_remaining>0:return
 if brain.rng.randf()<BOXING_CHANCE:
  boxing_remaining=BOXING_SECONDS
  attack_elapsed=-1;lower_elapsed=-1;rise_elapsed=0;standing=false
func advance_boxing(delta:float) -> void:
 if not boxing_unlocked:return
 var was_boxing:=boxing_remaining>0
 boxing_remaining=maxf(0,boxing_remaining-delta)
 if was_boxing and boxing_remaining<=0:
  attack_elapsed=-1;rise_elapsed=-1;lower_elapsed=0;lower_from_boxing=true
 boxing_check_remaining-=delta
 while boxing_check_remaining<=0:
  boxing_check_remaining+=BOXING_RETRY_SECONDS
  roll_boxing()
func start_attack() -> void:
 attack_elapsed=0;impact_done=false;attack_boxing=boxing_remaining>0
func attack_clip() -> StringName:
 return &"hook" if attack_boxing else &"attack"
func obstacle(direction:Vector3) -> bool:
 var query:=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*0.35,global_position+Vector3.UP*0.35+direction*0.75,33,[get_rid()])
 return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func steer(direction:Vector3,delta:float) -> Vector3:
 avoid_remaining=maxf(0,avoid_remaining-delta)
 if avoid_remaining>0:return avoid_direction
 if not obstacle(direction):return direction
 var a:=direction.rotated(Vector3.UP,PI/3);var b:=direction.rotated(Vector3.UP,-PI/3)
 avoid_direction=a if not obstacle(a) else (b if not obstacle(b) else direction.rotated(Vector3.UP,PI*0.75))
 avoid_remaining=0.7;return avoid_direction
func _physics_process(delta:float) -> void:
 if game==null or game.paused:return
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
  indicator.position.y=model.position.y+(model.posed[1].origin.y+10)*model.scale.y+0.185
  indicator.show_status(remaining,1.5,Color("e6dfa6"),game.camera_rig.camera);return
 indicator.hide()
 var visible_player:=sees_player()
 var mode:StringName=brain.advance(delta,global_position,game.player.global_position,visible_player,get_tree().get_nodes_in_group("prototype_trees"))
 var distance:=global_position.distance_to(game.player.global_position)
 var clip:StringName=&"idle";var progress:=0.0;var direction:=Vector3.ZERO;var speed:=0.0
 if attack_elapsed>=0:
  var duration:=Motion.seconds(attack_clip())
  var contact:=duration*.5
  attack_elapsed+=delta;clip=attack_clip();progress=minf(1,attack_elapsed/duration)
  if not impact_done and attack_elapsed>=contact:
   impact_done=true
   if distance<=REACH+0.15 and visible_player:game.enemy_contact(self,4.0 if attack_boxing else 2.0,game.parry.time-maxf(0,attack_elapsed-contact))
  if attack_elapsed>=duration:
   punch_left=not punch_left
   if visible_player and distance<=REACH+0.15:
    attack_elapsed=maxf(0,attack_elapsed-duration);impact_done=false;progress=attack_elapsed/duration
   else:
    attack_elapsed=-1
    if boxing_remaining<=0:lower_elapsed=0;lower_from_boxing=false
    else:clip=&"boxing_guard";progress=0
 elif rise_elapsed>=0:
  rise_elapsed+=delta;clip=&"boxing_rise" if boxing_remaining>0 else &"rise";progress=minf(1,rise_elapsed/0.28)
  if rise_elapsed>=0.28:rise_elapsed=-1;standing=true
  if rise_elapsed<0 and visible_player and distance<=REACH+.15:start_attack()
 elif lower_elapsed>=0:
  lower_elapsed+=delta;clip=&"boxing_lower" if lower_from_boxing else &"lower";progress=minf(1,lower_elapsed/0.28)
  if lower_elapsed>=0.28:lower_elapsed=-1;standing=false;lower_from_boxing=false
 elif visible_player and distance<REACH:
  if standing:start_attack();clip=attack_clip()
  else:rise_elapsed=0;clip=&"boxing_rise" if boxing_remaining>0 else &"rise"
 elif mode in [&"chase",&"investigate",&"walk"]:
  direction=brain.goal-global_position;direction.y=0
  if direction.length()>0.1:direction=steer(direction.normalized(),delta)
  speed=WANDER_SPEED if mode==&"walk" else SPEED;clip=&"walk" if mode==&"walk" else &"run"
 else:
  clip=mode if mode in [&"sit_down",&"sit",&"sit_up",&"feed"] else &"idle"
  progress=fposmod(brain.elapsed/Motion.seconds(clip),1) if clip in [&"idle",&"sit",&"feed"] else minf(1,brain.elapsed/Motion.seconds(clip))
  if clip==&"feed" and is_instance_valid(brain.tree):
   var toward:Vector3=brain.tree.global_position-global_position
   if toward.length()>0.001:model.rotation.y=lerp_angle(model.rotation.y,atan2(toward.x,toward.z),1-exp(-delta*7))
 if boxing_remaining>0 and clip in [&"idle",&"sit_down",&"sit",&"sit_up",&"feed",&"walk",&"run"]:
  if not standing:rise_elapsed=0;clip=&"boxing_rise";progress=0;direction=Vector3.ZERO;speed=0
  else:clip=&"boxing_walk" if speed>0 else &"boxing_guard"
 velocity.x=direction.x*speed;velocity.z=direction.z*speed
 if not is_on_floor():velocity.y-=18*delta
 move_and_slide()
 if clip in [&"walk",&"run",&"boxing_walk"]:
  var actual_speed:=Vector2(velocity.x,velocity.z).length()
  phase=fposmod(phase+delta/Motion.seconds(clip)*clampf(actual_speed/maxf(speed,.01),0,1),1);progress=phase
 if direction.length_squared()>0.01:model.rotation.y=lerp_angle(model.rotation.y,atan2(direction.x,direction.z),1-exp(-delta*7))
 elif clip in [&"attack",&"rise",&"hook",&"boxing_rise",&"boxing_guard"]:
  var toward:Vector3=game.player.global_position-global_position
  if toward.length()>0.001:model.rotation.y=lerp_angle(model.rotation.y,atan2(toward.x,toward.z),1-exp(-delta*7))
 model.animate(clip,progress,punch_left,delta)
 update_hurtboxes()

func ensure_corpse_area() -> void:
 if corpse_area!=null:return
 corpse_area=Area3D.new();corpse_area.collision_layer=16;corpse_area.collision_mask=0;corpse_area.monitoring=false;corpse_area.set_meta("creature",self);add_child(corpse_area)
 var shape:=CollisionShape3D.new();var volume:=BoxShape3D.new();volume.size=Vector3(0.8,0.3,0.9);shape.shape=volume;shape.position.y=0.15;corpse_area.add_child(shape)
func restore_presentation() -> void:
 if health<=0:
  collision_layer=0;collision_mask=0;hurt_area.collision_layer=0
  model.animate(&"death" if death_elapsed<2 else &"corpse",minf(1,death_elapsed/2))
  if death_elapsed>=2:ensure_corpse_area()
 elif effects.remaining(&"stun")>0:
  var remaining:float=effects.remaining(&"stun");var elapsed:=1.5-remaining
  var clip:StringName=&"stun_fall" if elapsed<0.24 else (&"stun_rise" if remaining<0.24 else &"stun_hold")
  model.animate(clip,clampf(elapsed/0.24 if clip==&"stun_fall" else (1-remaining/0.24 if clip==&"stun_rise" else 0),0,1))
 elif attack_elapsed>=0:model.animate(attack_clip(),attack_elapsed/Motion.seconds(attack_clip()),punch_left)
 elif rise_elapsed>=0:model.animate(&"boxing_rise" if boxing_remaining>0 else &"rise",rise_elapsed/0.28,punch_left)
 elif lower_elapsed>=0:model.animate(&"boxing_lower" if lower_from_boxing else &"lower",lower_elapsed/0.28,punch_left)
 else:model.animate(&"boxing_guard" if boxing_remaining>0 else &"idle",phase,punch_left)
 update_hurtboxes()
