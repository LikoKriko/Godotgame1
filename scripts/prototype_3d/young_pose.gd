extends RefCounted
## Short, bent hind legs and long front arms; never reuses human proportions.
const Joints = preload("res://scripts/continuous_body_pose.gd")
const ARM_A:=6.1
const ARM_B:=6.6
const LEG_A:=4.3
const LEG_B:=4.4
const HEAD_ANCHOR:=Vector3(0,22,7)
const SNOUT_OFFSET:=Vector3(0,-5.8811,14.8445)
const HIP_X:=7.0
const HIP_HEIGHT:=8.5
const HIP_Z:=-6.0
const SHOULDER_HEIGHT:=18.0
const SHOULDER_Z:=5.5
const FOOT_X:=8.4
const SHOULDER_X:=8.7
const REST_HAND:=Vector3(10.8,9.2,13.0)
static func blend(current:Dictionary,target:Dictionary,delta:float) -> Dictionary:
 var amount:=1-exp(-maxf(0,delta)*18)
 target.body=(current.body as Transform3D).interpolate_with(target.body,amount)
 target.head=(current.head as Basis).slerp(target.head,amount)
 target.standing=lerpf(current.standing,target.standing,amount)
 for side in 2:
  var sign_side:float=-1 if side==0 else 1
  var body:Transform3D=target.body
  var foot:Vector3=current.legs[side].end.lerp(target.legs[side].end,amount)
  var hand:Vector3=current.arms[side].end.lerp(target.arms[side].end,amount)
  target.legs[side]=Joints.joint(body*Vector3(sign_side*HIP_X,HIP_HEIGHT,HIP_Z),foot,LEG_A,LEG_B,body.basis*Vector3.BACK)
  target.arms[side]=Joints.joint(body*Vector3(sign_side*SHOULDER_X,SHOULDER_HEIGHT,SHOULDER_Z),hand,ARM_A,ARM_B,body.basis*Vector3(sign_side,0,-0.3))
 return target
static func sample(state: StringName,phase: float,left: bool = true) -> Dictionary:
 var walking:=state in [&"walk",&"run"]
 var standing:=1.0 if state==&"attack" else (smoothstep(0,1,phase) if state==&"rise" else (1-smoothstep(0,1,phase) if state==&"lower" else 0.0))
 var seated:=1.0 if state==&"sit" else (smoothstep(0,1,phase) if state==&"sit_down" else (1-smoothstep(0,1,phase) if state==&"sit_up" else 0.0))
 var fallen:=smoothstep(0,1,phase) if state in [&"stun_fall",&"death"] else (1-smoothstep(0,1,phase) if state==&"stun_rise" else (1.0 if state in [&"stun_hold",&"corpse"] else 0.0))
 var effort:=sin(phase*PI) if state==&"attack" else 0.0
 var lean:=lerpf(0.20,-0.04*effort,standing)
 lean=lerpf(lean,0.14,seated)
 var basis:=Basis(Vector3.RIGHT,lerpf(lean,1.45,fallen))
 if walking:basis=Basis(Vector3.BACK,0.025*sin(phase*TAU))*basis
 var pivot:=Vector3(0,HIP_HEIGHT,HIP_Z)
 var bob:float=-(0.25 if state==&"run" else 0.12)*(1-cos(phase*TAU*4)) if walking else -0.2*effort
 var recoil:=sin(clampf((phase-0.5)/0.18,0,1)*PI)*0.35 if state==&"attack" else 0.0
 var body:=Transform3D(basis,pivot-basis*pivot+Vector3(0,bob-3*seated-3.0*fallen,-recoil))
 var look:=lean*(1-standing)*(1-seated)*(1-fallen)+(0.045*sin(phase*TAU*2) if state==&"feed" else 0.0)
 var head_basis:=basis*Basis(Vector3.UP,sin(phase*TAU)*0.12*seated)*Basis(Vector3.RIGHT,-look)
 var legs: Array[Dictionary]=[];var arms: Array[Dictionary]=[]
 for side in 2:
  var sign_side:float=-1 if side==0 else 1
  var hind:=Joints.stance_swing(phase+side*0.5,4.5,1.5,0.6) if walking else {"z":0.0,"lift":0.0,"pitch":0.0}
  var front:=Joints.stance_swing(phase+0.25+side*0.5,4.5,1.25,0.6) if walking else {"z":0.0,"lift":0.0,"pitch":0.0}
  var foot:=Vector3(sign_side*FOOT_X,1.5+float(hind.lift),-4.5+float(hind.z))
  foot=foot.lerp(Vector3(sign_side*8.8,1.45,6),seated).lerp(Vector3(sign_side*9,1.5,-6),fallen)
  var leg:=Joints.joint(body*Vector3(sign_side*HIP_X,HIP_HEIGHT,HIP_Z),foot,LEG_A,LEG_B,basis*Vector3.BACK)
  leg.pitch=float(hind.pitch);legs.append(leg)
  var rest:=Vector3(sign_side*REST_HAND.x,REST_HAND.y,REST_HAND.z)
  var hand:=Vector3(sign_side*10.8,4.5+float(front.lift),14.0+float(front.z)).lerp(body*rest,standing)
  hand=hand.lerp(Vector3(sign_side*12.2,4,3),seated)
  if state==&"attack":
   var action:=Joints.gesture(rest,Vector3(sign_side*11.5,15.0,5.0),Vector3(sign_side*9.0,16.0,16.0),phase,&"fist") if (side==1)==left else rest.lerp(Vector3(sign_side*10.2,14.0,9.0),effort*0.5)
   hand=body*action
  hand=hand.lerp(Vector3(sign_side*16.3,4,12.2),fallen)
  arms.append(Joints.joint(body*Vector3(sign_side*SHOULDER_X,SHOULDER_HEIGHT,SHOULDER_Z),hand,ARM_A,ARM_B,basis*Vector3(sign_side,0,-0.3)))
 return {"body":body,"head":head_basis,"legs":legs,"arms":arms,"standing":standing}
