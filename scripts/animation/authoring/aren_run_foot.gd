extends RefCounted
## Phase-driven right-foot recovery; stance and the opposite foot remain untouched.
const Pose=preload("res://scripts/animation/authoring/aren_walk_upper_body.gd")
const Torso=preload("res://scripts/animation/authoring/aren_torso_flow.gd")
const Dynamics=preload("res://scripts/animation/authoring/aren_run_idle.gd")
const Solver=preload("res://scripts/continuous_body_pose.gd")
const SCALE=1.75/64.0
static func apply(native:RefCounted,sample:Dictionary,phase:float,support:float,p:Dictionary) -> Dictionary:
 var t:=fposmod(phase,1)
 if t<support:return sample
 Pose.restore_sample(native,sample)
 var u:float=(t-support)/(1-support)
 var leg:Dictionary=native.legs[0];var ids:Array=leg.ids
 var goal:Vector3=native.posed[ids[2]].origin
 var base_y:float=native.rest[ids[2]].origin.y+.30
 goal.y=base_y+(goal.y-base_y)*p.clearance_scale
 goal=Dynamics.swing_clearance(native.posed[ids[0]].origin,goal,leg.a+leg.b-.08,t,support)
 var clearance:float=maxf(0,(goal.y-base_y)*SCALE)
 var early:float=pow(u,3)*pow(1-u,6)/(pow(1.0/3,3)*pow(2.0/3,6))
 var late:float=pow(u,9)*pow(1-u,3)/(pow(.75,9)*pow(.25,3))
 var pitch:float=deg_to_rad(p.plantar_deg*early-p.dorsal_deg*late)
 # Remove ankle pitch near the ground; toe-off/landing remain C2 and flat.
 pitch*=smooth5(clampf(clearance/p.rotation_clearance_m,0,1))
 var basis:Basis=Basis(Vector3.RIGHT,pitch)*native.posed[ids[2]].basis
 var solution:=Solver.joint(native.posed[ids[0]].origin,goal,leg.a,leg.b,Vector3.BACK)
 native.untwisted_chain(ids,0,solution,Basis.IDENTITY)
 Torso.rotate_branch(native,ids[2],basis,solution.end)
 var cosine:float=clampf((solution.joint-solution.root).normalized().dot((solution.end-solution.joint).normalized()),-1,1)
 var name:String=native.mesh.mesh.get_blend_shape_name(native.knee_shapes[0])
 sample.shapes[name]=.5*(1-cosine)*(1-smoothstep(deg_to_rad(115),deg_to_rad(145),acos(cosine)))
 sample.feet[0]=native.inverse_frame*native.posed[ids[2]]
 var globals:Array[Transform3D]=[];var locals:Array[Transform3D]=[]
 for bone in native.parents.size():globals.append(native.inverse_frame*native.posed[bone])
 for bone in native.parents.size():
  var parent:int=native.parents[bone]
  locals.append(globals[parent].affine_inverse()*globals[bone] if parent>=0 else globals[bone])
 sample.poses=locals
 return sample
static func smooth5(t:float) -> float:return t*t*t*(t*(t*6-15)+10)
