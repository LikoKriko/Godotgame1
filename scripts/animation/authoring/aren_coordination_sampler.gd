extends "res://scripts/animation/authoring/aren_posture_sampler.gd"
## Rephase the complete local arm chains, retaining approved amplitude/gestures.
var arm_phase:=.5
var arm_bones:PackedInt32Array=[]
var knee_poles:Dictionary={}
func configure(library:AnimationLibrary,rig:Skeleton3D) -> void:
 super.configure(library,rig);arm_bones.clear()
 var roots:Array[int]=[rig.find_bone("smartrig_RightShoulder"),rig.find_bone("smartrig_LeftShoulder")]
 for bone in rig.get_bone_count():
  var parent:int=bone
  while parent>=0:
   if parent in roots:arm_bones.append(bone);break
   parent=rig.get_bone_parent(parent)
func sample(name:String,time:float) -> Dictionary:
 var result:=super.sample(name,time)
 if name=="walk":
  var opposite:=super.sample(name,time+clips[name].length*arm_phase)
  for bone in arm_bones:result.poses[bone]=opposite.poses[bone]
 var poles:Array[Vector3]=[]
 for chain in foot_chains:
  var global_pose:=Transform3D.IDENTITY;var points:Array[Vector3]=[]
  for bone in chain:
   global_pose=global_pose*result.poses[bone]
   if bone in [chain[-3],chain[-2],chain[-1]]:points.append(global_pose.origin)
  var axis:Vector3=(points[2]-points[0]).normalized()
  var radial:Vector3=points[1]-points[0];radial-=axis*radial.dot(axis)
  poles.append((native.frame.basis*radial).normalized())
 knee_poles[name]=poles
 return result
