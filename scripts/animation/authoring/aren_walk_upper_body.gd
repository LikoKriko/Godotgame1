extends RefCounted
## Periodic whole-torso authoring layer; feet and approved arm gestures stay intact.
const Torso=preload("res://scripts/animation/authoring/aren_torso_flow.gd")
static func restore_sample(native:RefCounted,sample:Dictionary) -> void:
 var globals:Array[Transform3D]=[]
 for bone in native.parents.size():
  var parent:int=native.parents[bone]
  globals.append(globals[parent]*sample.poses[bone] if parent>=0 else sample.poses[bone])
  native.posed[bone]=native.frame*globals[bone]
static func apply(native:RefCounted,sample:Dictionary,phase:float,p:Dictionary,reference:Dictionary) -> Dictionary:
 restore_sample(native,sample)
 var before:=Torso.capture(native)
 var original:Array=native.posed.duplicate()
 var hip:int=native.binding.bone(&"root")
 var hip_dynamic:Vector3=(before.angles[0]-reference.angles[0])*p.pelvis_retention
 var chest_dynamic:=Vector3(deg_to_rad(p.pitch_deg)*cos(phase*TAU*2),deg_to_rad(p.yaw_deg)*sin(phase*TAU),deg_to_rad(p.roll_deg)*sin(phase*TAU))
 var ids:Array=[hip]+Array(native.spine)+[native.neck,native.head]
 var dynamics:Array[Vector3]=[hip_dynamic]
 for share in p.spine_shares:dynamics.append(hip_dynamic.lerp(chest_dynamic,share))
 dynamics.append(chest_dynamic*p.neck_follow);dynamics.append(chest_dynamic*p.head_follow)
 for i in ids.size():
  var bone:int=ids[i]
  var desired:Vector3=reference.angles[i]+dynamics[i]
  var basis:Basis=Basis.from_euler(desired)*Basis.from_euler(before.angles[i]).inverse()*original[bone].basis
  Torso.rotate_branch(native,bone,basis,native.posed[bone].origin)
 # Counter-transform complete leg branches, as in the existing run-posture layer.
 for bone in native.parents.size():
  var parent:int=bone
  while parent>=0:
   if parent in [native.legs[0].ids[0],native.legs[1].ids[0]]:native.posed[bone]=original[bone];break
   parent=native.parents[parent]
 var globals:Array[Transform3D]=[];var locals:Array[Transform3D]=[]
 for bone in native.parents.size():globals.append(native.inverse_frame*native.posed[bone])
 for bone in native.parents.size():
  var parent:int=native.parents[bone]
  locals.append(globals[parent].affine_inverse()*globals[bone] if parent>=0 else globals[bone])
 sample.poses=locals
 return sample
