extends Node3D
## User-supplied Leafwoven Tunic, fitted and bound to the wearer's own pose.
const IMPORTED=preload("res://assets/models/meshy/leaf_armor/worn.res")
var shell:MeshInstance3D
var skeleton:=Skeleton3D.new()
var parents:Array[int]=[]
static var shared_mesh:ArrayMesh=IMPORTED
static var shared_material:StandardMaterial3D=IMPORTED.surface_get_material(0)
func _ready() -> void:
 add_child(skeleton)
 shell=MeshInstance3D.new();shell.mesh=shared_mesh;skeleton.add_child(shell);shell.skeleton=NodePath("..")
 shell.custom_aabb=AABB(Vector3(-20,-10,-30),Vector3(40,80,60))
func bind(rig:RefCounted) -> void:
 var skin:=Skin.new()
 for i in rig.rest.size():
  skeleton.add_bone(rig.skeleton.get_bone_name(i));parents.append(rig.parents[i])
  if parents[i]>=0:skeleton.set_bone_parent(i,parents[i])
  var local:Transform3D=rig.rest[parents[i]].affine_inverse()*rig.rest[i] if parents[i]>=0 else rig.rest[i]
  skeleton.set_bone_rest(i,local);skeleton.set_bone_pose(i,local);skin.add_bind(i,rig.rest[i].affine_inverse())
 shell.skin=skin
func update_pose(rig:RefCounted,body:Transform3D) -> void:
 var inverse:=body.affine_inverse()
 for i in parents.size():
  var current:Transform3D=inverse*rig.posed[i]
  var parent:int=parents[i]
  skeleton.set_bone_pose(i,(inverse*rig.posed[parent]).affine_inverse()*current if parent>=0 else current)
