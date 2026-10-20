extends RefCounted
## Additive coordinated posture on sampled approved cycles, before transition mixing.
const Torso=preload("res://scripts/animation/authoring/aren_torso_flow.gd")
static func apply(native:RefCounted,sample:Dictionary,angle:float) -> Dictionary:
 var globals:Array[Transform3D]=[]
 for i in native.parents.size():
  var parent:int=native.parents[i]
  globals.append(globals[parent]*sample.poses[i] if parent>=0 else sample.poses[i])
  native.posed[i]=native.frame*globals[i]
 var original:Array=native.posed.duplicate()
 var hip:int=native.binding.bone(&"root")
 Torso.rotate_branch(native,hip,Basis(Vector3.RIGHT,angle*.35)*native.posed[hip].basis,native.posed[hip].origin)
 # Cumulative pitch: pelvis 35%, lower abdomen 50%, upper abdomen 75%, chest 100%.
 for i in native.spine.size():
  var id:int=native.spine[i]
  Torso.rotate_branch(native,id,Basis(Vector3.RIGHT,angle*[.15,.25,.25][i])*native.posed[id].basis,native.posed[id].origin)
 Torso.rotate_branch(native,native.neck,Basis(Vector3.RIGHT,-angle*.5)*native.posed[native.neck].basis,native.posed[native.neck].origin)
 # Counter-transform the complete leg branches into the new pelvis frame.
 # Their world trajectories and knee corrective curves stay exactly approved;
 # the pelvis rotates about the same centre and keeps the socket radii/lengths.
 for i in native.parents.size():
  var parent:int=i
  while parent>=0:
   if parent==native.legs[0].ids[0] or parent==native.legs[1].ids[0]:native.posed[i]=original[i];break
   parent=native.parents[parent]
 for i in native.parents.size():globals[i]=native.inverse_frame*native.posed[i]
 var locals:Array[Transform3D]=[]
 for i in native.parents.size():
  var parent:int=native.parents[i]
  locals.append(globals[parent].affine_inverse()*globals[i] if parent>=0 else globals[i])
 sample.poses=locals
 return sample
