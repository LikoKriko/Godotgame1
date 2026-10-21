extends RefCounted
## Capture once in the supplied reference pose. No per-frame name/length lookup.
const Profile=preload("res://scripts/animation/shared/rig_profile.gd")
const Body=preload("res://scripts/continuous_body_pose.gd")
var roles:Dictionary={}
var names:Dictionary={}
var chains:Dictionary={}
var globals:Array[Transform3D]=[]
var locals:Array[Transform3D]=[]
var parents:Array[int]=[]
var branches:Array[PackedInt32Array]=[] # Inclusive subtrees, in original bone order.
var errors:Array=[]
func configure(skeleton:Skeleton3D,profile:Resource) -> bool:
 roles.clear();names.clear();chains.clear();globals.clear();locals.clear();parents.clear();branches.clear();errors.clear()
 if not profile is Profile:errors.append("Expected an animation rig profile");return false
 var result:Dictionary=profile.resolve(skeleton);errors=result.errors
 if not result.ok:return false
 for i in skeleton.get_bone_count():
  names[skeleton.get_bone_name(i)]=i;parents.append(skeleton.get_bone_parent(i));globals.append(skeleton.get_bone_global_pose(i));locals.append(skeleton.get_bone_pose(i))
 for bone in parents.size():branches.append(PackedInt32Array())
 for bone in parents.size():
  var ancestor:int=bone
  while ancestor>=0:
   branches[ancestor].append(bone)
   ancestor=parents[ancestor]
 roles=result.bones
 for label in result.chains:
  var ids:Array[int]=result.chains[label]
  var a:=globals[ids[0]].origin.distance_to(globals[ids[1]].origin);var b:=globals[ids[1]].origin.distance_to(globals[ids[2]].origin)
  if a<=.000001 or b<=.000001:errors.append("Zero-length limb: "+String(label));continue
  chains[label]={"ids":ids,"a":a,"b":b,"offset":globals[ids[3]].origin-globals[ids[2]].origin if ids.size()==4 else Vector3.ZERO}
 if not errors.is_empty():roles.clear();chains.clear();globals.clear();locals.clear();parents.clear();branches.clear();return false
 return true
func bone(role:StringName) -> int:return int(roles.get(role,-1))
static func solve_metres(root:Vector3,target:Vector3,upper:float,lower:float,pole:Vector3) -> Dictionary:
 if not root.is_finite() or not target.is_finite() or not pole.is_finite() or not is_finite(upper) or not is_finite(lower) or minf(upper,lower)<=.0004:return {}
 var axis:=root.direction_to(target)
 if (pole-axis*pole.dot(axis)).length_squared()<.000001 and absf(axis.dot(Vector3.RIGHT))>.99:pole=Vector3.UP
 # Preserve the existing solver's sub-millimetre tolerances for source-metre rigs.
 var result:=Body.joint(root*100,target*100,upper*100,lower*100,pole)
 result.root/=100;result.joint/=100;result.end/=100
 return result
