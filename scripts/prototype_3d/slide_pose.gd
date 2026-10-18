extends RefCounted
## Feet-first hip slide adapted to the imported Meshy anatomy. Pose only:
## speed, 0.46s duration and air steering remain in locomotion.gd.
const Controls=preload("res://scripts/animation/characters/survivor_controls.gd")
const Aim=preload("res://scripts/prototype_3d/tool_aim.gd")
const Kinematics=preload("res://scripts/prototype_3d/human_kinematics.gd")
const Anatomy=preload("res://scripts/prototype_3d/survivor_anatomy.gd")
const Profiles=preload("res://scripts/prototype_3d/held_profiles.gd")
static func apply(pose:Dictionary,phase:float,clip:StringName=&"slide") -> void:
 var t:=clampf(phase,0,1)
 var keyed:=Controls.sample(clip,t)
 var backward:=String(clip).begins_with("slide_back")
 var lateral:float=-1 if String(clip).ends_with("left") else (1 if String(clip).ends_with("right") else 0)
 var enter:float=keyed.timing.x
 var rise:float=keyed.timing.y
 var load:float=keyed.timing.z
 var original:Transform3D=pose.body
 var pivot:=Vector3(0,Anatomy.HIP.y,0)
 # The outside of the folded leg and hip carry the body. Pelvis leans back;
 # the chest curls forward relative to it rather than staying a rigid plank.
 var hip_basis:=Basis.from_euler(keyed.pelvis)
 var glide:=Transform3D(hip_basis,keyed.hip-hip_basis*pivot)
 var recovery_basis:=Basis(Vector3.RIGHT,.14)
 var recovery:=Transform3D(recovery_basis,Vector3(0,21.5,0)-recovery_basis*pivot)
 var pelvis:Transform3D=original.interpolate_with(glide,enter).interpolate_with(recovery,rise)
 var lumbar:=pelvis*Vector3(0,Anatomy.HIP.y+5.5,0)
 var curl:=Basis(pelvis.basis.x,keyed.curl.x*load)
 var body:=Transform3D(curl,lumbar-curl*lumbar)*pelvis
 var feet:Array[Vector3]=[keyed.foot_l,keyed.foot_r]
 var turn:=Basis(Vector3.UP,keyed.curl.y)
 var recover_feet:Array[Vector3]=[Vector3(-Anatomy.HIP.x,2.1,0),Vector3(Anatomy.HIP.x,2.1,0)]
 var family:StringName=pose.get("family",&"")
 var profile:Dictionary=Profiles.profile(family)
 for side in 2:
  var sign_side:float=-1 if side==0 else 1
  var start_axis:Vector3=(original*Vector3(sign_side*Anatomy.HIP.x,Anatomy.HIP.y,0)).direction_to(pose.legs[side].end)
  pose.hips[side]=pelvis*Vector3(sign_side*Anatomy.HIP.x,Anatomy.HIP.y,0)
  pose.shoulders[side]=body*Vector3(sign_side*Anatomy.SHOULDER.x,Anatomy.SHOULDER.y,Anatomy.SHOULDER.z)
  pose.legs[side].end=(pose.legs[side].end as Vector3).lerp(feet[side],enter).lerp(recover_feet[side],rise)
  var loaded_side:=1-side if lateral<0 else side
  var ankle_pitch:float=(-.20 if loaded_side==0 else -.10) if backward else (-.08 if side==0 else -.16)
  pose.legs[side].pitch=lerpf(pose.legs[side].pitch,ankle_pitch,load)*(1-rise)
  # A stable knee plane opens the folded leg naturally, leaving space between
  # knee and hip. The old target folded the calf almost onto the thigh.
  var pole:=Vector3(-1,.22,.18) if loaded_side==0 else Vector3(.06,1,.18)
  if backward:
   pole=Vector3(-.12,1,.25) if loaded_side==0 else Vector3(1,.24,.25)
   if lateral<0:pole.x=-pole.x
   pole=turn*pole
  if not backward:
   if lateral<0:pole.x=-pole.x
   pole=turn*pole
  var axis:Vector3=pose.hips[side].direction_to(pose.legs[side].end)
  pose.leg_poles[side]=Kinematics.transport_pole(start_axis,Vector3.BACK,axis,pole.normalized(),load)
  var free:bool=family==&"" or (family!=&"bow" and not profile.two_hands and side!=pose.active)
  var hand:Vector3=body*((keyed.hand_l if side==0 else keyed.hand_r) if free else Vector3(sign_side*8,39,12.5))
  if backward:
   hand+=body.basis*Vector3(-lateral*1.2,maxf(0,-lateral*sign_side)*.8,0)
  pose.hands[side]=(pose.hands[side] as Vector3).lerp(hand,enter)
 pose.grip=(pose.grip as Vector3).lerp(body*Vector3(-3.36,40,11),enter)
 pose.shaft=(pose.shaft as Vector3).lerp(body.basis*Vector3(.25,.88,.40).normalized(),enter).normalized()
 pose.body=body;pose.pelvis=pelvis
 pose.leg_frame=Basis(Vector3.UP,keyed.curl.y*load)
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
