extends RefCounted
## Constrain spurious IK pole drift, never clamp a correct knee flexion angle.
const Torso=preload("res://scripts/animation/authoring/aren_torso_flow.gd")
static func stabilize(native:RefCounted,side:int,source_pole:Vector3,state:Dictionary,dt:float) -> bool:
 var ids:Array=native.legs[side].ids
 var hip:Vector3=native.posed[ids[0]].origin
 var knee:Vector3=native.posed[ids[1]].origin
 var foot:Transform3D=native.posed[ids[2]]
 var axis:Vector3=(foot.origin-hip).normalized()
 var centre:Vector3=hip+axis*(knee-hip).dot(axis)
 var radial:Vector3=knee-centre
 if radial.length_squared()<.000001:return false
 var forward:Vector3=(Vector3.BACK-axis*axis.dot(Vector3.BACK)).normalized()
 var target:Vector3=(source_pole-axis*axis.dot(source_pole)).normalized()
 if target.dot(forward)<=0:target=forward
 var current:=radial.normalized()
 var deviation:=acos(clampf(current.dot(target),-1,1))
 var margin:float=asin(clampf(target.dot(forward),.001,1))
 var begin:float=minf(deg_to_rad(15),margin*.4)
 var end:float=minf(deg_to_rad(45),margin*.95)
 var u:=clampf((deviation-begin)/maxf(end-begin,.0001),0,1)
 var weight:float=u*u*u*(u*(u*6-15)+10)
 # Blend back to the sampled anatomical pole before its projection can invert.
 # Above the bound it is exactly the source direction, including at 180°.
 var direction:=current.lerp(target,weight).normalized()
 var correcting:=deviation>begin
 # Keep the plane continuous when the original IK pole crosses its singularity.
 # Track valid source motion directly; only ease an active correction/release.
 if dt>0 and (correcting or state.active) and state.direction!=Vector3.ZERO:
  var previous:Vector3=state.direction-axis*axis.dot(state.direction)
  previous=previous.normalized()
  var angle:=acos(clampf(previous.dot(direction),-1,1))
  direction=previous.slerp(direction,minf(1,deg_to_rad(180)*dt/maxf(angle,.000001))).normalized()
  state.active=correcting or direction.dot(current)<.999999
 else:state.active=correcting
 if direction.dot(forward)<=0:direction=target
 state.direction=direction
 if direction.dot(current)>.9999999:return false
 var solution:Dictionary={"root":hip,"joint":centre+direction*radial.length(),"end":foot.origin}
 native.untwisted_chain(ids,0,solution,Basis.IDENTITY)
 Torso.rotate_branch(native,ids[2],foot.basis,foot.origin)
 return true
