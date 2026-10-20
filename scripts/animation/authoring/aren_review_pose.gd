extends RefCounted
## Four cameras observe one solved pose; followers never run a second IK clock.
var rigs:Array[Skeleton3D]=[]
var meshes:Array[MeshInstance3D]=[]
var poses:Array[Transform3D]=[]
var shapes:PackedFloat32Array=[]
func configure(actors:Array[Node3D]) -> void:
 rigs.clear();meshes.clear();poses.clear();shapes.clear()
 if actors.is_empty() or not actors[0].has_method("advance_transition"):return
 for actor in actors:
  rigs.append(actor.native.skeleton);meshes.append(actor.native.mesh)
 poses.resize(rigs[0].get_bone_count());shapes.resize(meshes[0].mesh.get_blend_shape_count())
func copy_pose() -> void:
 if rigs.is_empty():return
 for bone in poses.size():poses[bone]=rigs[0].get_bone_pose(bone)
 for shape in shapes.size():shapes[shape]=meshes[0].get_blend_shape_value(shape)
 for view in range(1,rigs.size()):
  for bone in poses.size():rigs[view].set_bone_pose(bone,poses[bone])
  for shape in shapes.size():meshes[view].set_blend_shape_value(shape,shapes[shape])
