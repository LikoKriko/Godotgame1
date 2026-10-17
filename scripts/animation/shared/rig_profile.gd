extends Resource
## Semantic names describe anatomy without renaming the supplied skeleton.
@export var category:StringName=&"enemy"
@export var locomotion_family:StringName
@export var reference_height:=1.0
@export var rig_id:StringName
@export var bones:Dictionary={}
@export var chains:Dictionary={}
func resolve(skeleton:Skeleton3D) -> Dictionary:
 var errors:Array[String]=[];var indices:Dictionary={};var resolved:Dictionary={};var used:Dictionary={}
 if locomotion_family.is_empty():errors.append("Missing locomotion family")
 if category not in [&"character",&"enemy"]:errors.append("Unknown animation category")
 if not is_finite(reference_height) or reference_height<=0:errors.append("Reference height must be positive")
 if rig_id.is_empty():errors.append("Missing rig_id")
 if skeleton==null or bones.is_empty():return {"ok":false,"errors":["A skeleton and semantic bone map are required"],"bones":{},"chains":{}}
 for role in bones:
  if not (role is String or role is StringName) or not (bones[role] is String or bones[role] is StringName):errors.append("Bone roles and labels must be strings");continue
  var index:=skeleton.find_bone(bones[role])
  if index<0:errors.append("Missing bone: "+str(bones[role]));continue
  if used.has(index):errors.append("Duplicate bone assignment: "+str(role));continue
  used[index]=true;indices[role]=index
 for label in chains:
  if not (chains[label] is Array or chains[label] is PackedStringArray) or chains[label].size()<3 or chains[label].size()>4:errors.append("Chain needs three or four roles: "+str(label));continue
  var ids:Array[int]=[]
  for role in chains[label]:
   if not indices.has(role):errors.append("Unknown chain role: "+str(role));continue
   ids.append(indices[role])
  if ids.size()!=chains[label].size():continue
  for i in range(1,ids.size()):
   var ancestor:=skeleton.get_bone_parent(ids[i])
   while ancestor>=0 and ancestor!=ids[i-1]:ancestor=skeleton.get_bone_parent(ancestor)
   if ancestor!=ids[i-1]:errors.append("Broken anatomical chain: "+str(label))
  resolved[label]=ids
 return {"ok":errors.is_empty(),"errors":errors,"bones":indices,"chains":resolved}
