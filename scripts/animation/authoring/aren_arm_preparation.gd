extends RefCounted
## Semantic arm preparation over the freshly evaluated locomotion pose.
const Torso=preload("res://scripts/animation/authoring/aren_torso_flow.gd")
static func apply(native:RefCounted,side:int,amount:float,forward_deg:float,fold_deg:float) -> void:
 if amount<.000001:return
 var ids:Array=native.arms[side].ids
 var chest:Basis=(native.posed[native.spine[2]].basis*native.inverse_rest[native.spine[2]].basis).orthonormalized()
 var axis:Vector3=(chest*Vector3.RIGHT).normalized()
 var shoulder:Basis=Basis(axis,-deg_to_rad(forward_deg)*amount)*native.posed[ids[1]].basis
 Torso.rotate_branch(native,ids[1],shoulder,native.posed[ids[1]].origin)
 var upper:Vector3=(native.posed[ids[2]].origin-native.posed[ids[1]].origin).normalized()
 var lower:Vector3=(native.posed[ids[3]].origin-native.posed[ids[2]].origin).normalized()
 var hinge:=upper.cross(lower)
 hinge=hinge.normalized() if hinge.length_squared()>.000001 else -axis
 var angle:=acos(clampf(upper.dot(lower),-1,1))
 var extra:float=minf(deg_to_rad(fold_deg)*amount,maxf(0,deg_to_rad(115)-angle))
 var elbow:Basis=Basis(hinge,extra)*native.posed[ids[2]].basis
 Torso.rotate_branch(native,ids[2],elbow,native.posed[ids[2]].origin)
