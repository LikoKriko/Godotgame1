extends RefCounted
## Opt-in bridge: approved poses, real CharacterBody motion and terrain contacts.
const Jump=preload("res://scripts/animation/authoring/aren_jump_motion.gd")
const Fall=preload("res://scripts/animation/authoring/aren_fall_motion.gd")
const BlenderLanding=preload("res://scripts/animation/terrain/aren_blender_landing.gd")
const Detection=preload("res://scripts/animation/terrain/aren_fall_response.gd")
var detection=Detection.new()
var deep_landing_enabled:=false # Opt in from the approved terrain sandbox.
var landing=BlenderLanding.new()
var landing_clock:=0.0
var landing_heading:=0.0
var stage:="grounded"
var timer:=0.0
var air_time:=0.0
var source:Dictionary={}
var neutral:Dictionary={}
var last_ground:Dictionary={}
var last_position:=Vector3.ZERO
var release_feet:Array[Transform3D]=[]
var peak_y:=0.0
var support_y:=0.0
var landing_height:=0.0
var impact_scale:=1.0
var recovery_duration:=Jump.RECOVER
var recovery_clock:=Jump.RECOVER
var recovery_pose:Dictionary={}
var recovery_feet:Array[Transform3D]=[]
var landing_pending:=false
var impact_loading:=0.0
var impact_velocity:=0.0
var impact_elapsed:=100.0
var launches:=0
var falls:=0
var contacts:=0
var target_travel:=Vector2.ZERO
var momentum_offset:=Vector2.ZERO
var momentum_time:=.16
var floor_query:=PhysicsRayQueryParameters3D.new()
var support_history:Array[Vector2]=[]
var physics_clock:=0.0
var blender_peak_y:=0.0
var blender_height:=0.0

func pre_move(body:CharacterBody3D,actor:Node3D,direction:Vector3,target:Vector2,jump:bool,dt:float) -> bool:
 target_travel=target
 var launched:=false
 if jump and body.is_on_floor() and stage=="grounded" and recovery_clock>=recovery_duration and not landing.active:
  stage="prepare";timer=0
 if stage=="prepare":
  if not body.is_on_floor():stage="grounded";timer=0
  else:
   timer+=dt
   if timer>=Jump.PREPARE+Jump.PUSH:
    stage="flight";air_time=0;launched=true;launches+=1
    body.velocity.y=Jump.LAUNCH_SPEED
    source=last_ground.duplicate(true)
    if source.is_empty():source=actor.capture_pose()
    peak_y=body.global_position.y;actor.jump_speed=Vector2(body.velocity.x,body.velocity.z).length()
 if stage in ["flight","unsupported","fall"]:
  # Preserve momentum without input; bounded steering/acceleration in the air.
  var planar:=Vector2(body.velocity.x,body.velocity.z)
  if not direction.is_zero_approx():planar=planar.move_toward(target,Jump.AIR_ACCELERATION*dt)
  body.velocity.x=planar.x;body.velocity.z=planar.y
 last_position=body.global_position
 return launched

func ground_gap(body:CharacterBody3D) -> float:
 floor_query.from=body.global_position+Vector3.UP*.03
 floor_query.to=body.global_position-Vector3.UP*30
 floor_query.exclude=[body.get_rid()];floor_query.collision_mask=body.collision_mask
 var hit:=body.get_world_3d().direct_space_state.intersect_ray(floor_query)
 return maxf(0,body.global_position.y-hit.position.y) if not hit.is_empty() else 30.0

func after_move(body:CharacterBody3D,actor:Node3D,velocity:Vector3,vertical:float,launched:bool,dt:float) -> void:
 physics_clock+=dt
 var on_floor:=body.is_on_floor()
 var was_air:=stage in ["flight","unsupported","fall"]
 while not support_history.is_empty() and physics_clock-support_history[0].x>.25:support_history.pop_front()
 if on_floor and not was_air and not landing.active:support_history.append(Vector2(physics_clock,maxf(body.global_position.y,contact_height(body))))
 if launched:blender_peak_y=body.global_position.y
 var gap:=0.0 if on_floor else ground_gap(body)
 detection.update(dt,on_floor,vertical,gap,false,launched)
 if not on_floor:
  if detection.mode not in ["falling","voluntary"] and gap<=Detection.STEP_CLEARANCE:
   # Unconfirmed short gaps retain the approved terrain solver and height filter.
   # Foot IK never promotes such a gap into an automatic fall.
   stage="grounded"
   actor.evaluate_motion(dt,velocity,false)
   return
  if not was_air:
   stage="unsupported";air_time=0;source=actor.capture_pose()
   peak_y=maxf(last_position.y,support_y)
   blender_peak_y=peak_y
   for supported in support_history:blender_peak_y=maxf(blender_peak_y,supported.y)
   release_feet.clear()
   var release_frame:Transform3D=actor.global_transform
   release_frame.origin+=last_position-body.global_position
   for leg in actor.native.legs:release_feet.append(release_frame*actor.native.posed[leg.ids[2]])
   actor.jump_speed=Vector2(velocity.x,velocity.z).length()
   actor.fall_contacts.clear()
   for side in 2:actor.fall_contacts.append(actor.terrain_contacts.size()>side and actor.terrain_contacts[side].planted)
  air_time+=dt;peak_y=maxf(peak_y,body.global_position.y)
  blender_peak_y=maxf(blender_peak_y,body.global_position.y)
  if detection.mode=="falling" and stage!="fall":stage="fall";falls+=1
  actor.grounded=false;actor.measured_speed=Vector2(velocity.x,velocity.z).length()
  actor.body_height=body.global_position.y;actor.body_height_velocity=vertical
  if neutral.is_empty():neutral=actor.sampler.sample("idle",0)
  if stage=="flight":
   actor.apply_jump_pose(source,neutral,{"air_time":air_time,"time":Jump.PREPARE+Jump.PUSH+air_time,"grounded":false,"vertical_velocity":vertical})
  else:
   actor.fall_response=detection;actor.fall_time=air_time
   actor.external_support_feet.clear()
   for foot in release_feet:actor.external_support_feet.append(actor.global_transform.affine_inverse()*foot)
   actor.apply_fall_pose(source,neutral,vertical,gap)
  var predicted_height:float=blender_peak_y-(body.global_position.y-gap)
  if deep_landing_enabled and vertical<0 and BlenderLanding.Family.accepts(predicted_height):landing.prepare(actor,gap,vertical)
  return
 var new_landing:=false
 if was_air and (stage=="flight" or stage=="fall"):
  momentum_offset=Vector2(velocity.x,velocity.z)-target_travel;momentum_time=0
  contacts+=1;landing_height=maxf(0,peak_y-contact_height(body))
  blender_height=maxf(0,blender_peak_y-contact_height(body))
  impact_scale=Fall.recovery_scale(landing_height) if stage=="fall" else 1.0
  landing_pending=stage=="fall" and Fall.collapse_pending(landing_height)
  recovery_duration=Jump.RECOVER*impact_scale;recovery_clock=0
  recovery_pose=actor.capture_pose();recovery_feet.clear()
  for side in 2:recovery_feet.append(actor.global_transform*actor.native.posed[actor.native.legs[side].ids[2]])
  actor.terrain_contacts.clear();actor.pelvis_offset=0;actor.reach_velocity=0
  actor.body_height=body.global_position.y;actor.body_height_velocity=0
  impact_loading=0;impact_velocity=0;impact_elapsed=0
  if deep_landing_enabled and BlenderLanding.Family.accepts(blender_height):
   landing.start(actor,blender_height,vertical,velocity,Callable(actor,"probe"))
   landing_clock=0;landing_heading=actor.rotation.y;new_landing=true
   recovery_pose.clear();impact_elapsed=100
   recovery_duration=landing.parameters.duration;recovery_clock=0
 support_y=contact_height(body)
 stage="prepare" if stage=="prepare" else "grounded"
 if landing.active:
  if not new_landing:landing_clock+=dt
  var exit:Dictionary={}
  if landing_clock>=landing.parameters.rise_end:
   actor.evaluate_motion(dt,velocity,true);exit=actor.capture_pose()
  else:
   actor.measured_speed=Vector2(velocity.x,velocity.z).length();actor.measured_velocity=Vector3(velocity.x,0,velocity.z)
   actor.body_height=body.global_position.y;actor.grounded=true;actor.ray_count=0
  landing.apply(actor,landing_clock,exit)
  recovery_clock=minf(recovery_duration,landing_clock)
  return
 recovery_clock=minf(recovery_duration,recovery_clock+dt)
 impact_elapsed+=dt
 var goal:float=float(actor.profile.get("loading_m",.028))*impact_scale if impact_elapsed<.22*impact_scale else 0.0
 var compression_spring:Vector2=actor.spring(impact_loading,impact_velocity,goal,dt,20.0/impact_scale)
 impact_loading=compression_spring.x;impact_velocity=compression_spring.y
 actor.evaluate_motion(dt,velocity,true)
 if stage=="prepare":
  last_ground=actor.capture_pose()
  actor.jump_speed=actor.measured_speed
  actor.apply_jump_pose(last_ground,actor.sampler.sample("idle",0),{"air_time":0.0,"time":minf(timer,Jump.PREPARE+Jump.PUSH),"grounded":true,"vertical_velocity":0.0})

func blend_ground(actor:Node3D) -> void:
 if recovery_pose.is_empty() or recovery_clock>=recovery_duration:return
 var weight:=Jump.smooth5(recovery_clock/recovery_duration)
 var target:Dictionary=actor.capture_pose()
 for bone in actor.native.parents.size():
  var local:Transform3D=recovery_pose.poses[bone].interpolate_with(target.poses[bone],weight)
  var parent:int=actor.native.parents[bone]
  actor.native.local_globals[bone]=actor.native.local_globals[parent]*local if parent>=0 else local
  actor.native.posed[bone]=actor.native.frame*actor.native.local_globals[bone]
 for side in 2:
  var landing:Transform3D=actor.global_transform.affine_inverse()*recovery_feet[side]
  actor.sampled_feet[side]=landing.interpolate_with(actor.sampled_feet[side],Jump.smooth5(clampf(recovery_clock/(.16*impact_scale),0,1)))

func compression() -> float:
 # Ground locomotion has no impact loading; retain its approved fast path.
 if recovery_pose.is_empty():return 0.0
 return impact_loading

func contact_height(body:CharacterBody3D) -> float:
 for index in body.get_slide_collision_count():
  var collision:=body.get_slide_collision(index)
  if collision.get_normal().y>=cos(body.floor_max_angle):return collision.get_position().y
 # Floor snap can retain support without a new slide collision at a rounded rim.
 if body.is_on_floor() and absf(body.global_position.y-support_y)<=.26:return support_y
 return body.global_position.y

func resume_travel(target:Vector2,dt:float) -> Vector2:
 if landing.active:
  var carry:Vector3=landing.initial_velocity*(1-Jump.smooth5(landing_clock/landing.parameters.brake))
  var resume:=Jump.smooth5((landing_clock-landing.parameters.rise_end)/(landing.parameters.duration-landing.parameters.rise_end))
  return Vector2(carry.x,carry.z)+target*resume
 var result:=target+momentum_offset*(1-Jump.smooth5(momentum_time/.16))
 momentum_time=minf(.16,momentum_time+dt)
 return result
