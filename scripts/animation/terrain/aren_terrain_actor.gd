extends "res://scripts/animation/authoring/aren_run_balanced_actor.gd"
## Collision-driven adapter. Source samplers, clips, binds and the review are read-only.
const FootSupport=preload("res://scripts/animation/terrain/terrain_foot_support.gd")
var foot_support=FootSupport.new()
var body:CharacterBody3D
var measured_speed:=0.0
var measured_acceleration:=0.0
var grounded:=false
var planning:=false
var terrain_contacts:Array[Dictionary]=[]
var pelvis_offset:=0.0
var ray_count:=0
var support_error:=0.0
var previous_speed:=0.0
var skin_time_left:=0.0
var style_pose:Array[Transform3D]=[]
var style_blend:=1.0
var changing_style:=true
var style_cache:Dictionary={}

func _ready() -> void:
 super._ready()
 cache_style()
 for state in ["cautious","tired"]:
  set_style(state);cache_style()
 activate_style("normal")
 foot_support.configure(native)
 changing_style=false
 set_process(false)

func cache_style() -> void:
 style_cache[style]={"library":library,"sampler":sampler,"pitch":steady_chest_pitch}

func activate_style(value:String) -> void:
 style=value;library=style_cache[value].library;sampler=style_cache[value].sampler
 steady_chest_pitch=style_cache[value].pitch
 player.remove_animation_library(&"aren");player.add_animation_library(&"aren",library)
 reset_motion()

func change_style(value:String) -> void:
 if value==style or not style_cache.has(value):return
 var old_pose:Array[Transform3D]=native.posed.duplicate()
 var old_shapes:Array[float]=[]
 for shape in native.mesh.mesh.get_blend_shape_count():old_shapes.append(native.mesh.get_blend_shape_value(shape))
 var old_phase:=phase
 var old_clock:=clock
 var speed:=current_speed
 changing_style=true
 activate_style(value)
 changing_style=false
 phase=old_phase;clock=old_clock;current_speed=speed
 target_speed=speed
 style_pose=old_pose;style_blend=0.0
 # Configuration resets its preview pose; retain the visible terrain pose until
 # the next physics sample, so input callbacks cannot expose a flat idle frame.
 native.posed=old_pose.duplicate()
 for bone in native.parents.size():native.local_globals[bone]=native.inverse_frame*native.posed[bone]
 native.writer.apply(native.skeleton,native.local_globals)
 for shape in old_shapes.size():native.mesh.set_blend_shape_value(shape,old_shapes[shape])

func evaluate_motion(dt:float,speed:float,on_ground:bool) -> void:
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
 var mix:=gait_blend()
 var walk:Dictionary=library.get_animation(&"walk").get_meta("cycle")
 var run:Dictionary=library.get_animation(&"run").get_meta("cycle")
 var stride:float=walk.distance_m*mix if mix<=1 else lerpf(walk.distance_m,run.distance_m,mix-1)
 if measured_speed>.00001:phase+=measured_speed/maxf(stride,.00001)*dt
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
 super.render_pose(prepare)

func probe(point:Vector3) -> Dictionary:
 var query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.65,point-Vector3.UP*.85,1,[body.get_rid()])
 ray_count+=1
 var hit:=body.get_world_3d().direct_space_state.intersect_ray(query)
 if not hit.is_empty() and hit.normal.dot(Vector3.UP)<cos(deg_to_rad(42)):return {}
 return hit

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
 var goals:Array[Transform3D]=[]
 var offsets:Array[float]=[]
 var frame:=global_transform
 var inverse:=frame.affine_inverse()
 for side in 2:
  var ids:Array=native.legs[side].ids
  var goal:Transform3D=sampled_feet[side]
  if style_blend<1 and style_pose.size()==native.posed.size():goal=style_pose[ids[2]].interpolate_with(goal,smooth5(style_blend))
  var world:Vector3=frame*goal.origin
  var hit:=probe(world)
  var planted:bool=grounded and (gait_blend()<.015 or fposmod(phase+side*.5,1)<support_fraction()) and not hit.is_empty()
  if terrain_contacts.size()<=side:terrain_contacts.append({"planted":false,"anchor":world,"basis":goal.basis})
  var contact:Dictionary=terrain_contacts[side]
  var clearance:float=foot_support.clearance(side,goal)
  var offset:=0.0
  if not hit.is_empty():
   # Three probes cover the sole, preventing a centre-only ray from burying toes.
   var normal:Vector3=hit.normal
   var floor_y:float=hit.position.y
   var forward:Vector3=frame.basis.z.normalized()
   for along in [-.09,.12]:
    var sole_hit:=probe(world+forward*along)
    if not sole_hit.is_empty():
     var centred_height:float=sole_hit.position.y+sole_hit.normal.dot(forward*along)/maxf(sole_hit.normal.y,.1)
     floor_y=maxf(floor_y,centred_height)
     normal+=sole_hit.normal
   normal=normal.normalized()
   offset=floor_y-global_position.y
   var aligned:Basis=frame.basis.orthonormalized().inverse()*Basis(Quaternion(Vector3.UP,normal))*frame.basis.orthonormalized()*goal.basis
   var basis_scale:=goal.basis.get_scale()
   goal.basis=goal.basis.orthonormalized().slerp(aligned.orthonormalized(),1-smoothstep(.015,.16,clearance))*Basis.from_scale(basis_scale)
   var sole_height:float=-INF
   for sole_point in foot_support.soles[side]:
    var sole_offset:Vector3=frame.basis*goal.basis*sole_point
    var sole_hit:=probe(world+sole_offset)
    if not sole_hit.is_empty():sole_height=maxf(sole_height,sole_hit.position.y-sole_offset.y)
   if is_finite(sole_height):world.y=sole_height+(0.0 if planted else clearance)+.006
   if planted:
    if not contact.planted:
     contact.anchor=world;contact.basis=frame.basis.orthonormalized()*goal.basis
    world=contact.anchor;goal.basis=frame.basis.orthonormalized().inverse()*contact.basis
   # Release unreachable support rather than stretching a native joint.
   var hip_world:Vector3=frame*native.posed[ids[0]].origin
   if planted and hip_world.distance_to(world)>(native.legs[side].a+native.legs[side].b)*SCALE*1.05:
    planted=false;contact.planted=false
  contact.planted=planted
  if contacts.size()>side:contacts[side].planted=planted
  goal.origin=inverse*world
  offsets.append(offset);goals.append(goal)
 var desired:float=clampf(minf(offsets[0],offsets[1]),-.28,.22) if grounded else 0.0
 pelvis_offset=lerpf(pelvis_offset,desired,1-exp(-1.0/120*16))
 var lowering:=0.0
 for side in 2:
  var leg:Dictionary=native.legs[side]
  var hip:Vector3=native.posed[leg.ids[0]].origin+Vector3.UP*pelvis_offset/SCALE
  var goal:Vector3=goals[side].origin
  var horizontal:=Vector2(hip.x-goal.x,hip.z-goal.z).length_squared()
  var allowed:float=goal.y+sqrt(maxf(.01,pow(leg.a+leg.b-.08,2)-horizontal))
  lowering=maxf(lowering,hip.y-allowed)
 pelvis_lowering=maxf(lowering,lerpf(pelvis_lowering,lowering,1-exp(-1.0/120/.12)))
 for i in native.posed.size():native.posed[i].origin.y+=pelvis_offset/SCALE-pelvis_lowering
 for side in 2:
  var leg:Dictionary=native.legs[side];var ids:Array=leg.ids
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
   var lift:=0.0
   for point in foot_support.skinned_points(native,side):
    var skin_world:Vector3=frame*point
    var skin_hit:=probe(skin_world)
    if not skin_hit.is_empty():lift=maxf(lift,skin_hit.position.y+.003-skin_world.y)
   if lift<.0001:break
   goals[side].origin.y+=lift*1.1/SCALE
   if terrain_contacts[side].planted:terrain_contacts[side].anchor.y+=lift*1.1
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
