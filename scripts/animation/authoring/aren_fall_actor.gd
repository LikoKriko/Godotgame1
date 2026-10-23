extends "res://scripts/animation/authoring/aren_jump_actor.gd"
## Shared falling poses; the viewer supplies ballistics and gameplay supplies collisions.
const Fall=preload("res://scripts/animation/authoring/aren_fall_motion.gd")
const FallResponse=preload("res://scripts/animation/terrain/aren_fall_response.gd")
var fall_response=FallResponse.new()
var review_height:=1.5
var drop_height:=1.5
var floor_y:=-1.5
var ledge_y:=0.0
var ledge_z:=0.0
var fall_time:=0.0
var base_y:=0.0
var fall_contacts:Array[bool]=[]
var fall_chain:=0
var neutral_fall:Dictionary={}
var fall_recovery_scale:=1.0
var external_support_feet:Array[Transform3D]=[]
func begin_preview(name:String) -> void:
 recovering=false;recovery_source.clear();airborne_source.clear();queued_preview=""
 preview_name=name;preview_clock=0;preview_done=false;fall_chain=0
 jump_origin=Fall.gait_for(name);jump_target=jump_origin
 if name=="fall_sequences":jump_origin="idle";jump_target="idle"
 reset_motion(jump_origin,jump_source_phase);position=Vector3.ZERO;base_y=0
 segment_name=Fall.CHAIN[0] if name=="fall_sequences" else name
 setup_ledge()
func setup_ledge() -> void:
 drop_height=Fall.height_for(segment_name,review_height)
 floor_y=base_y-drop_height;ledge_y=base_y;ledge_z=distance_m+speed_for(jump_origin)*Fall.LEAD_IN
 preview_stage="lead";stage_time=0;fall_time=0;jump_speed=current_speed;fall_recovery_scale=1.0
 fall_response.reset()
 jump_state={"phase":0,"time":0.0,"air_time":0.0,"height":0.0,"vertical_velocity":0.0,"grounded":true,"finished":false}
func request_preview(name:String) -> void:
 if preview_name.is_empty() or (preview_stage=="lead" and preview_clock==0):begin_preview(name);return
 if preview_done:
  queued_preview=name;preview_done=false
 else:queued_preview=name
func preview_duration(name:String="") -> float:
 return Fall.LEAD_IN+Fall.flight_duration(drop_height)+Fall.recovery_duration(drop_height)+Jump.SETTLE
func step_preview(dt:float) -> void:
 if preview_stage=="lead":
  var limit:float=Fall.LEAD_IN
  if not recipe.is_empty():limit=maxf(limit,stage_time+dt)
  var step:float=minf(dt,maxf(0,limit-stage_time))
  advance_transition(step);position=Vector3(0,base_y,distance_m);stage_time+=step
  if stage_time>=limit-.0000001 and recipe.is_empty():
   airborne_source=capture_pose();takeoff_distance=distance_m;jump_speed=current_speed
   fall_contacts.clear()
   for side in 2:fall_contacts.append(contacts[side].planted)
   preview_stage="fall";stage_time=0
  if dt-step>.0000001:step_preview(dt-step)
  return
 if preview_stage=="fall":
  var duration:=Fall.flight_duration(drop_height)
  var step:float=minf(dt,maxf(0,duration-fall_time));fall_time+=step
  var vy:float=-Jump.GRAVITY*fall_time
  var drop:float=.5*Jump.GRAVITY*fall_time*fall_time
  fall_response.update(step,false,vy,maxf(0,drop_height-drop))
  distance_m=takeoff_distance+jump_speed*fall_time
  position=Vector3(0,base_y-drop,distance_m)
  if neutral_fall.is_empty():neutral_fall=sampler.sample("idle",0)
  apply_fall_pose(airborne_source,neutral_fall,vy,maxf(0,drop_height-drop))
  jump_state={"phase":fall_phase(),"time":fall_time,"air_time":fall_time,"height":drop,"vertical_velocity":vy,"grounded":false,"finished":false}
  if fall_time>=duration-.0000001:
   begin_recovery();jump_state.phase=4;jump_state.height=drop_height;position.y=floor_y
  if dt-step>.0000001:step_preview(dt-step)
  return
 if preview_stage=="recovery":
  stage_time+=dt;recovery_weight=Jump.smooth5(stage_time/Fall.recovery_duration(drop_height))
  advance_transition(dt);position=Vector3(0,floor_y,distance_m)
  jump_state.phase=4;jump_state.vertical_velocity=0;jump_state.grounded=true
  fall_response.update(dt,true,0,0)
  if stage_time>=Fall.recovery_duration(drop_height):
   recovering=false;recovery_source.clear();preview_stage="settle";stage_time=0
  return
 if preview_stage=="settle":
  advance_transition(dt);position=Vector3(0,floor_y,distance_m);stage_time+=dt
  if stage_time>=Jump.SETTLE and recipe.is_empty():
   if not queued_preview.is_empty():
    var next:=queued_preview;queued_preview="";continue_fall(next)
   elif preview_name=="fall_sequences":
    fall_chain=(fall_chain+1)%Fall.CHAIN.size();continue_fall(Fall.CHAIN[fall_chain],true)
   else:preview_done=true
func continue_fall(name:String,chained:bool=false) -> void:
 var previous:=jump_origin
 base_y=floor_y;jump_origin=Fall.gait_for(name);jump_target=jump_origin
 if not chained:preview_name=name;preview_clock=0
 segment_name=name
 if previous!=jump_origin:request_transition(previous+"_to_"+jump_origin)
 setup_ledge()
func fall_phase() -> int:
 if fall_response.mode!="falling":return 0
 if fall_time>Fall.flight_duration(drop_height)-.10:return 3
 return 1 if fall_response.fall_time<.22 else 2
func apply_fall_pose(source:Dictionary,neutral:Dictionary,velocity_y:float,ground_gap:float,release_time:float=-1.0) -> void:
 # Reuse approved descending leg/torso targets, never the launch or anticipation.
 var near_ground:float=1-Jump.smooth5(ground_gap/.65)
 var synthetic_vy:float=lerpf(-1.2,-Jump.LAUNCH_SPEED,near_ground)
 var state:Dictionary={"air_time":.5+fall_time,"time":Jump.duration(),"grounded":false,"vertical_velocity":synthetic_vy}
 super.apply_jump_pose(source,neutral,state)
 var base_feet:Array[Transform3D]=[]
 for leg in native.legs:base_feet.append(native.inverse_frame*native.posed[leg.ids[2]])
 var speed_weight:=Jump.smooth5(absf(velocity_y)/14.0)
 var reaction:float=1-exp(-fall_time/ .20)
 var hip:int=native.binding.bone(&"root")
 var lean:float=deg_to_rad(3+4*speed_weight)
 var roll:float=deg_to_rad(2)*exp(-fall_time/.65)
 Torso.rotate_branch(native,hip,Basis.from_euler(Vector3(lean*.3,0,roll*.3))*native.posed[hip].basis,native.posed[hip].origin)
 for id in native.spine:Torso.rotate_branch(native,id,Basis.from_euler(Vector3(lean*.7/3,0,roll*.7/3))*native.posed[id].basis,native.posed[id].origin)
 Torso.rotate_branch(native,native.neck,Basis(Vector3.RIGHT,-lean*.4)*native.posed[native.neck].basis,native.posed[native.neck].origin)
 for side in 2:
  var arm:Array=native.arms[side].ids
  var sign_side:float=1 if side==0 else -1
  var spread:float=deg_to_rad(14+15*speed_weight+3*sign_side*exp(-fall_time/.55))
  var pitch:float=deg_to_rad(-4-6*reaction*sign_side)
  Torso.rotate_branch(native,arm[1],Basis(Vector3.FORWARD,spread*sign_side)*Basis(Vector3.RIGHT,pitch)*native.posed[arm[1]].basis,native.posed[arm[1]].origin)
  Torso.rotate_branch(native,arm[2],Basis(Vector3.RIGHT,-deg_to_rad(8+10*speed_weight))*native.posed[arm[2]].basis,native.posed[arm[2]].origin)
 var target:=capture_pose()
 # Gameplay releases the body from the first unsupported tick. Classification
 # grace still rejects small terrain gaps; the approved viewer keeps its clock.
 var release:float=release_time if release_time>=0 else (fall_response.fall_time if fall_response.mode=="falling" else 0.0)
 var weight:=Jump.smooth5(release/Fall.BODY_RELEASE)
 for i in native.parents.size():
  var local:Transform3D=source.poses[i].interpolate_with(target.poses[i],weight)
  var parent:int=native.parents[i]
  native.local_globals[i]=native.local_globals[parent]*local if parent>=0 else local
  native.posed[i]=native.frame*native.local_globals[i]
 jump_ik_error_m=0
 for side in 2:
  var leg:Dictionary=native.legs[side];var ids:Array=leg.ids
  var root:Vector3=native.posed[ids[0]].origin
  var foot:Transform3D=(native.frame*source.feet[side]).interpolate_with(native.frame*base_feet[side],weight)
  var axis:Vector3=(foot.origin-root).normalized()
  var radial:Vector3=native.posed[ids[1]].origin-root
  radial=(radial-axis*radial.dot(axis)).normalized()
  var anchor:Transform3D=native.frame*source.feet[side]
  if external_support_feet.size()==2:anchor=external_support_feet[side]
  else:anchor.origin+=(Vector3(0,base_y,takeoff_distance)-position)/SCALE
  var support:float=fall_response.support_weight if fall_contacts[side] else 0.0
  var goal:Vector3=foot.origin.lerp(anchor.origin,support)
  var solution:=Solver.joint(root,goal,leg.a,leg.b,radial)
  native.untwisted_chain(ids,0,solution,Basis.IDENTITY)
  Torso.rotate_branch(native,ids[2],foot.basis,solution.end)
  var cosine:float=clampf((solution.joint-solution.root).normalized().dot((solution.end-solution.joint).normalized()),-1,1)
  native.mesh.set_blend_shape_value(native.knee_shapes[side],.5*(1-cosine)*(1-smoothstep(deg_to_rad(115),deg_to_rad(145),acos(cosine))))
 for i in native.posed.size():native.local_globals[i]=native.inverse_frame*native.posed[i]
 native.writer.apply(native.skeleton,native.local_globals)

func set_style(value:String) -> void:
 neutral_fall.clear()
 super.set_style(value)

func begin_recovery() -> void:
 fall_recovery_scale=Fall.recovery_scale(drop_height)
 super.begin_recovery()
 loading_hold=.22*fall_recovery_scale

func solve_contacts() -> void:
 var unscaled:=loading
 loading*=fall_recovery_scale
 super.solve_contacts()
 loading=unscaled
