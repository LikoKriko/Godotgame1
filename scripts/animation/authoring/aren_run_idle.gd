extends RefCounted
## Parameterized full-chain layers. Source rest, skin and gait contacts stay native.
const Torso=preload("res://scripts/animation/authoring/aren_torso_flow.gd")
const Solver=preload("res://scripts/continuous_body_pose.gd")
static func running(native:RefCounted,phase:float,p:Dictionary,reference:Dictionary) -> void:
 if p.run_flow<=0:return
 var current:=Torso.capture(native)
 var hip:int=native.binding.bone(&"root")
 var pelvis_dynamic:Vector3=(current.angles[0]-reference.angles[0])*.6
 var centre:Vector3=reference.angles[0];centre.x*=p.run_posture
 var target:Vector3=centre+pelvis_dynamic
 var origin:Vector3=reference.centre+(current.origin-reference.centre)*.65
 Torso.rotate_branch(native,hip,Basis.from_euler(current.angles[0].lerp(target,p.run_flow))*native.rest[hip].basis,current.origin.lerp(origin,p.run_flow))
 var chest_dynamic:Vector3=(current.angles[3]-reference.angles[3])*p.run_body_motion
 chest_dynamic.x+=deg_to_rad(.1)*cos(phase*TAU*2)
 var shares:Array[float]=[.30,.65,1.0]
 for i in native.spine.size():
  var id:int=native.spine[i]
  centre=reference.angles[i+1];centre.x*=p.run_posture
  target=centre+pelvis_dynamic.lerp(chest_dynamic,shares[i])
  var angles:Vector3=current.angles[i+1].lerp(target,p.run_flow)
  Torso.rotate_branch(native,id,Basis.from_euler(angles)*native.rest[id].basis,native.posed[id].origin)
 for i in 2:
  var id:int=native.neck if i==0 else native.head
  centre=reference.angles[4+i];centre.x*=lerpf(1.0,p.run_posture,.7)
  target=centre+(current.angles[4+i]-reference.angles[4+i])*p.run_body_motion
  Torso.rotate_branch(native,id,Basis.from_euler(current.angles[4+i].lerp(target,p.run_flow))*native.rest[id].basis,native.posed[id].origin)
static func resting(native:RefCounted,phase:float,p:Dictionary) -> void:
 # Start from the same relaxed pose every sample, not the one-second hip bob.
 var goals:Array[Transform3D]=[]
 for leg in native.legs:goals.append(native.posed[leg.ids[2]])
 var wave:float=sin(phase*TAU)*p.idle_breath*p.idle_flow
 var balance:Vector3=Vector3(sin(phase*TAU+PI/3)*.025,0,sin(phase*TAU*2)*.015)*p.idle_balance*p.idle_flow
 for i in native.posed.size():native.posed[i].origin+=balance
 var shares:Array[float]=[.05,.16,.38]
 # These are cumulative thoracic angles, not scale changes to the bones.
 for i in native.spine.size():
  var id:int=native.spine[i]
  var parent_pitch:float=shares[i-1] if i>0 else 0.0
  var rotation:=Basis(Vector3.RIGHT,deg_to_rad(shares[i]-parent_pitch)*wave)
  Torso.rotate_branch(native,id,rotation*native.posed[id].basis,native.posed[id].origin)
 var compensation:=Basis(Vector3.RIGHT,-deg_to_rad(.30)*wave)
 Torso.rotate_branch(native,native.neck,compensation*native.posed[native.neck].basis,native.posed[native.neck].origin)
 for side in 2:
  var arm:Dictionary=native.arms[side]
  var clavicle:int=arm.ids[0]
  var rotation:=Basis(Vector3.FORWARD,deg_to_rad(.08)*wave*(-1 if side==0 else 1))
  Torso.rotate_branch(native,clavicle,rotation*native.posed[clavicle].basis,native.posed[clavicle].origin)
  var leg:Dictionary=native.legs[side];var ids:Array=leg.ids
  var solved:=Solver.joint(native.posed[ids[0]].origin,goals[side].origin,leg.a,leg.b,Vector3.BACK)
  native.untwisted_chain(ids,0,solved,Basis.IDENTITY)
  Torso.rotate_branch(native,ids[2],goals[side].basis,solved.end)
  var cosine:float=clampf((solved.joint-solved.root).normalized().dot((solved.end-solved.joint).normalized()),-1,1)
  native.mesh.set_blend_shape_value(native.knee_shapes[side],.5*(1-cosine)*(1-smoothstep(deg_to_rad(115),deg_to_rad(145),acos(cosine))))
static func swing_clearance(hip:Vector3,target:Vector3,length:float,phase:float,support:float) -> Vector3:
 var cycle:=fposmod(phase,1.0)
 if cycle<support:return target
 var u:float=(cycle-support)/(1-support)
 var horizontal:=Vector2(target.x-hip.x,target.z-hip.z).length_squared()
 var minimum_y:float=hip.y-sqrt(maxf(.01,length*length-horizontal))
 var needed:float=minimum_y-target.y
 # Smooth positive part and C2 toe-off/landing fade avoid IK reach clipping.
 var lift:float=.5*(needed+sqrt(needed*needed+.0001))
 var a:=clampf(u/.04,0,1);var b:=clampf((1-u)/.04,0,1)
 var fade:float=a*a*a*(a*(a*6-15)+10)*b*b*b*(b*(b*6-15)+10)
 target.y+=lift*fade
 return target
