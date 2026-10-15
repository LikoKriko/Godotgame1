extends RefCounted
## Bent-leg hip slide. Pose only: speed, duration, input and air steering stay in
## locomotion.gd. Authored kinematics are not a measured motion-capture clip.
const Aim=preload("res://scripts/prototype_3d/tool_aim.gd")
const Anatomy=preload("res://scripts/prototype_3d/survivor_anatomy.gd")
static func apply(pose:Dictionary,phase:float) -> void:
 var t:=clampf(phase,0,1)
 var enter:=smoothstep(0,0.28,t);var rise:=smoothstep(0.69,1,t)
 var basis:=Basis.from_euler(Vector3(-0.22,0.09,0.18))
 var pivot:=Vector3(0,Anatomy.HIP.y,0)
 var pelvis:=Vector3(0.6,4.7,-1.2)
 var glide:=Transform3D(basis,pelvis-basis*pivot)
 # Recover to a low, balanced stance; the runtime blends into walking/crouching.
 var recover_basis:=Basis(Vector3.RIGHT,0.12)
 var recover:=Transform3D(recover_basis,Vector3(0,20.9,0)-recover_basis*pivot)
 var body:Transform3D=(pose.body as Transform3D).interpolate_with(glide,enter).interpolate_with(recover,rise)
 var glide_feet:Array[Vector3]=[Vector3(-6,2.8,5.7),Vector3(4.7,2.1,26.2)]
 var neutral_feet:Array[Vector3]=[Vector3(-Anatomy.HIP.x,2.1,0),Vector3(Anatomy.HIP.x,2.1,0)]
 var amount:=enter*(1-rise)
 for side in 2:
  pose.hips[side]=body*Vector3((-1 if side==0 else 1)*Anatomy.HIP.x,Anatomy.HIP.y,0)
  pose.shoulders[side]=body*Vector3((-1 if side==0 else 1)*Anatomy.SHOULDER.x,Anatomy.SHOULDER.y,Anatomy.SHOULDER.z)
  pose.legs[side].end=(pose.legs[side].end as Vector3).lerp(glide_feet[side],enter).lerp(neutral_feet[side],rise)
  pose.legs[side].pitch=lerpf(pose.legs[side].pitch,-0.18 if side==0 else -0.32,amount)*(1-rise)
  var hand:=body*Vector3(-10.5 if side==0 else 10.5,44,9)
  pose.hands[side]=(pose.hands[side] as Vector3).lerp(hand,enter)
  # The folded knee opens sideways; the leading knee stays above its heel.
  var pole:=Vector3(-1,0.10,-0.15) if side==0 else Vector3(0.05,1,0.15)
  pose.leg_poles[side]=Vector3.BACK.lerp(pole.normalized(),amount).normalized()
 pose.grip=(pose.grip as Vector3).lerp(body*Vector3(-3.36,37,8.5),enter)
 pose.shaft=(pose.shaft as Vector3).lerp(body.basis*Vector3(0.25,0.88,0.40).normalized(),enter).normalized()
 pose.body=body
static func jump_from(pose:Dictionary,launch:Dictionary,phase:float) -> void:
 var amount:=smoothstep(0,0.45,phase)
 var target_frame:Basis=pose.get("tool_basis",Aim.frame(pose.shaft))
 var launch_frame:Basis=launch.get("tool_basis",Aim.frame(launch.shaft))
 var body:Transform3D=(launch.body as Transform3D).interpolate_with(pose.body,amount)
 for side in 2:
  pose.hips[side]=body*Vector3((-1 if side==0 else 1)*Anatomy.HIP.x,Anatomy.HIP.y,0)
  pose.shoulders[side]=body*Vector3((-1 if side==0 else 1)*Anatomy.SHOULDER.x,Anatomy.SHOULDER.y,Anatomy.SHOULDER.z)
  pose.legs[side].end=(launch.legs[side].end as Vector3).lerp(pose.legs[side].end,amount)
  pose.legs[side].pitch=lerpf(launch.legs[side].pitch,pose.legs[side].pitch,amount)
  pose.hands[side]=(launch.hands[side] as Vector3).lerp(pose.hands[side],amount)
  pose.leg_poles[side]=(launch.leg_poles[side] as Vector3).lerp(pose.leg_poles[side],amount).normalized()
 pose.body=body;pose.grip=(launch.grip as Vector3).lerp(pose.grip,amount)
 pose.tool_basis=launch_frame.slerp(target_frame,amount);pose.shaft=pose.tool_basis.y
