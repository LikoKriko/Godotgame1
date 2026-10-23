extends "res://scripts/animation/authoring/aren_blender_landing_contacts.gd"
## Approved whole-body clips, physical impact clock, existing native contact IK.
const BaseClip=preload("res://assets/characters/prototype_3d/generated/aren_landing_blender_pilot_v1/landing_3m.res")
const HeavyClip=preload("res://assets/characters/prototype_3d/generated/aren_landing_blender_pilot_v1/landing_heavy.res")
const Family=preload("res://scripts/animation/authoring/aren_blender_landing_motion.gd")
const Sampler=preload("res://scripts/animation/authoring/aren_cycle_sampler.gd")
var playback=Sampler.new()
var playback_ready:=false
var clip_impact:float=BaseClip.get_meta("impact_time")
var surface_query:=PhysicsRayQueryParameters3D.new()
var body_lift:=0.0
var impact_speed:=0.0
var contact_elapsed:=0.0
var last_pose_ms:=0.0
var exit_weight:=0.0
var cache_query:=PhysicsShapeQueryParameters3D.new()
var cache_box:=BoxShape3D.new()
var cache_centre:=Vector3.ZERO
var cached_boxes:Array[Dictionary]=[]
var cached_grids:Array[Dictionary]=[]
var cache_ready:=false
var hand_points_local:=PackedVector3Array()
var hand_bones:=PackedInt32Array()
var hand_weights:=PackedFloat32Array()
var hand_offsets:=PackedInt32Array()
var knee_lift:=0.0
var foot_bases:Array[Basis]=[]
var hand_goals:Array[Vector3]=[]

func configure(actor:Node3D) -> void:
 super.configure(actor)
 if playback_ready:return
 playback.configure(actor.library,actor.native.skeleton)
 for key in ["blender","heavy"]:
  var clip:Animation=BaseClip if key=="blender" else HeavyClip
  playback.clips[key]=clip
  var bindings:Array=[]
  for track in clip.get_track_count():bindings.append(actor.native.skeleton.find_bone(str(clip.track_get_path(track).get_subname(0))))
  playback.tracks[key]=bindings
 surface_query.collision_mask=actor.body.collision_mask
 surface_query.exclude=[actor.body.get_rid()]
 cache_box.size=Vector3(2.5,2.2,2.5);cache_query.shape=cache_box
 cache_query.collision_mask=surface_query.collision_mask;cache_query.exclude=surface_query.exclude
 for record in hand_samples:
  hand_offsets.append(hand_bones.size())
  for influence in record:
   hand_bones.append(influence[0]);hand_points_local.append(influence[1]);hand_weights.append(influence[2])
 hand_offsets.append(hand_bones.size())
 playback_ready=true

func cache_surfaces(actor:Node3D) -> void:
 cache_centre=actor.global_position
 cache_query.transform=Transform3D(Basis.IDENTITY,cache_centre+Vector3.UP*.15)
 var hits:Array[Dictionary]=actor.body.get_world_3d().direct_space_state.intersect_shape(cache_query,32)
 cached_boxes.clear();cached_grids.clear();cache_ready=hits.size()<32
 var boxes:Array[Dictionary]=[]
 for hit in hits:
  var collider:CollisionObject3D=hit.collider
  if collider.has_meta(&"sole_height_grid") and collider.global_basis.is_equal_approx(Basis.IDENTITY):
   cached_grids.append({"data":collider.get_meta(&"sole_height_grid"),"origin":collider.global_position})
  else:boxes.append(hit)
 sole_support.cache_boxes(boxes)
 if not boxes.is_empty() and not sole_support.boxes_valid:cache_ready=false;return
 for i in sole_support.box_frames.size():
  var frame:Transform3D=sole_support.box_frames[i]
  var normal:Vector3=frame.basis.y.normalized()
  var half:Vector3=sole_support.box_bounds[i].size*.5
  var top:Vector3=frame*Vector3(0,half.y,0)
  cached_boxes.append({"inverse":sole_support.box_inverses[i],"normal":normal,"d":normal.dot(top),"half":half})

func pose_at(seconds:float,intensity:float) -> Dictionary:
 var t:=clampf(seconds,0,BaseClip.length-.000001)
 var pose:Dictionary=playback.sample("blender",t)
 var heavy:Dictionary=playback.sample("heavy",t)
 for bone in pose.poses.size():pose.poses[bone]=pose.poses[bone].interpolate_with(heavy.poses[bone],intensity)
 return pose

func prepare(actor:Node3D,ground_gap:float,velocity_y:float) -> void:
 configure(actor)
 var remaining:float=(sqrt(velocity_y*velocity_y+2*Jump.GRAVITY*ground_gap)-absf(velocity_y))/Jump.GRAVITY
 var weight:=Jump.smooth5(1-remaining/.45)
 if weight<=0:return
 var source_pose:Dictionary=actor.capture_pose()
 var predicted_speed:float=-sqrt(velocity_y*velocity_y+2*Jump.GRAVITY*ground_gap)
 var pose:=pose_at(clip_impact-remaining,Family.profile(predicted_speed).intensity)
 for bone in pose.poses.size():pose.poses[bone]=source_pose.poses[bone].interpolate_with(pose.poses[bone],weight)
 restore(actor,pose.poses);write(actor)

func surface(actor:Node3D,point:Vector3) -> Dictionary:
 if cache_ready and absf(point.x-cache_centre.x)<1.24 and absf(point.z-cache_centre.z)<1.24:
  var height:=-INF;var normal:=Vector3.UP
  for box in cached_boxes:
   var y:float=(box.d-box.normal.x*point.x-box.normal.z*point.z)/box.normal.y
   if y>point.y+.8 or y<point.y-1.2:continue
   var local:Vector3=box.inverse*Vector3(point.x,y,point.z)
   if absf(local.x)>box.half.x+.00001 or absf(local.z)>box.half.z+.00001:continue
   if y>height:height=y;normal=box.normal
  for grid in cached_grids:
   var value:Vector4=FootSupport.Patch.sample_grid(grid.data,point-grid.origin)
   var y:float=value.w+grid.origin.y
   if value.y>0 and y>height and y<=point.y+.8 and y>=point.y-1.2:height=y;normal=Vector3(value.x,value.y,value.z)
  if is_finite(height):
   return {"position":Vector3(point.x,height,point.z),"normal":normal} if normal.y>=cos(actor.body.floor_max_angle) else {}
 surface_query.from=point+Vector3.UP*.8;surface_query.to=point-Vector3.UP*1.2
 actor.ray_count+=1
 var hit:Dictionary=actor.body.get_world_3d().direct_space_state.intersect_ray(surface_query)
 if not hit.is_empty() and hit.normal.y<cos(actor.body.floor_max_angle):return {}
 return hit

func gap(actor:Node3D,points:PackedVector3Array) -> float:
 var result:=INF
 if cache_ready:
  var minimum_normal:float=cos(actor.body.floor_max_angle)
  for point in points:
   var height:=-INF;var normal_y:=1.0
   for box in cached_boxes:
    var y:float=(box.d-box.normal.x*point.x-box.normal.z*point.z)/box.normal.y
    if y>point.y+.8 or y<point.y-1.2:continue
    var local:Vector3=box.inverse*Vector3(point.x,y,point.z)
    if absf(local.x)>box.half.x+.00001 or absf(local.z)>box.half.z+.00001:continue
    if y>height:height=y;normal_y=box.normal.y
   for grid in cached_grids:
    var value:Vector4=FootSupport.Patch.sample_grid(grid.data,point-grid.origin)
    var y:float=value.w+grid.origin.y
    if value.y>0 and y>height and y<=point.y+.8 and y>=point.y-1.2:height=y;normal_y=value.y
   if is_finite(height):
    if normal_y>=minimum_normal:result=minf(result,point.y-height)
   else:
    var hit:=surface(actor,point)
    if not hit.is_empty():result=minf(result,point.y-hit.position.y)
  return result
 for point in points:
  var hit:=surface(actor,point)
  if not hit.is_empty():result=minf(result,point.y-hit.position.y)
 return result

func hand_points(actor:Node3D) -> PackedVector3Array:
 var poses:Array[Transform3D]=actor.native.posed
 var frame:=actor.global_transform
 var result:=PackedVector3Array();result.resize(hand_offsets.size()-1)
 for vertex in result.size():
  var point:=Vector3.ZERO
  for index in range(hand_offsets[vertex],hand_offsets[vertex+1]):
   var pose:Transform3D=poses[hand_bones[index]]
   point+=pose.basis*hand_points_local[index]+pose.origin*hand_weights[index]
  result[vertex]=frame*point
 return result

func start(actor:Node3D,_height:float,velocity_y:float,velocity:Vector3=Vector3.ZERO,_query:Callable=Callable()) -> void:
 configure(actor);parameters=Family.profile(velocity_y);impact_speed=absf(velocity_y)
 # Stronger impacts compress the same approved whole-body pose faster, while
 # weight transfer/recovery last longer. No independent bone curves are added.
 parameters.absorb=lerpf(.20,.16,parameters.intensity)
 for key in ["release","release_end","hold","rise_end"]:
  var canonical:float=parameters[key]/parameters.scale
  parameters[key]=parameters.absorb+(canonical-.20)*(parameters.duration-parameters.absorb)/1.60
 initial_velocity=Vector3(velocity.x,0,velocity.z)
 parameters.brake=minf(.10,.16/maxf(initial_velocity.length(),.1))
 active=true;time=0;body_lift=0;contact_elapsed=0;knee_lift=0
 restore(actor,pose_at(clip_impact,parameters.intensity).poses)
 begin_contacts(actor)
 cache_surfaces(actor)
 # Adapt the pelvis to the support level without changing the authored pose.
 for side in 2:
  var low:=gap(actor,sole_support.world_skin_points(actor.native,side,actor.global_transform))
  if is_finite(low):body_lift-=low*.5
 body_lift=clampf(body_lift,-.12,.16)

func apply(actor:Node3D,seconds:float,exit:Dictionary={}) -> void:
 var started:=Time.get_ticks_usec()
 var dt:=maxf(0,seconds-contact_elapsed)
 contact_elapsed=seconds
 time=.20*seconds/parameters.absorb if seconds<=parameters.absorb else .20+(seconds-parameters.absorb)*1.60/(parameters.duration-parameters.absorb)
 cache_surfaces(actor)
 var pose:=pose_at(clip_impact+time,parameters.intensity)
 var finish:=Jump.smooth5((time-1.50)/.30)
 exit_weight=finish
 if not exit.is_empty() and finish>0:
  for bone in pose.poses.size():pose.poses[bone]=pose.poses[bone].interpolate_with(exit.poses[bone],finish)
 restore(actor,pose.poses)
 var displacement:Vector3=contact_position-actor.global_position;displacement.y=0
 var counter:Vector3=actor.global_basis.inverse()*displacement
 for bone in actor.native.posed.size():
  actor.native.posed[bone].origin+=(counter+Vector3.UP*body_lift/SCALE)*(1-finish)
 foot_bases.clear();hand_goals.clear()
 for leg in actor.native.legs:foot_bases.append(actor.native.posed[leg.ids[2]].basis)
 for arm in actor.native.arms:hand_goals.append(actor.global_transform*actor.native.posed[arm.ids[3]].origin)
 palm_planted=time>=.20 and time<=23.0/60;support_loaded=palm_planted;knee_planted=false
 foot_error=0;palm_error=0
 for side in 2:fit_foot(actor,side)
 # Terrain adaptation only: keep the suspended knee clear of a local mound
 # without altering the authored flexion, contacts or native bone lengths.
 var knee_points:=PackedVector3Array()
 for record in knee_samples:
  var point:=Vector3.ZERO
  for influence in record:
   var transform:Transform3D=actor.native.posed[influence[0]]
   point+=transform.basis*influence[1]+transform.origin*influence[2]
  knee_points.append(actor.global_transform*point)
 var knee_clearance:=gap(actor,knee_points)
 var target_lift:float=clampf((.005-knee_clearance)*2.2,0,.10) if is_finite(knee_clearance) else 0.0
 knee_lift=maxf(target_lift,move_toward(knee_lift,target_lift,.25*dt))
 if knee_lift*(1-finish)>.00001:
  for bone in actor.native.posed.size():actor.native.posed[bone].origin.y+=knee_lift*(1-finish)/SCALE
  for side in 2:fit_foot(actor,side)
 fit_hand(actor,0);fit_hand(actor,1)
 knee_minimum=knee_gap(actor)
 for side in 2:correct_knee(actor,side)
 write(actor)
 if seconds>=parameters.duration-.000001:
  active=false;actor.body_height=actor.global_position.y;actor.body_height_velocity=0
 last_pose_ms=(Time.get_ticks_usec()-started)/1000.0

func fit_foot(actor:Node3D,side:int) -> void:
 var native=actor.native;var leg:Dictionary=native.legs[side];var ids:Array=leg.ids
 var planted:bool=time<=56.0/60 if side==1 else (time<=23.0/60 or time>=56.0/60)
 if side==0 and time>=56.0/60 and not right_replanted:
  locks[0]=actor.global_transform*native.posed[ids[2]];right_replanted=true
 var goal:Vector3=(actor.global_transform.affine_inverse()*locks[side].origin).lerp(native.posed[ids[2]].origin,exit_weight) if planted else native.posed[ids[2]].origin
 var hit:=surface(actor,actor.global_transform*goal)
 if not hit.is_empty():
  var basis:Basis=actor.global_basis.orthonormalized().inverse()*Basis(Quaternion(Vector3.UP,hit.normal))*actor.global_basis.orthonormalized()*foot_bases[side]
  Torso.rotate_branch(native,ids[2],basis,native.posed[ids[2]].origin)
 for iteration in 3:
  adjust_chain(actor,ids,0,leg.a,leg.b,goal)
  var low:=gap(actor,sole_support.world_skin_points(native,side,actor.global_transform))
  if not is_finite(low) or ((not planted or exit_weight>0) and low>=.001) or absf(low-.001)<.0003:break
  goal.y+=(.001-low)/actor.global_basis.y.length()
 foot_error=maxf(foot_error,native.posed[ids[2]].origin.distance_to(goal)*SCALE)

func fit_hand(actor:Node3D,side:int) -> void:
 var native=actor.native;var arm:Dictionary=native.arms[side];var ids:Array=arm.ids
 var wrist:Vector3=hand_goals[side]
 var hit:=surface(actor,wrist)
 if hit.is_empty():return
 var clearance:float=wrist.y-hit.position.y
 if clearance>.24:return
 var rotation_weight:=1-Jump.smooth5(maxf(0,clearance-.04)/.14)
 var original:Basis=native.posed[ids[3]].basis
 var aligned:Basis=actor.global_basis.orthonormalized().inverse()*Basis(Quaternion(Vector3.UP,hit.normal))*actor.global_basis.orthonormalized()*original
 var basis:=original.orthonormalized().slerp(aligned.orthonormalized(),rotation_weight)*Basis.from_scale(original.get_scale())
 Torso.rotate_branch(native,ids[3],basis,native.posed[ids[3]].origin)
 var goal:Vector3=actor.global_transform.affine_inverse()*wrist
 var last_gap:=INF
 if side==0 and palm_planted:
  if not hand_locked:hand_lock=wrist;hand_locked=true
  goal=actor.global_transform.affine_inverse()*hand_lock
 for iteration in 3:
  adjust_chain(actor,ids,1,arm.a,arm.b,goal)
  # The free left hand stays above the ground; its authored path is retained.
  if side!=0:break
  var low:=gap(actor,hand_points(actor));last_gap=low
  if not is_finite(low) or (not palm_planted and low>=.001) or absf(low-.001)<.0003:break
  goal.y+=(.001-low)/actor.global_basis.y.length()
 if side==0:
  if palm_planted:hand_lock=actor.global_transform*native.posed[ids[3]].origin
  palm_error=native.posed[ids[3]].origin.distance_to(goal)*SCALE
  palm_minimum=last_gap
  elbow_degrees=rad_to_deg((native.posed[ids[2]].origin-native.posed[ids[1]].origin).angle_to(native.posed[ids[3]].origin-native.posed[ids[2]].origin))
