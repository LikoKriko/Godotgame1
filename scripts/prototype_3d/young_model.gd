extends Node3D
## Meshy Mossclaw Boar supplied by the user. The source mesh/UVs/textures are
## preserved; a baked skin adapts the unrigged FBX to the creature's actions.
const Motion=preload("res://scripts/prototype_3d/young_pose.gd")
const IMPORTED_SKIN=preload("res://assets/enemies/first/meshy/mossclaw_skin.res")
var skeleton:=Skeleton3D.new()
var rest:Array[Transform3D]=[]
var posed:Array[Transform3D]=[]
var parents:Array[int]=[]
var mesh_node:MeshInstance3D
var body_material:StandardMaterial3D
var last_pose:Dictionary={}
func _ready() -> void:
 mesh_node=MeshInstance3D.new();add_child(mesh_node)
 mesh_node.mesh=IMPORTED_SKIN
 body_material=IMPORTED_SKIN.surface_get_material(0)
 make_skeleton()
 mesh_node.custom_aabb=AABB(Vector3(-35,-20,-45),Vector3(70,80,100))
func bone(label:String,parent:int,point:Vector3) -> void:
 var index:=skeleton.get_bone_count();skeleton.add_bone(label);parents.append(parent)
 var transform:=Transform3D(Basis.IDENTITY,point);rest.append(transform);posed.append(transform)
 if parent>=0:skeleton.set_bone_parent(index,parent)
 var local:=rest[parent].affine_inverse()*transform if parent>=0 else transform
 skeleton.set_bone_rest(index,local);skeleton.set_bone_pose(index,local)
func make_skeleton() -> void:
 var neutral:=Motion.sample(&"attack",0)
 bone("body",-1,Vector3.ZERO);bone("head",0,Motion.HEAD_ANCHOR)
 for side in 2:
  var start:=rest.size();var leg:Dictionary=neutral.legs[side]
  bone("thigh_%d"%side,0,leg.root);bone("shin_%d"%side,start,leg.joint);bone("foot_%d"%side,start+1,leg.end)
 for side in 2:
  var start:=rest.size();var arm:Dictionary=neutral.arms[side]
  bone("upper_arm_%d"%side,0,arm.root);bone("forearm_%d"%side,start,arm.joint);bone("fist_%d"%side,start+1,arm.end)
 add_child(skeleton);mesh_node.reparent(skeleton);mesh_node.skeleton=NodePath("..")
 var skin:=Skin.new()
 for i in rest.size():skin.add_bind(i,rest[i].affine_inverse())
 mesh_node.skin=skin
func orient(index:int,root:Vector3,end:Vector3,rest_end:Vector3) -> void:
 posed[index]=Transform3D(Basis(Quaternion(rest[index].origin.direction_to(rest_end),root.direction_to(end))),root)
func animate(state:StringName,phase:float,left:bool = true,delta:float = 0.0) -> void:
 var target:=Motion.sample(state,phase,left)
 last_pose=Motion.blend(last_pose,target,delta) if delta>0 and not last_pose.is_empty() and state!=&"attack" else target
 var body:Transform3D=last_pose.body;posed[0]=body
 posed[1]=Transform3D(last_pose.head,body*Motion.HEAD_ANCHOR)
 for side in 2:
  for kind in 2:
   var start:=2+side*3 if kind==0 else 8+side*3
   var limb:Dictionary=last_pose.legs[side] if kind==0 else last_pose.arms[side]
   orient(start,limb.root,limb.joint,rest[start+1].origin);orient(start+1,limb.joint,limb.end,rest[start+2].origin)
   posed[start+2]=Transform3D(Basis.IDENTITY.slerp(body.basis,last_pose.standing),limb.end)
 for i in posed.size():skeleton.set_bone_pose(i,posed[parents[i]].affine_inverse()*posed[i] if parents[i]>=0 else posed[i])
