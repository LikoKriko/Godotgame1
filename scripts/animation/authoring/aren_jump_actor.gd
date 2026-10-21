extends "res://scripts/animation/authoring/aren_run_balanced_actor.gd"
## Review-only opt-in layer. Approved libraries and terrain IK are untouched.
const Jump=preload("res://scripts/animation/authoring/aren_jump_motion.gd")
var jump_state:Dictionary={}
var jump_source_phase:=.0
var jump_ik_error_m:=0.0
func seek_jump(seconds:float,gait:String) -> void:
 jump_state=Jump.preview(seconds,speed_for(gait))
 var ground_time:float=minf(jump_state.time,Jump.PREPARE+Jump.PUSH)
 var duration:float=sampler.clips[gait].length
 var source:=sampler.sample(gait,jump_source_phase*duration+ground_time)
 var neutral:=sampler.sample("idle",0)
 apply_jump_pose(source,neutral,jump_state)
 position=Vector3(0,jump_state.height,jump_state.distance)
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
 var hip:int=native.binding.bone(&"root")
 var lowering:float=.065*load_weight
 var pitch:float=deg_to_rad(7)*load_weight
 var air_progress:float=clampf((Jump.LAUNCH_SPEED-float(state.vertical_velocity))/(2*Jump.LAUNCH_SPEED),0,1)
 var gather:float=sin(air_progress*PI)
 if not state.grounded:pitch=deg_to_rad(2+2*gather)*airborne
 Torso.rotate_branch(native,hip,Basis(Vector3.RIGHT,pitch*.3)*native.posed[hip].basis,native.posed[hip].origin-Vector3.UP*lowering/SCALE)
 for i in native.spine.size():
  var id:int=native.spine[i]
  Torso.rotate_branch(native,id,Basis(Vector3.RIGHT,pitch*.7/3)*native.posed[id].basis,native.posed[id].origin)
 Torso.rotate_branch(native,native.neck,Basis(Vector3.RIGHT,-pitch*.5)*native.posed[native.neck].basis,native.posed[native.neck].origin)
 # Arm swing continues through extension, then relaxes towards descent.
 var swing:float=deg_to_rad(15)*load_weight-deg_to_rad(40)*push_weight
 if not state.grounded:swing=lerpf(deg_to_rad(-40),deg_to_rad(-12),Jump.smooth5(air_progress))
 for side in 2:
  var arm:Array=native.arms[side].ids
  var sign_side:float=1 if side==0 else -1
  var spread:float=deg_to_rad(10)*airborne*sign_side
  var arm_id:int=arm[1]
  Torso.rotate_branch(native,arm_id,Basis(Vector3.FORWARD,spread)*Basis(Vector3.RIGHT,swing)*native.posed[arm_id].basis,native.posed[arm_id].origin)
  var elbow:int=arm[2]
  Torso.rotate_branch(native,elbow,Basis(Vector3.RIGHT,-deg_to_rad(12)*airborne*gather)*native.posed[elbow].basis,native.posed[elbow].origin)
 jump_ik_error_m=0
 for side in 2:
  var leg:Dictionary=native.legs[side];var ids:Array=leg.ids
  var foot:Transform3D=native.frame*source.feet[side]
  var root:Vector3=native.posed[ids[0]].origin
  var neutral_foot:Transform3D=native.frame*neutral.feet[side]
  var asymmetry:float=(1 if side==0 else -1)*minf(current_jump_speed()/4.5,1)*.025*gather
  var air_goal:=Vector3(root.x,root.y-(.77-.13*gather)/SCALE,(.035+.04*gather+asymmetry)/SCALE)
  var goal:Vector3=foot.origin.lerp(air_goal,airborne)
  var basis:Basis=Transform3D(foot.basis,Vector3.ZERO).interpolate_with(Transform3D(neutral_foot.basis,Vector3.ZERO),airborne).basis
  var plantar:float=deg_to_rad(9)*Jump.smooth5(float(state.air_time)/.06)*(1-Jump.smooth5(air_progress)) if not state.grounded else 0.0
  basis=Basis(Vector3.RIGHT,plantar)*basis
  var solution:=Solver.joint(root,goal,leg.a,leg.b,Vector3.BACK)
  jump_ik_error_m=maxf(jump_ik_error_m,solution.end.distance_to(goal)*SCALE)
  native.untwisted_chain(ids,0,solution,Basis.IDENTITY)
  Torso.rotate_branch(native,ids[2],basis,solution.end)
  var cosine:float=clampf((solution.joint-solution.root).normalized().dot((solution.end-solution.joint).normalized()),-1,1)
  var corrective:float=.5*(1-cosine)*(1-smoothstep(deg_to_rad(115),deg_to_rad(145),acos(cosine)))
  native.mesh.set_blend_shape_value(native.knee_shapes[side],corrective)
 for i in native.posed.size():native.local_globals[i]=native.inverse_frame*native.posed[i]
 native.writer.apply(native.skeleton,native.local_globals)
func current_jump_speed() -> float:
 return 0.0 if jump_state.is_empty() or jump_state.time<=0 else float(jump_state.distance)/float(jump_state.time)
