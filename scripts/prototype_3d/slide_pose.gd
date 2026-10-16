extends RefCounted
## Feet-first hip slide adapted to the imported Meshy anatomy. Pose only:
## speed, 0.46s duration and air steering remain in locomotion.gd.
const Aim=preload("res://scripts/prototype_3d/tool_aim.gd")
const Anatomy=preload("res://scripts/prototype_3d/survivor_anatomy.gd")
const Profiles=preload("res://scripts/prototype_3d/held_profiles.gd")
static func apply(pose:Dictionary,phase:float,backward:bool=false,lateral:float=0.0) -> void:
 var t:=clampf(phase,0,1)
 var enter:=smoothstep(0,.34,t)
 var rise:=smoothstep(.72,1,t)
 var load:=enter*(1-rise)
 var original:Transform3D=pose.body
 var pivot:=Vector3(0,Anatomy.HIP.y,0)
 # The outside of the folded leg and hip carry the body. Pelvis leans back;
 # the chest curls forward relative to it rather than staying a rigid plank.
 var hip_basis:=Basis.from_euler(Vector3(-.38,.06,.12))
 var glide:=Transform3D(hip_basis,Vector3(.3,5.0,-1.2)-hip_basis*pivot)
 if backward:
  # Hips lead the retreat; knees/feet remain in front, so this is not a
  # reversed forward slide. Curl the chest over the loaded bent-leg support.
  hip_basis=Basis.from_euler(Vector3(-.16,-.05,-.10))
  glide=Transform3D(hip_basis,Vector3(-.3,6.0,-3.0)-hip_basis*pivot)
 if backward and not is_zero_approx(lateral):
  hip_basis=Basis.from_euler(Vector3(-.16,-lateral*.12,-lateral*.15))
  glide=Transform3D(hip_basis,Vector3(lateral*1.3,6.0,-3.0)-hip_basis*pivot)
 var recovery_basis:=Basis(Vector3.RIGHT,.14)
 var recovery:=Transform3D(recovery_basis,Vector3(0,21.5,0)-recovery_basis*pivot)
 var pelvis:Transform3D=original.interpolate_with(glide,enter).interpolate_with(recovery,rise)
 var lumbar:=pelvis*Vector3(0,Anatomy.HIP.y+5.5,0)
 var curl:=Basis(pelvis.basis.x,(.34 if backward else .23)*load)
 var body:=Transform3D(curl,lumbar-curl*lumbar)*pelvis
 var feet:Array[Vector3]=[Vector3(-1.8,3.0,15.5),Vector3(4.7,2.5,27.0)]
 if backward:feet=[Vector3(-5.2,3.2,24.0),Vector3(4.5,3.4,12.0)]
 var turn:=Basis(Vector3.UP,-lateral*.30)
 if backward and lateral<0:feet=[Vector3(-feet[1].x,feet[1].y,feet[1].z),Vector3(-feet[0].x,feet[0].y,feet[0].z)]
 if backward and not is_zero_approx(lateral):
  for i in 2:feet[i]=turn*feet[i]
 var recover_feet:Array[Vector3]=[Vector3(-Anatomy.HIP.x,2.1,0),Vector3(Anatomy.HIP.x,2.1,0)]
 var family:StringName=pose.get("family",&"")
 var profile:Dictionary=Profiles.profile(family)
 for side in 2:
  var sign_side:float=-1 if side==0 else 1
  pose.hips[side]=pelvis*Vector3(sign_side*Anatomy.HIP.x,Anatomy.HIP.y,0)
  pose.shoulders[side]=body*Vector3(sign_side*Anatomy.SHOULDER.x,Anatomy.SHOULDER.y,Anatomy.SHOULDER.z)
  pose.legs[side].end=(pose.legs[side].end as Vector3).lerp(feet[side],enter).lerp(recover_feet[side],rise)
  var loaded_side:=1-side if backward and lateral<0 else side
  var ankle_pitch:float=(-.20 if loaded_side==0 else -.10) if backward else (-.08 if side==0 else -.16)
  pose.legs[side].pitch=lerpf(pose.legs[side].pitch,ankle_pitch,load)*(1-rise)
  # A stable knee plane opens the folded leg naturally, leaving space between
  # knee and hip. The old target folded the calf almost onto the thigh.
  var pole:=Vector3(-1,.22,.18) if side==0 else Vector3(.06,1,.18)
  if backward:
   pole=Vector3(-.12,1,.25) if loaded_side==0 else Vector3(1,.24,.25)
   if lateral<0:pole.x=-pole.x
   pole=turn*pole
  pose.leg_poles[side]=Vector3.BACK.lerp(pole.normalized(),load).normalized()
  var free:bool=family==&"" or (family!=&"bow" and not profile.two_hands and side!=pose.active)
  var hand:=body*Vector3(sign_side*(9.5 if free else 8.0),44.0 if free else 39.0,14.0 if free else 12.5)
  if backward:
   hand+=body.basis*Vector3(-lateral*1.2,maxf(0,-lateral*sign_side)*.8,0)
  pose.hands[side]=(pose.hands[side] as Vector3).lerp(hand,enter)
 pose.grip=(pose.grip as Vector3).lerp(body*Vector3(-3.36,40,11),enter)
 pose.shaft=(pose.shaft as Vector3).lerp(body.basis*Vector3(.25,.88,.40).normalized(),enter).normalized()
 pose.body=body;pose.pelvis=pelvis
 if backward:pose.leg_frame=Basis(Vector3.UP,-lateral*.30*load)
static func jump_from(pose:Dictionary,launch:Dictionary,phase:float) -> void:
 var amount:=smoothstep(0,.45,phase)
 var target_frame:Basis=pose.get("tool_basis",Aim.frame(pose.shaft))
 var launch_frame:Basis=launch.get("tool_basis",Aim.frame(launch.shaft))
 var body:Transform3D=(launch.body as Transform3D).interpolate_with(pose.body,amount)
 var pelvis:Transform3D=(launch.get("pelvis",launch.body) as Transform3D).interpolate_with(pose.get("pelvis",pose.body),amount)
 pose.leg_frame=(launch.get("leg_frame",Basis.IDENTITY) as Basis).slerp(pose.get("leg_frame",Basis.IDENTITY),amount)
 for side in 2:
  pose.hips[side]=pelvis*Vector3((-1 if side==0 else 1)*Anatomy.HIP.x,Anatomy.HIP.y,0)
  pose.shoulders[side]=body*Vector3((-1 if side==0 else 1)*Anatomy.SHOULDER.x,Anatomy.SHOULDER.y,Anatomy.SHOULDER.z)
  pose.legs[side].end=(launch.legs[side].end as Vector3).lerp(pose.legs[side].end,amount)
  pose.legs[side].pitch=lerpf(launch.legs[side].pitch,pose.legs[side].pitch,amount)
  pose.hands[side]=(launch.hands[side] as Vector3).lerp(pose.hands[side],amount)
  pose.leg_poles[side]=(launch.leg_poles[side] as Vector3).lerp(pose.leg_poles[side],amount).normalized()
 pose.body=body;pose.pelvis=pelvis
 pose.grip=(launch.grip as Vector3).lerp(pose.grip,amount)
 pose.tool_basis=launch_frame.slerp(target_frame,amount);pose.shaft=pose.tool_basis.y
