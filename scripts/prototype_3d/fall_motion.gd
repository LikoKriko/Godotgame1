extends RefCounted
## The same readable order for both anatomies: knees, loss of balance, spread.
const Controls=preload("res://scripts/animation/characters/survivor_controls.gd")
static func stages(phase:float) -> Vector3:
 var t:=clampf(phase,0,1)
 return Vector3(smoothstep(0,.38,t),smoothstep(.40,.84,t),smoothstep(.62,1,t))

static func human(pose:Dictionary,t:float) -> Dictionary:
 var keyed:=Controls.sample(&"death",t)
 var stage:Vector3=keyed.timing
 var basis:=Basis(Vector3.RIGHT,keyed.angles.x)
 pose.body=Transform3D(basis,keyed.hip-basis*Vector3(0,31,0));pose.pelvis=pose.body
 pose.head_basis=basis*Basis(Vector3.RIGHT,-.18*stage.y)
 pose.arm_poles=[];pose.foot_bases=[]
 for side in 2:
  var s:float=-1 if side==0 else 1
  pose.shoulders[side]=pose.body*Vector3(s*6.2,48,1.3)
  pose.hips[side]=pose.body*Vector3(s*3.6,31,0)
  pose.legs[side].end=keyed.foot_l if side==0 else keyed.foot_r;pose.legs[side].pitch=0.0
  pose.leg_poles[side]=keyed.pole_l if side==0 else keyed.pole_r
  var angles:Vector3=keyed.foot_angles_l if side==0 else keyed.foot_angles_r
  pose.foot_bases.append(Basis(Vector3.RIGHT,angles.x)*Basis(Vector3.UP,angles.y))
  pose.hands[side]=keyed.hand_l if side==0 else keyed.hand_r
  pose.arm_poles.append(Vector3(s,0,-.3).lerp(Vector3(s*.4,.15,1),stage.y))
 pose.grip=pose.hands[pose.active]
 return pose

static func young(t:float,initial:Dictionary,kneel_height:float=6.2,kneel_z:float=-7.8) -> Dictionary:
 var stage:=stages(t);var kneel:=stage.x;var fall:=stage.y;var spread:=stage.z
 var pose:=initial.duplicate(true)
 var pivot:=Vector3(0,8.5,-6)
 var hip:=Vector3(0,lerpf(8.5,kneel_height,kneel),-6)
 hip=hip.lerp(Vector3(0,10.2,-4),fall)
 hip.y-=1.30*smoothstep(.80,1,t)
 var pitch:=lerpf(.20,.14,kneel)
 pitch=lerpf(pitch,-PI/2,fall)
 var basis:=Basis(Vector3.RIGHT,pitch)
 pose.body=Transform3D(basis,hip-basis*pivot);pose.pelvis=pose.body
 pose.head=Basis.IDENTITY.slerp(basis,fall)
 pose.tail_turn=smoothstep(.36,.70,t)*1.72
 pose.standing=0.0;pose.adjust_sole=false
 pose.arm_poles=[];pose.leg_poles=[];pose.foot_bases=[]
 for side in 2:
  var s:float=-1 if side==0 else 1
  var foot:=Vector3(s*8.4,lerpf(1.5,2.35,kneel),lerpf(-4.5,kneel_z,kneel))
  pose.feet[side]=foot.lerp(Vector3(s*14,2.1,-3.5),fall)
  pose.feet[side].y+=4.5*sin(fall*PI/2)
  var foot_pitch:float=-PI/2*fall
  pose.pitches[side]=0.0
  pose.foot_bases.append(Basis(Vector3.RIGHT,foot_pitch)*Basis(Vector3.UP,s*.35*spread))
  var hand:Vector3=initial.hands[side]
  hand=hand.lerp(Vector3(s*12,5.5,11),kneel)
  hand=hand.lerp(Vector3(s*14,14.5,-8),fall)
  pose.hands[side]=hand.lerp(Vector3(s*18,15,-8),spread)
  pose.arm_poles.append(Vector3(s,1,.2))
  pose.leg_poles.append(Vector3(0,0,1).lerp(Vector3(s*.5,1,0),fall).normalized())
 return pose
