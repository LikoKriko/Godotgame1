extends RefCounted
## Contact-speed-matched foot targets; shorten airborne overreach, not bone lengths.
const Pose=preload("res://scripts/animation/authoring/aren_walk_upper_body.gd")
const Torso=preload("res://scripts/animation/authoring/aren_torso_flow.gd")
const Solver=preload("res://scripts/continuous_body_pose.gd")
const Dynamics=preload("res://scripts/animation/authoring/aren_run_idle.gd")
const SCALE=1.75/64.0
static func smooth5(t:float) -> float:return t*t*t*(t*(t*6-15)+10)
static func foot(phase:float,p:Dictionary) -> Vector3:
 var t:=fposmod(phase,1)
 if t<p.support:return Vector3(0,0,lerpf(p.half,-p.half,t/p.support))
 var u:float=(t-p.support)/(1-p.support)
 var velocity:float=-2*p.half/p.support*(1-p.support)
 var z:float
 if u<p.release:
  var q:float=u/p.release
  z=-p.half+velocity*p.release*(q-(pow(q,6)-3*pow(q,5)+2.5*pow(q,4)))
 elif u>1-p.landing:
  var q:float=(1-u)/p.landing
  z=p.half-velocity*p.landing*(q-(pow(q,6)-3*pow(q,5)+2.5*pow(q,4)))
 else:z=lerpf(-p.half+velocity*p.release*.5,p.half-velocity*p.landing*.5,smooth5((u-p.release)/(1-p.release-p.landing)))
 var y:float=64*pow(u,3)*pow(1-u,3)*p.lift
 y+=p.heel_recovery_m/SCALE*pow(u,3)*pow(1-u,6)/(pow(1.0/3,3)*pow(2.0/3,6))
 return Vector3(0,y,z)
static func maximum_split(p:Dictionary) -> float:
 var maximum:=0.0
 for frame in 960:
  var phase:float=frame/960.0
  maximum=maxf(maximum,absf(foot(phase,p).z-foot(phase+.5,p).z)*SCALE)
 return maximum
static func apply(native:RefCounted,sample:Dictionary,phase:float,p:Dictionary) -> Dictionary:
 Pose.restore_sample(native,sample)
 var step:float=fposmod(phase,.5)
 var old_air:float=clampf((step-p.source_support)/maxf(.5-p.source_support,.001),0,1)
 var new_air:float=clampf((step-p.support)/maxf(.5-p.support,.001),0,1)
 var rise:float=p.flight_rise_m/SCALE*(pow(sin(PI*new_air),2)-pow(sin(PI*old_air),2))
 for bone in native.parents.size():native.posed[bone].origin.y+=rise
 var feet:Array[Transform3D]=[]
 for side in 2:
  var leg:Dictionary=native.legs[side];var ids:Array=leg.ids
  var t:float=phase+side*.5
  var goal:=foot(t,p)
  goal.x=native.rest[ids[2]].origin.x;goal.y+=native.rest[ids[2]].origin.y+.30
  goal=Dynamics.swing_clearance(native.posed[ids[0]].origin,goal,leg.a+leg.b-.08,t,p.support)
  var solution:=Solver.joint(native.posed[ids[0]].origin,goal,leg.a,leg.b,Vector3.BACK)
  var basis:Basis=native.posed[ids[2]].basis
  native.untwisted_chain(ids,0,solution,Basis.IDENTITY)
  Torso.rotate_branch(native,ids[2],basis,solution.end)
  feet.append(native.inverse_frame*native.posed[ids[2]])
  var cosine:float=clampf((solution.joint-solution.root).normalized().dot((solution.end-solution.joint).normalized()),-1,1)
  var name:String=native.mesh.mesh.get_blend_shape_name(native.knee_shapes[side])
  sample.shapes[name]=.5*(1-cosine)*(1-smoothstep(deg_to_rad(115),deg_to_rad(145),acos(cosine)))
 var globals:Array[Transform3D]=[];var locals:Array[Transform3D]=[]
 for bone in native.parents.size():globals.append(native.inverse_frame*native.posed[bone])
 for bone in native.parents.size():
  var parent:int=native.parents[bone]
  locals.append(globals[parent].affine_inverse()*globals[bone] if parent>=0 else globals[bone])
 sample.poses=locals;sample.feet=feet
 return sample
