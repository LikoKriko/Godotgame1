extends "res://scripts/animation/authoring/aren_run_balanced_actor.gd"
## Review-only opt-in layer. Approved libraries and terrain IK are untouched.
const Jump=preload("res://scripts/animation/authoring/aren_jump_motion.gd")
var jump_state:Dictionary={}
var jump_source_phase:=.0
var jump_ik_error_m:=0.0
var queued_preview:=""
var preview_name:=""
var preview_clock:=0.0
var preview_done:=false
var preview_stage:=""
var segment_name:=""
var jump_origin:="idle"
var jump_target:="idle"
var jump_time:=0.0
var stage_time:=0.0
var chain_index:=0
var airborne_source:Dictionary={}
var recovery_source:Dictionary={}
var recovery_poles:Array[Vector3]=[]
var recovering:=false
var recovery_weight:=1.0
var contact_distance:=0.0
var jump_speed:=0.0
var takeoff_distance:=0.0
func apply_jump_pose(source:Dictionary,neutral:Dictionary,state:Dictionary) -> void:
 # No support query, world foot lock, pelvis terrain correction or terrestrial
 # IK runs in flight. Fixed-length limb posing remains active for anatomy.
 var airborne:float=Jump.smooth5(float(state.air_time)/.16)
 var load_weight:=0.0
 var push_weight:=0.0
 if state.grounded:
  load_weight=Jump.smooth5(float(state.time)/Jump.PREPARE)
  if state.time>=Jump.PREPARE:
   push_weight=Jump.smooth5((float(state.time)-Jump.PREPARE)/Jump.PUSH)
   load_weight=1-push_weight
 for i in native.parents.size():
  var local:Transform3D=source.poses[i].interpolate_with(neutral.poses[i],airborne)
  var parent:int=native.parents[i]
  native.local_globals[i]=native.local_globals[parent]*local if parent>=0 else local
  native.posed[i]=native.frame*native.local_globals[i]
 var pose_poles:Array[Vector3]=[]
 for leg in native.legs:
  var root:Vector3=native.posed[leg.ids[0]].origin
  var axis:Vector3=(native.posed[leg.ids[2]].origin-root).normalized()
  var knee:Vector3=native.posed[leg.ids[1]].origin-root
  var radial:Vector3=knee-axis*knee.dot(axis)
  pose_poles.append(radial.normalized() if radial.length_squared()>.000001 else Vector3.BACK)
 var hip:int=native.binding.bone(&"root")
 var lowering:float=.065*load_weight
 var pitch:float=deg_to_rad(11)*load_weight+deg_to_rad(4)*push_weight
 var air_progress:float=clampf((Jump.LAUNCH_SPEED-float(state.vertical_velocity))/(2*Jump.LAUNCH_SPEED),0,1)
 var gather:float=sin(air_progress*PI)
 var descent:float=Jump.smooth5((air_progress-.5)*2)
 var travel_weight:float=clampf(jump_speed/5.0,0,1)
 if not state.grounded:
  pitch=deg_to_rad(4)*(1-Jump.smooth5(float(state.air_time)/(Jump.LAUNCH_SPEED/Jump.GRAVITY)))
  lowering=(.004+.04*travel_weight)*descent
 Torso.rotate_branch(native,hip,Basis(Vector3.RIGHT,pitch*.3)*native.posed[hip].basis,native.posed[hip].origin-Vector3.UP*lowering/SCALE)
 for i in native.spine.size():
  var id:int=native.spine[i]
  Torso.rotate_branch(native,id,Basis(Vector3.RIGHT,pitch*[.16,.24,.30][i])*native.posed[id].basis,native.posed[id].origin)
 Torso.rotate_branch(native,native.neck,Basis(Vector3.RIGHT,-pitch*.5)*native.posed[native.neck].basis,native.posed[native.neck].origin)
 # Arm swing continues through extension, then relaxes towards descent.
 var swing:float=deg_to_rad(15)*load_weight-deg_to_rad(40)*push_weight
 if not state.grounded:swing=lerpf(deg_to_rad(-40),deg_to_rad(-12),Jump.smooth5(air_progress))
 for side in 2:
  var arm:Array=native.arms[side].ids
  var sign_side:float=1 if side==0 else -1
  var spread:float=deg_to_rad(10)*airborne*sign_side
  var arm_id:int=arm[1]
  Torso.rotate_branch(native,arm_id,Basis(Vector3.FORWARD,spread)*Basis(Vector3.RIGHT,swing+deg_to_rad(6)*sign_side*descent*travel_weight)*native.posed[arm_id].basis,native.posed[arm_id].origin)
  var elbow:int=arm[2]
  Torso.rotate_branch(native,elbow,Basis(Vector3.RIGHT,-deg_to_rad(12)*airborne*gather)*native.posed[elbow].basis,native.posed[elbow].origin)
 jump_ik_error_m=0
 for side in 2:
  var leg:Dictionary=native.legs[side];var ids:Array=leg.ids
  var foot:Transform3D=native.frame*source.feet[side]
  var root:Vector3=native.posed[ids[0]].origin
  var neutral_foot:Transform3D=native.frame*neutral.feet[side]
  var asymmetry:float=(1 if side==0 else -1)*minf(current_jump_speed()/4.5,1)*.025*gather
  var lead:float=(.20 if side==0 else -.10)*descent*travel_weight
  var trailing_lift:float=.035*descent*travel_weight if side==1 else 0.0
  var air_goal:Vector3=neutral_foot.origin+Vector3(0,.12*gather+trailing_lift,.04*gather+asymmetry+lead)/SCALE
  var goal:Vector3=foot.origin.lerp(air_goal,airborne)
  var basis:Basis=Transform3D(foot.basis,Vector3.ZERO).interpolate_with(Transform3D(neutral_foot.basis,Vector3.ZERO),airborne).basis
  var plantar:float=deg_to_rad(9)*Jump.smooth5(float(state.air_time)/.06)*(1-Jump.smooth5(air_progress)) if not state.grounded else 0.0
  basis=Basis(Vector3.RIGHT,plantar)*basis
  var source_pole:Vector3=pose_poles[side]
  var pole:Vector3=source_pole.lerp(Vector3.BACK,airborne).normalized()
  var solution:=Solver.joint(root,goal,leg.a,leg.b,pole)
  jump_ik_error_m=maxf(jump_ik_error_m,solution.end.distance_to(goal)*SCALE)
  native.untwisted_chain(ids,0,solution,Basis.IDENTITY)
  Torso.rotate_branch(native,ids[2],basis,solution.end)
  var cosine:float=clampf((solution.joint-solution.root).normalized().dot((solution.end-solution.joint).normalized()),-1,1)
  var corrective:float=.5*(1-cosine)*(1-smoothstep(deg_to_rad(115),deg_to_rad(145),acos(cosine)))
  native.mesh.set_blend_shape_value(native.knee_shapes[side],corrective)
 for i in native.posed.size():native.local_globals[i]=native.inverse_frame*native.posed[i]
 native.writer.apply(native.skeleton,native.local_globals)
func current_jump_speed() -> float:
 return jump_speed

func capture_pose() -> Dictionary:
 var poses:Array[Transform3D]=[]
 var globals:Array[Transform3D]=[]
 var feet:Array[Transform3D]=[]
 var shapes:Dictionary={}
 for i in native.parents.size():globals.append(native.inverse_frame*native.posed[i])
 for i in native.parents.size():
  var parent:int=native.parents[i]
  poses.append(globals[parent].affine_inverse()*globals[i] if parent>=0 else globals[i])
 for leg in native.legs:feet.append(native.inverse_frame*native.posed[leg.ids[2]])
 for index in native.mesh.mesh.get_blend_shape_count():shapes[native.mesh.mesh.get_blend_shape_name(index)]=native.mesh.get_blend_shape_value(index)
 return {"poses":poses,"feet":feet,"shapes":shapes}
func begin_preview(name:String) -> void:
 recovering=false;recovery_source.clear();airborne_source.clear()
 queued_preview=""
 preview_name=name;preview_clock=0;preview_done=false;chain_index=0
 var gait:=name.trim_suffix("_to_jump") if name.ends_with("_to_jump") else name.trim_prefix("jump_to_")
 if gait not in ["idle","walk","run"]:gait="idle"
 reset_motion(gait,jump_source_phase);position=Vector3.ZERO
 jump_origin=gait;jump_target=gait;jump_speed=current_speed
 segment_name=Jump.CHAIN[0] if name=="jump_transitions" else name
 preview_stage="lead";stage_time=0;jump_time=0
 jump_state=Jump.preview(0,jump_speed)
 if name.begins_with("jump_to_"):
  # An isolated exit starts at the exact apex pose used by the entry.
  var remaining:float=Jump.LEAD_IN+Jump.apex_time()
  while remaining>.0000001:
   var dt:float=minf(1.0/120,remaining);remaining-=dt;step_preview(dt)
  preview_clock=0;preview_done=false;preview_stage="flight"
  jump_target=gait
func seek_jump(seconds:float,gait:String) -> void:seek_preview(gait,seconds)
func seek_preview(name:String,seconds:float) -> void:
 var t:=maxf(0,seconds)
 if name!=preview_name or t<preview_clock-.0000001:begin_preview(name)
 advance_jump_preview(t-preview_clock)
func advance_jump_preview(delta:float) -> void:
 var remaining:=maxf(0,delta)
 while remaining>.0000001 and not preview_done:
  var dt:=minf(remaining,1.0/120);remaining-=dt
  step_preview(dt);preview_clock+=dt
func step_preview(dt:float) -> void:
 if preview_stage in ["lead","prepare","push"]:
  var limit:float=Jump.LEAD_IN if preview_stage=="lead" else (Jump.PREPARE if preview_stage=="prepare" else Jump.PUSH)
  if preview_stage=="lead" and not recipe.is_empty():limit=maxf(limit,stage_time+dt)
  var step:float=minf(dt,maxf(0,limit-stage_time))
  advance_transition(step);stage_time+=step
  if preview_stage!="lead":
   jump_time=(0.0 if preview_stage=="prepare" else Jump.PREPARE)+stage_time
   var source:=capture_pose()
   jump_state=Jump.preview(jump_time,jump_speed)
   apply_jump_pose(source,sampler.sample("idle",0),jump_state)
   if preview_stage=="push" and stage_time>=limit-.0000001:
    airborne_source=source;takeoff_distance=distance_m
  position=Vector3(0,0,distance_m)
  if stage_time>=limit-.0000001 and (preview_stage!="lead" or recipe.is_empty()):
   if preview_stage=="lead":jump_speed=current_speed
   preview_stage={"lead":"prepare","prepare":"push","push":"flight"}[preview_stage];stage_time=0
  if dt-step>.0000001:step_preview(dt-step)
  return
 if preview_stage=="flight":
  var entry_only:=segment_name.ends_with("_to_jump")
  var end_time:float=Jump.apex_time() if entry_only else Jump.duration()
  var step:float=minf(dt,maxf(0,end_time-jump_time))
  jump_time+=step
  jump_state=Jump.preview(jump_time,jump_speed)
  distance_m=takeoff_distance+jump_speed*(jump_time-Jump.PREPARE-Jump.PUSH)
  apply_jump_pose(airborne_source,sampler.sample("idle",0),jump_state)
  position=Vector3(0,jump_state.height,distance_m)
  if jump_time>=end_time-.0000001:
   if entry_only:
    if preview_name=="jump_transitions":
     chain_index=(chain_index+1)%Jump.CHAIN.size();segment_name=Jump.CHAIN[chain_index]
     jump_target=segment_name.trim_prefix("jump_to_")
    else:preview_done=true
   else:begin_recovery()
  if dt-step>.0000001 and not preview_done:step_preview(dt-step)
  return
 if preview_stage=="recovery":
  stage_time+=dt;recovery_weight=Jump.smooth5(stage_time/Jump.RECOVER)
  advance_transition(dt);position=Vector3(0,0,distance_m)
  jump_state.phase=5;jump_state.height=0;jump_state.vertical_velocity=0
  if stage_time>=Jump.RECOVER:
   recovering=false;recovery_source.clear();preview_stage="settle";stage_time=0
  return
 if preview_stage=="settle":
  advance_transition(dt);position=Vector3(0,0,distance_m);stage_time+=dt
  if stage_time>=Jump.SETTLE and recipe.is_empty():
   if not queued_preview.is_empty():
    var next:=queued_preview;queued_preview="";continue_on_ground(next)
   elif preview_name=="jump_transitions":
    chain_index=(chain_index+1)%Jump.CHAIN.size();segment_name=Jump.CHAIN[chain_index]
    jump_origin=segment_name.trim_suffix("_to_jump");jump_speed=current_speed
    preview_stage="lead";stage_time=0;jump_time=0
   else:preview_done=true
func begin_recovery() -> void:
 recovery_source=capture_pose();contact_distance=distance_m
 recovery_poles.clear()
 for leg in native.legs:
  var root:Vector3=native.posed[leg.ids[0]].origin
  var axis:Vector3=(native.posed[leg.ids[2]].origin-root).normalized()
  var knee:Vector3=native.posed[leg.ids[1]].origin-root
  recovery_poles.append((knee-axis*knee.dot(axis)).normalized())
 var landing_distance:=distance_m
 recovering=false
 # Resume the approved ground scheduler with the original momentum. Its
 # existing recipes brake/accelerate towards the requested exit gait.
 reset_motion(jump_origin)
 pelvis_lowering=0
 distance_m=landing_distance
 phase=maxf(0,support_fraction()-.10) if jump_origin!="idle" else 0.0
 for side in 2:
  var foot:Transform3D=native.frame*recovery_source.feet[side]
  var world:Vector3=foot.origin*SCALE+Vector3.BACK*distance_m
  contacts[side]={"planted":true,"anchor":world,"offset":Vector3.ZERO,"release":phase+side*.5,"basis":foot.basis,"nominal":world}
 if jump_origin!=jump_target:request_transition(jump_origin+"_to_"+jump_target)
 loading_hold=.22
 recovering=true;recovery_weight=0;stage_time=0;preview_stage="recovery"
 render_pose(0)
 jump_state.phase=5;jump_state.grounded=true;jump_state.height=0;jump_state.vertical_velocity=0
 position=Vector3(0,0,distance_m)
func solve_contacts() -> void:
 var original_poles:Dictionary={}
 if recovering and recovery_weight<1:
  # Feed the existing knee-plane stabilizer the same continuous reference as
  # the body crossfade; touchdown must not switch its reference instantaneously.
  original_poles=sampler.knee_poles
  sampler.knee_poles=original_poles.duplicate(true)
  for gait in original_poles:
   for side in 2:sampler.knee_poles[gait][side]=recovery_poles[side].lerp(original_poles[gait][side],recovery_weight).normalized()
 if recovering and not recovery_source.is_empty() and recovery_weight<1:
  var target:=capture_pose()
  for i in native.parents.size():
   var pose_weight:float=Jump.smooth5(stage_time/.16) if i==native.binding.bone(&"root") else recovery_weight
   var local:Transform3D=recovery_source.poses[i].interpolate_with(target.poses[i],pose_weight)
   var parent:int=native.parents[i]
   native.local_globals[i]=native.local_globals[parent]*local if parent>=0 else local
   native.posed[i]=native.frame*native.local_globals[i]
  for side in 2:
   var landing:Transform3D=native.frame*recovery_source.feet[side]
   landing.origin.z-=(distance_m-contact_distance)/SCALE
   sampled_feet[side]=landing.interpolate_with(sampled_feet[side],Jump.smooth5(stage_time/.16))
 super.solve_contacts()
 if not original_poles.is_empty():sampler.knee_poles=original_poles

func request_preview(name:String) -> void:
 # Changing the menu while airborne selects an exit without restarting flight.
 if name.begins_with("jump_to_") and (preview_stage in ["prepare","push","flight"] or (preview_stage=="lead" and preview_clock>.0000001)):
  preview_name=name;segment_name=name;jump_target=name.trim_prefix("jump_to_");preview_done=false
  return
 if preview_name.is_empty() or (preview_clock<=.0000001 and preview_stage=="lead"):begin_preview(name);return
 if preview_stage=="lead" or (preview_done and preview_stage=="settle"):continue_on_ground(name);return
 preview_done=false
 queued_preview=name
 if preview_stage=="flight" or segment_name.ends_with("_to_jump"):
  segment_name="jump_to_"+jump_origin;jump_target=jump_origin
  preview_name="queued"
func continue_on_ground(name:String) -> void:
 var previous_gait:=jump_target
 var gait:=name.trim_suffix("_to_jump") if name.ends_with("_to_jump") else name
 if name.begins_with("jump_to_"):gait=previous_gait
 if gait not in ["idle","walk","run"]:gait="idle"
 preview_name=name;segment_name=Jump.CHAIN[0] if name=="jump_transitions" else name
 preview_clock=0;preview_done=false;chain_index=0;jump_origin=gait
 jump_target=name.trim_prefix("jump_to_") if name.begins_with("jump_to_") else gait
 if previous_gait!=gait:request_transition(previous_gait+"_to_"+gait)
 preview_stage="lead";stage_time=0;jump_time=0

func set_style(value:String) -> void:
 # Parent setup constructs several sampler stages before the balanced sampler.
 recovering=false;recovery_source.clear();preview_name="";preview_stage=""
 super.set_style(value)
