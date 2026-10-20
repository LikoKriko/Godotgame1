extends RefCounted
## Continuous whole-chain coordination in native authoring space, before foot IK.
static func capture(native:RefCounted) -> Dictionary:
 var angles:Array[Vector3]=[]
 var ids:Array=[native.binding.bone(&"root")]
 ids.append_array(native.spine);ids.append_array([native.neck,native.head])
 for id in ids:angles.append((native.posed[id].basis*native.inverse_rest[id].basis).orthonormalized().get_euler())
 return {"origin":native.posed[ids[0]].origin,"angles":angles}
static func summarize(frames:Array) -> Dictionary:
 var centre:=Vector3.ZERO;var means:Array[Vector3]=[]
 means.resize(frames[0].angles.size());means.fill(Vector3.ZERO)
 # Exclude the duplicate loop endpoint from the periodic mean.
 for frame in frames.size()-1:
  centre+=frames[frame].origin
  for i in means.size():means[i]+=frames[frame].angles[i]
 centre/=frames.size()-1
 for i in means.size():means[i]/=frames.size()-1
 return {"centre":centre,"angles":means}
static func rotate_branch(native:RefCounted,bone:int,basis:Basis,origin:Vector3) -> void:
 var change:Transform3D=Transform3D(basis,origin)*native.posed[bone].affine_inverse()
 for i in native.posed.size():
  var parent:int=i
  while parent>=0 and parent!=bone:parent=native.parents[parent]
  if parent==bone:native.posed[i]=change*native.posed[i]
static func apply(native:RefCounted,phase:float,parameters:Dictionary,reference:Dictionary) -> void:
 var weight:float=parameters.torso_flow
 if weight<=0:return
 var before:=capture(native)
 var hip:int=native.binding.bone(&"root")
 var retained:float=lerpf(1.0,parameters.pelvis_sway,weight)
 var hip_dynamic:Vector3=(before.angles[0]-reference.angles[0])*retained
 var hip_angles:Vector3=reference.angles[0]+hip_dynamic
 var origin:Vector3=reference.centre+(before.origin-reference.centre)*retained
 rotate_branch(native,hip,Basis.from_euler(hip_angles)*native.rest[hip].basis,origin)
 # Reuse authored yaw/step phase. Spread restrained support-linked sagittal
 # and frontal movement cumulatively through all three spine segments.
 var chest_dynamic:Vector3=before.angles[3]-reference.angles[3]
 var pitch:=deg_to_rad(.25)*cos(phase*TAU*2)
 var roll:=deg_to_rad(.45)*sin(phase*TAU)
 chest_dynamic+=Vector3(pitch,0,roll)
 var shares:Array[float]=[.30,.65,1.0]
 for i in native.spine.size():
  var bone:int=native.spine[i]
  var desired:Vector3=reference.angles[i+1]+hip_dynamic.lerp(chest_dynamic,shares[i])
  var angles:Vector3=before.angles[i+1].lerp(desired,weight)
  rotate_branch(native,bone,Basis.from_euler(angles)*native.rest[bone].basis,native.posed[bone].origin)
 # Gaze compensation is partial, keeping the neck linked to the chest.
 for i in 2:
  var bone:int=native.neck if i==0 else native.head
  var angles:Vector3=before.angles[4+i]+Vector3(pitch,0,roll)*weight*(.35 if i==0 else .15)
  rotate_branch(native,bone,Basis.from_euler(angles)*native.rest[bone].basis,native.posed[bone].origin)
