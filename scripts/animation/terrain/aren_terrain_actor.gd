extends "res://scripts/animation/authoring/aren_run_balanced_actor.gd"
## Collision-driven adapter. Source samplers, clips, binds and the review are read-only.
const TerrainSampler=preload("res://scripts/animation/terrain/terrain_cycle_sampler.gd")
const Step=preload("res://scripts/animation/terrain/terrain_step.gd")
const FootSupport=preload("res://scripts/animation/terrain/terrain_foot_support.gd")
var foot_support=FootSupport.new()
var body:CharacterBody3D
var measured_speed:=0.0
var measured_velocity:=Vector3.ZERO
var pose_speed:=0.0
var pose_speed_velocity:=0.0
var measured_acceleration:=0.0
var grounded:=false
var planning:=false
var terrain_contacts:Array[Dictionary]=[]
var pelvis_offset:=0.0
var reach_velocity:=0.0 # Metres/second for the single signed pelvis correction.
var body_height:=0.0
var body_height_velocity:=0.0
var height_initialized:=false
var ray_count:=0
var ground_query:=PhysicsRayQueryParameters3D.new()
var support_error:=0.0
var previous_speed:=0.0
var skin_time_left:=0.0
var style_pose:Array[Transform3D]=[]
var style_feet:Array[Transform3D]=[]
var source_pose:Array[Transform3D]=[]
var source_feet:Array[Transform3D]=[]
var style_blend:=1.0
var changing_style:=true
var style_cache:Dictionary={}
var landing_feet:Dictionary={}
var climb_checked:=false
var climb_landing:Dictionary={}

func _ready() -> void:
 super._ready()
 cache_style()
 for state in ["cautious","tired"]:
  # Parent set_style() reconfigures the current sampler before replacing it.
  # Do not let that mutate a sampler already retained by another style.
  sampler=Sampler.new()
  set_style(state);cache_style()
 for entry in style_cache.values():entry.sampler=TerrainSampler.new(entry.sampler)
 activate_style("normal")
 var exclusions:Array[RID]=[]
 if body!=null:exclusions.append(body.get_rid())
 foot_support.configure(native,exclusions,Callable(self,"support_surface"))
 ground_query.collision_mask=1
 if body!=null:ground_query.exclude=[body.get_rid()]
 changing_style=false
 set_process(false)

func cache_style() -> void:
 var landing:Dictionary={}
 for clip in ["idle","walk","run"]:
  var feet:Array[Transform3D]=[]
  for side in 2:
   var sample:Dictionary=sampler.sample(clip,0.0 if clip=="idle" else side*.5*sampler.clips[clip].length)
   feet.append(native.frame*sample.feet[side])
  landing[clip]=feet
 style_cache[style]={"library":library,"sampler":sampler,"pitch":steady_chest_pitch,"landing":landing}

func activate_style(value:String) -> void:
 style=value;library=style_cache[value].library;sampler=style_cache[value].sampler
 steady_chest_pitch=style_cache[value].pitch;landing_feet=style_cache[value].landing
 player.remove_animation_library(&"aren");player.add_animation_library(&"aren",library)
 reset_motion()

func change_style(value:String) -> void:
 if value==style or not style_cache.has(value):return
 var old_pose:Array[Transform3D]=native.posed.duplicate()
 var old_source_pose:Array[Transform3D]=source_pose.duplicate()
 var old_source_feet:Array[Transform3D]=source_feet.duplicate()
 var old_shapes:Array[float]=[]
 for shape in native.mesh.mesh.get_blend_shape_count():old_shapes.append(native.mesh.get_blend_shape_value(shape))
 var old_phase:=phase
 var old_clock:=clock
 var speed:=current_speed
 var old_lowering:=pelvis_lowering
 var old_reach_velocity:=reach_velocity
 changing_style=true
 activate_style(value)
 changing_style=false
 phase=old_phase;clock=old_clock;current_speed=speed
 pelvis_lowering=old_lowering;reach_velocity=old_reach_velocity
 target_speed=speed
 style_pose=old_source_pose;style_feet=old_source_feet;style_blend=0.0
 # Configuration resets its preview pose; retain the visible terrain pose until
 # the next physics sample, so input callbacks cannot expose a flat idle frame.
 native.posed=old_pose.duplicate()
 for bone in native.parents.size():native.local_globals[bone]=native.inverse_frame*native.posed[bone]
 native.writer.apply(native.skeleton,native.local_globals)
 for shape in old_shapes.size():native.mesh.set_blend_shape_value(shape,old_shapes[shape])

func evaluate_motion(dt:float,velocity:Vector3,on_ground:bool) -> void:
 measured_velocity=Vector3(velocity.x,0,velocity.z)
 var speed:=measured_velocity.length()
 if not height_initialized:
  body_height=global_position.y;body_height_velocity=0; height_initialized=true
  pose_speed=speed;pose_speed_velocity=0
 var height:=spring(body_height,body_height_velocity,global_position.y,dt,25)
 body_height=height.x;body_height_velocity=height.y
 var envelope:=spring(pose_speed,pose_speed_velocity,speed,dt,24)
 pose_speed=maxf(0,envelope.x);pose_speed_velocity=envelope.y
 climb_checked=false;climb_landing.clear()
 measured_speed=speed;grounded=on_ground
 measured_acceleration=(speed-previous_speed)/maxf(dt,.00001);previous_speed=speed
 ray_count=0;support_error=0;skin_time_left=clampf(dt,0,1)
 advance_transition(dt)

func tick(dt:float) -> void:
 skin_time_left=maxf(0,skin_time_left-dt)
 var old_phase:=phase
 var old_distance:=distance_m
 var old_lean:=lean
 var old_lean_velocity:=lean_velocity
 planning=true
 super.tick(dt)
 planning=false
 current_speed=measured_speed;acceleration=measured_acceleration
 phase=old_phase
 var physical_speed:=current_speed
 current_speed=pose_speed
 var mix:=gait_blend()
 current_speed=physical_speed
 var walk:Dictionary=library.get_animation(&"walk").get_meta("cycle")
 var run:Dictionary=library.get_animation(&"run").get_meta("cycle")
 var stride:float=walk.distance_m*mix if mix<=1 else lerpf(walk.distance_m,run.distance_m,mix-1)
 if measured_speed>.00001:phase+=minf(3.0,measured_speed/maxf(stride,walk.distance_m*.02))*dt
 distance_m=old_distance+measured_speed*dt
 var preparation:=0.0
 if not recipe.is_empty():preparation=controls.get_animation(StringName(recipe)).value_track_interpolate(1,transition_time/transition_duration)
 var physical_lean:=spring(old_lean,old_lean_velocity,clampf(measured_acceleration*.014,-.065,.070)+preparation*.025,dt,12)
 lean=physical_lean.x;lean_velocity=physical_lean.y
 style_blend=minf(1,style_blend+dt/.3)
 tick_dt=dt;correction_tick=dt
 render_pose(preparation)
 tick_dt=0;correction_tick=0

func render_pose(prepare:float) -> void:
 if planning:return
 # Collision impulses must not switch the idle/walk/run mix in one frame.
 # Phase/displacement above still use measured motion; clip curves are untouched.
 var physical_speed:=current_speed
 if height_initialized and not changing_style:current_speed=pose_speed
 if sampler is TerrainSampler:sampler.begin_evaluation(launch_session)
 super.render_pose(prepare)
 if sampler is TerrainSampler:sampler.end_evaluation()
 current_speed=physical_speed

func probe(point:Vector3) -> Dictionary:
 ground_query.from=point+Vector3.UP*.65;ground_query.to=point-Vector3.UP*.85
 ray_count+=1
 var hit:=body.get_world_3d().direct_space_state.intersect_ray(ground_query)
 if not hit.is_empty() and not support_surface(hit.position,hit.normal):return {}
 return hit

func support_surface(point:Vector3,normal:Vector3) -> bool:
 if normal.y<cos(deg_to_rad(42)):return false
 var height:float=point.y-body.global_position.y
 if height<=.035:return true
 if height>Step.MAXIMUM+.005:return false
 # A continuous slope through the controller's floor is already reachable.
 # A horizontal terrace above that floor needs a real forward body landing.
 var offset:=point-body.global_position
 var floor_at_body:float=point.y+(normal.x*offset.x+normal.z*offset.z)/normal.y
 if absf(floor_at_body-body.global_position.y)<=.035:return true
 if not grounded or measured_speed<.03:return false
 var direction:=measured_velocity.normalized()
 var planar:=Vector3(offset.x,0,offset.z)
 if planar.length()>.7 or planar.normalized().dot(direction)<.25:return false
 if not climb_checked:
  climb_checked=true
  climb_landing=Step.landing(body,direction*.35)
 return not climb_landing.is_empty() and absf(point.y-climb_landing.transform.origin.y)<=.035

func minimum_reach(side:int) -> float:
 var leg:Dictionary=native.legs[side];var ids:Array=leg.ids
 var upper:Vector3=source_pose[ids[1]].origin-source_pose[ids[0]].origin
 var lower:Vector3=source_pose[ids[2]].origin-source_pose[ids[1]].origin
 # Preserve any greater flexion authored in the approved source pose.
 var flex:float=maxf(deg_to_rad(130),upper.angle_to(lower))
 return sqrt(maxf(0,leg.a*leg.a+leg.b*leg.b+2*leg.a*leg.b*cos(flex)))

func solve_contacts() -> void:
 if body==null or changing_style:
  super.solve_contacts();return
 if style_blend<1 and style_pose.size()==native.posed.size():
  var current_pose:Array[Transform3D]=native.posed.duplicate()
  for i in native.posed.size():
   var parent:int=native.parents[i]
   var old_local:Transform3D=style_pose[parent].affine_inverse()*style_pose[i] if parent>=0 else style_pose[i]
   var new_local:Transform3D=current_pose[parent].affine_inverse()*current_pose[i] if parent>=0 else current_pose[i]
   var local:=old_local.interpolate_with(new_local,smooth5(style_blend))
   if parent>=0:local.origin=local.origin.normalized()*new_local.origin.length()
   native.posed[i]=native.posed[parent]*local if parent>=0 else local
 # Retain the authored/blended input, never an already terrain-corrected pose.
 source_pose=native.posed.duplicate();source_feet.clear()
 var goals:Array[Transform3D]=[]
 var support_floor:=INF
 var frame:=global_transform
 var body_offset:float=body_height-global_position.y if height_initialized else 0.0
 var inverse:=frame.affine_inverse()
 for side in 2:
  var ids:Array=native.legs[side].ids
  var goal:Transform3D=sampled_feet[side]
  if style_blend<1 and style_feet.size()==2:goal=style_feet[side].interpolate_with(goal,smooth5(style_blend))
  source_feet.append(goal)
  var world:Vector3=frame*goal.origin
  var hit:=probe(world)
  if terrain_contacts.size()<=side:terrain_contacts.append({"planted":false,"anchor":world,"basis":goal.basis})
  var contact:Dictionary=terrain_contacts[side]
  var planted:bool=grounded and (gait_blend()<.015 or fposmod(phase+side*.5,1)<support_fraction()) and (not hit.is_empty() or contact.planted)
  var authored_world:=world
  var authored_basis:=goal.basis
  var floor_y:float=hit.position.y if not hit.is_empty() else float(contact.get("floor_y",global_position.y))
  var cycle:=floori(phase+side*.5)
  if int(contact.get("released_cycle",-1))==cycle:planted=false
  var clearance:float=foot_support.clearance(side,goal)
  if not hit.is_empty():
   # Three probes cover the sole, preventing a centre-only ray from burying toes.
   var normal:Vector3=hit.normal
   floor_y=hit.position.y
   var forward:Vector3=frame.basis.z.normalized()
   for along in [-.09,.12]:
    var sole_hit:=probe(world+forward*along)
    if not sole_hit.is_empty():
     var centred_height:float=sole_hit.position.y+sole_hit.normal.dot(forward*along)/maxf(sole_hit.normal.y,.1)
     floor_y=maxf(floor_y,centred_height)
     normal+=sole_hit.normal
   normal=normal.normalized()
   var aligned:Basis=frame.basis.orthonormalized().inverse()*Basis(Quaternion(Vector3.UP,normal))*frame.basis.orthonormalized()*goal.basis
   var basis_scale:=goal.basis.get_scale()
   goal.basis=goal.basis.orthonormalized().slerp(aligned.orthonormalized(),1-smoothstep(.015,.16,clearance))*Basis.from_scale(basis_scale)
   var sole_height:float=-INF
   for sole_point in foot_support.soles[side]:
    var sole_offset:Vector3=frame.basis*goal.basis*sole_point
    var sole_hit:=probe(world+sole_offset)
    if not sole_hit.is_empty():sole_height=maxf(sole_height,sole_hit.position.y-sole_offset.y)
   if is_finite(sole_height):world.y=sole_height+(0.0 if planted else clearance)+.006
  var hip_world:Vector3=frame*(native.posed[ids[0]].origin+Vector3.UP*((pelvis_offset+body_offset)/SCALE))
  if hip_world.distance_to(world)<minimum_reach(side)*SCALE:
   world=authored_world;goal.basis=authored_basis;planted=false
  var nominal:=world
  var nominal_basis:=goal.basis
  if planted:
   if not contact.planted:
    contact.anchor=world;contact.basis=frame.basis.orthonormalized()*goal.basis
    contact.floor_y=floor_y;contact.heading=frame.basis.z.normalized()
   world=contact.anchor;goal.basis=frame.basis.orthonormalized().inverse()*contact.basis
  # Release unreachable support rather than stretching a native joint.
  var turn:float=frame.basis.z.normalized().angle_to(contact.get("heading",frame.basis.z.normalized()))
  if planted and (hip_world.distance_to(world)>(native.legs[side].a+native.legs[side].b-.08)*SCALE+.002 or turn>deg_to_rad(60)):
   planted=false;contact.released_cycle=cycle
   world=nominal;goal.basis=nominal_basis
  if not planted:
   if contact.planted:
    contact.swing_offset=contact.anchor-nominal
    contact.release_phase=phase+side*.5
   var progress:float=clampf((phase+side*.5-float(contact.get("release_phase",phase+side*.5-1)))/maxf(1-support_fraction(),.01),0,1)
   var fade:float=1-smooth5(progress)
   world+=contact.get("swing_offset",Vector3.ZERO)*fade
   var source_basis:Basis=frame.basis.orthonormalized().inverse()*contact.basis
   goal.basis=Transform3D(source_basis,Vector3.ZERO).interpolate_with(Transform3D(goal.basis,Vector3.ZERO),1-fade).basis
  contact.nominal=nominal
  contact.planted=planted
  if contacts.size()>side:contacts[side].planted=planted
  goal.origin=inverse*world
  # Only the ground carrying an actual world anchor may position the body.
  # A rotating nominal/swing foot can be over another level or off a ledge.
  if planted:support_floor=minf(support_floor,float(contact.floor_y))
  goals.append(goal)
 var dt:float=correction_tick
 var desired:float=clampf(support_floor-body_height,-.28,.22) if grounded and is_finite(support_floor) else 0.0
 var lowering:=0.0
 for side in 2:
  # A recovering foot must never drive the pelvis down to reach a rearward,
  # elevated swing target. The approved player bounds swing reach too.
  var leg:Dictionary=native.legs[side]
  var hip:Vector3=native.posed[leg.ids[0]].origin+Vector3.UP*(desired+body_offset)/SCALE
  var goal:Vector3=goals[side].origin
  if not terrain_contacts[side].planted:
   if not grounded:continue
   # Preview the next ground-level landing, not the raised trailing foot.
   # Cache approved front-contact poses to avoid resampling/mutating the rig.
   var mix:=gait_blend()
   var a:String="idle" if mix<1 else "walk"
   var b:String="walk" if mix<1 else "run"
   var front:Transform3D=landing_feet[a][side].interpolate_with(landing_feet[b][side],mix if mix<1 else mix-1)
   var landing_world:Vector3=frame*front.origin+measured_velocity*.12
   var hit:=probe(landing_world)
   if hit.is_empty() or absf(hit.position.y-global_position.y)>.26:continue
   var sole_y:=INF
   for point in foot_support.soles[side]:sole_y=minf(sole_y,(frame.basis*front.basis*point).y)
   goal=front.origin
   goal.y=(hit.position.y-sole_y+.006-global_position.y)/SCALE
  var horizontal:=Vector2(hip.x-goal.x,hip.z-goal.z).length_squared()
  var allowed:float=goal.y+sqrt(maxf(.01,pow(leg.a+leg.b-.08,2)-horizontal))
  lowering=maxf(lowering,hip.y-allowed)
 # Resolve both feet into one signed target before filtering. Independent
 # floor/reach filters could add their velocities during a support change.
 var target:=clampf(desired-lowering*SCALE,-.28,.22)
 var filtered:=spring(pelvis_offset,reach_velocity,target,dt,18)
 pelvis_offset=move_toward(pelvis_offset,filtered.x,.75*dt)
 reach_velocity=clampf(filtered.y,-.75,.75)
 pelvis_lowering=0.0
 for i in native.posed.size():native.posed[i].origin.y+=(pelvis_offset+body_offset)/SCALE
 for side in 2:
  var leg:Dictionary=native.legs[side];var ids:Array=leg.ids
  if not terrain_contacts[side].planted:
   var hip:Vector3=native.posed[ids[0]].origin
   var delta:Vector3=goals[side].origin-hip
   var reach:float=leg.a+leg.b-.08
   if delta.length()>reach:goals[side].origin=hip+delta.normalized()*reach
  # Pelvis filtering and release offsets must obey the same flexion bound.
  var from_hip:Vector3=goals[side].origin-native.posed[ids[0]].origin
  var minimum:=minimum_reach(side)
  if from_hip.length()<minimum:
   goals[side].origin=native.posed[ids[0]].origin+from_hip.normalized()*minimum
   terrain_contacts[side].planted=false
   terrain_contacts[side].released_cycle=floori(phase+side*.5)
   if contacts.size()>side:contacts[side].planted=false
  var pole:Vector3=native.posed[ids[1]].origin-native.posed[ids[0]].origin
  var solution:=Solver.joint(native.posed[ids[0]].origin,goals[side].origin,leg.a,leg.b,pole)
  native.untwisted_chain(ids,0,solution,Basis.IDENTITY)
  Torso.rotate_branch(native,ids[2],goals[side].basis,solution.end)
  var mix:=gait_blend()
  var a:String="idle" if mix<1 else "walk"
  var b:String="walk" if mix<1 else "run"
  var pole_weight:float=mix if mix<1 else mix-1
  var stable_pole:Vector3=sampler.knee_poles[a][side].lerp(sampler.knee_poles[b][side],pole_weight).normalized()
  KneePlane.stabilize(native,side,stable_pole,knee_planes[side],correction_tick)
  var error:float=solution.end.distance_to(goals[side].origin)*SCALE
  max_ik_error_m=maxf(max_ik_error_m,error)
  if terrain_contacts[side].planted:support_error=maxf(support_error,error)
  var cosine:float=clampf((solution.joint-solution.root).normalized().dot((solution.end-solution.joint).normalized()),-1,1)
  native.mesh.set_blend_shape_value(native.knee_shapes[side],.5*(1-cosine)*(1-smoothstep(deg_to_rad(115),deg_to_rad(145),acos(cosine))))

  # Ankle skin blends with the shin. Correct its actual surface after IK,
  # keeping the planted XZ anchor while permitting vertical sole compression.
  # Skin is displayed once per physics frame; contact clocks still substep.
  for iteration in (2 if skin_time_left<.000001 else 0):
   if not foot_support.may_penetrate(native,side,frame,body.get_world_3d().direct_space_state):break
   var lift:=0.0
   if foot_support.plane_valid:
    lift=foot_support.plane_lift(native,side,frame)
   else:
    for point in foot_support.skinned_points(native,side):
     var skin_world:Vector3=frame*point
     var skin_hit:=probe(skin_world)
     if not skin_hit.is_empty():lift=maxf(lift,skin_hit.position.y+.003-skin_world.y)
   if lift<.0001:break
   var hip:Vector3=native.posed[ids[0]].origin
   var horizontal:float=Vector2(goals[side].origin.x-hip.x,goals[side].origin.z-hip.z).length_squared()
   var ceiling:float=hip.y-sqrt(maxf(0,minimum*minimum-horizontal))
   var raised:=minf(goals[side].origin.y+lift*1.1/SCALE,ceiling)
   if raised<=goals[side].origin.y+.000001:break
   goals[side].origin.y=raised
   # This is a fresh per-pose skin correction, never accumulated in the
   # immutable support anchor across frames or fed back into pelvis height.
   solution=Solver.joint(native.posed[ids[0]].origin,goals[side].origin,leg.a,leg.b,pole)
   native.untwisted_chain(ids,0,solution,Basis.IDENTITY)
   Torso.rotate_branch(native,ids[2],goals[side].basis,solution.end)
   KneePlane.stabilize(native,side,stable_pole,knee_planes[side],0)
  error=native.posed[ids[2]].origin.distance_to(goals[side].origin)*SCALE
  max_ik_error_m=maxf(max_ik_error_m,error)
  if terrain_contacts[side].planted:support_error=maxf(support_error,error)
  var upper:Vector3=native.posed[ids[1]].origin-native.posed[ids[0]].origin
  var lower:Vector3=native.posed[ids[2]].origin-native.posed[ids[1]].origin
  cosine=clampf(upper.normalized().dot(lower.normalized()),-1,1)
  native.mesh.set_blend_shape_value(native.knee_shapes[side],.5*(1-cosine)*(1-smoothstep(deg_to_rad(115),deg_to_rad(145),acos(cosine))))
