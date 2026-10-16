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
var bind_pose:Dictionary={}
var previous_state:StringName=&"reference"
var interruption_pose:Dictionary={}
const Frames=preload("res://scripts/prototype_3d/human_kinematics.gd")

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
 var neutral:=Motion.bind_pose()
 bind_pose=neutral
 bone("body",-1,Vector3.ZERO);bone("head",0,Motion.HEAD_ANCHOR)
 for side in 2:
  var start:=rest.size();var leg:Dictionary=neutral.legs[side]
  bone("thigh_%d"%side,0,leg.root);bone("shin_%d"%side,start,leg.joint);bone("foot_%d"%side,start+1,leg.end)
 for side in 2:
  var start:=rest.size();var arm:Dictionary=neutral.arms[side]
  bone("upper_arm_%d"%side,0,arm.root);bone("forearm_%d"%side,start,arm.joint);bone("fist_%d"%side,start+1,arm.end)
 bone("tail",0,preload("res://scripts/prototype_3d/young_skin_weights.gd").TAIL_ANCHOR)
 add_child(skeleton);mesh_node.reparent(skeleton);mesh_node.skeleton=NodePath("..")
 var skin:=Skin.new()
 for i in rest.size():skin.add_bind(i,rest[i].affine_inverse())
 mesh_node.skin=skin
func animate(state:StringName,phase:float,left:bool = true,delta:float = 0.0) -> void:
 var target:=Motion.sample(state,phase,left)
 if state!=previous_state:
  interruption_pose=last_pose.duplicate(true) if delta>0 and state in [&"attack",&"hook",&"boxing_rise",&"boxing_lower",&"death",&"stun_fall"] else {}
  previous_state=state
 if not interruption_pose.is_empty() and state in [&"attack",&"hook",&"boxing_rise",&"boxing_lower",&"death",&"stun_fall"]:
  var end:=.16 if state in [&"attack",&"hook",&"boxing_rise",&"boxing_lower"] else (.35 if state==&"death" else .55)
  var settle:=smoothstep(0,end,phase)
  target=Motion.mix(interruption_pose,target,settle)
  if settle>=1:interruption_pose.clear()
 last_pose=Motion.blend(last_pose,target,delta) if delta>0 and not last_pose.is_empty() and state not in [&"attack",&"hook",&"death",&"corpse"] else target
 apply_pose(last_pose)
func apply_pose(pose:Dictionary) -> void:
 last_pose=pose
 var body:Transform3D=last_pose.body;posed[0]=body
 posed[1]=Transform3D(last_pose.head,last_pose.head_origin)
 posed[14]=Transform3D(body.basis*Basis(Vector3.UP,last_pose.get("tail_turn",0.0)),body*rest[14].origin)
 for side in 2:
  for kind in 2:
   var start:=2+side*3 if kind==0 else 8+side*3
   var limb:Dictionary=last_pose.legs[side] if kind==0 else last_pose.arms[side]
   var original:Dictionary=bind_pose.legs[side] if kind==0 else bind_pose.arms[side]
   for segment in 2:
    var rotation:=Frames.segment_frame(limb,segment)*Frames.segment_frame(original,segment).inverse()
    posed[start+segment]=Transform3D(rotation,limb.root if segment==0 else limb.joint)
   var end_basis:Basis=(last_pose.foot_bases[side] if not last_pose.get("foot_bases",[]).is_empty() else Basis(Vector3.RIGHT,limb.get("pitch",0.0))) if kind==0 else posed[start+1].basis
   posed[start+2]=Transform3D(end_basis,limb.end)
 for i in posed.size():skeleton.set_bone_pose(i,posed[parents[i]].affine_inverse()*posed[i] if parents[i]>=0 else posed[i])
