extends RefCounted
## Convert complete global poses to locals, inverting each shared parent once.
var parents:Array[int]=[]
var ancestors:Array[int]=[]
var inverses:Array[Transform3D]=[]
func configure(hierarchy:Array[int]) -> void:
 parents.assign(hierarchy);ancestors.clear();inverses.resize(parents.size())
 for parent in parents:
  if parent>=0 and not ancestors.has(parent):ancestors.append(parent)
func apply(skeleton:Skeleton3D,posed:Array[Transform3D]) -> void:
 for parent in ancestors:inverses[parent]=posed[parent].affine_inverse()
 for i in posed.size():skeleton.set_bone_pose(i,inverses[parents[i]]*posed[i] if parents[i]>=0 else posed[i])
