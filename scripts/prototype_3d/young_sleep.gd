extends RefCounted
## Quiet curled rest, reusing the existing seated supports and original rig.
static func sample(quad:Dictionary,seated:Dictionary,state:StringName,t:float) -> Dictionary:
 var rest:=seated.duplicate(true)
 var hip:Vector3=rest.body*Vector3(0,8.5,-6)
 var basis:=Basis(Vector3.RIGHT,.19)
 rest.body=Transform3D(basis,hip+Vector3(0,.05,0)-basis*Vector3(0,8.5,-6))
 rest.head=Basis(Vector3.RIGHT,.23)
 for side in 2:rest.hands[side]=Vector3((-1 if side==0 else 1)*11.8,5.65,11.8)
 var amount:=1.0 if state==&"sleep" else smoothstep(0,1,t if state==&"sleep_down" else 1-t)
 var pose:=quad.duplicate(true)
 pose.body=(quad.body as Transform3D).interpolate_with(rest.body,amount)
 pose.head=(quad.head as Basis).slerp(rest.head,amount)
 for side in 2:
  pose.feet[side]=(quad.feet[side] as Vector3).lerp(rest.feet[side],amount)
  pose.hands[side]=(quad.hands[side] as Vector3).lerp(rest.hands[side],amount)
 if state==&"sleep":
  var breath:=sin(t*TAU)
  pose.body.origin.y+=breath*.035
  pose.head=rest.head*Basis(Vector3.RIGHT,breath*.003)
 return pose
