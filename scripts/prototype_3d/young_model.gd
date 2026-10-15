extends Node3D
## Bind geometry follows the supplied young mole. Runtime animation is skeletal.
const Motion = preload("res://scripts/prototype_3d/young_pose.gd")
const REFERENCE=preload("res://assets/enemies/first/reference_3d.png")
const ReferenceMesh=preload("res://scripts/prototype_3d/young_reference_mesh.gd")
static var shared_geometry:ArrayMesh
static var shared_skin:ArrayMesh
static var geometry_counts:Dictionary={}
const Normals = preload("res://scripts/prototype_3d/humanoid_rig.gd")
var skeleton:=Skeleton3D.new()
var rest: Array[Transform3D]=[]
var posed: Array[Transform3D]=[]
var parents: Array[int]=[]
var mesh_node:MeshInstance3D
var body_material:ShaderMaterial
var last_pose:Dictionary={}
func _ready() -> void:
 mesh_node=MeshInstance3D.new();add_child(mesh_node)
 body_material=ShaderMaterial.new();body_material.shader=preload("res://shaders/prototype_3d/young_skin.gdshader")
 body_material.set_shader_parameter("reference_views",load("res://assets/enemies/first/reference_3d.png"))
 var outline:=ShaderMaterial.new();outline.shader=preload("res://shaders/prototype_3d/young_outline.gdshader");outline.set_shader_parameter("thickness",0.035);body_material.next_pass=outline
 mesh_node.material_override=body_material
 pose("attack",0,4,true)
 make_skeleton()
func pose(_state:String,_phase:float,_direction:int,_left:bool=true) -> void:
 # Sculpt once in the reference stance; runtime only deforms this bind mesh.
 if shared_geometry==null:
  var builder:=ReferenceMesh.new()
  shared_geometry=builder.build();geometry_counts=builder.counts.duplicate()
 mesh_node.mesh=shared_geometry;mesh_node.position.y=0
func bone(label:String,parent:int,point:Vector3) -> void:
 var index:=skeleton.get_bone_count();skeleton.add_bone(label);parents.append(parent)
 var transform:=Transform3D(Basis.IDENTITY,point);rest.append(transform);posed.append(transform)
 if parent>=0:skeleton.set_bone_parent(index,parent)
 var local:=rest[parent].affine_inverse()*transform if parent>=0 else transform
 skeleton.set_bone_rest(index,local);skeleton.set_bone_pose(index,local)
func make_skeleton() -> void:
 var neutral:=Motion.sample(&"attack",0)
 bone("body",-1,Vector3.ZERO);bone("head",0,Vector3(0,21,2.5))
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
 if shared_skin!=null:
  mesh_node.mesh=shared_skin
  mesh_node.custom_aabb=AABB(Vector3(-30,-15,-35),Vector3(60,70,75))
  return
 var arrays:Array=mesh_node.mesh.surface_get_arrays(0)
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var tags:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
 var front_back:=PackedFloat32Array();var sides:=PackedFloat32Array();var view_weights:=PackedFloat32Array()
 var normals:PackedVector3Array=Normals.smooth_normals(vertices)
 for i in vertices.size():
  var p:=vertices[i];var n:=normals[i]
  var image_y:float=(553.0-(p.y+0.1)*12.08)/724.0
  var side_x:float=cos(deg_to_rad(68))*p.x
  var side_z:float=sin(deg_to_rad(68))*p.z
  front_back.append_array(PackedFloat32Array([(264+p.x*12.08)/2172.0,image_y,(1345-p.x*12.08)/2172.0,image_y]))
  sides.append_array(PackedFloat32Array([(800+(side_x+side_z)*12.08)/2172.0,image_y,(1955+(side_x-side_z)*12.08)/2172.0,image_y]))
  var weights_by_view:=Vector4(pow(maxf(n.z,0),3),pow(maxf(-n.z,0),3),pow(maxf(-n.x,0),3),pow(maxf(n.x,0),3))
  weights_by_view/=maxf(0.0001,weights_by_view.x+weights_by_view.y+weights_by_view.z+weights_by_view.w)
  view_weights.append_array(PackedFloat32Array([weights_by_view.x,weights_by_view.y,weights_by_view.z,weights_by_view.w]))
 arrays[Mesh.ARRAY_CUSTOM0]=front_back;arrays[Mesh.ARRAY_CUSTOM1]=sides;arrays[Mesh.ARRAY_CUSTOM2]=view_weights
 var bones:=PackedInt32Array();var weights:=PackedFloat32Array()
 for i in vertices.size():
  var part:=int(tags[i].x);var a:=0;var b:=0;var weight:=0.0
  if part==1:a=1;b=1
  elif part in [6,7]:a=4+(part-6)*3;b=a
  elif part in [8,9]:a=10+(part-8)*3;b=a
  elif part in [2,3,4,5]:
   var side:=part%2;var joints:Dictionary=neutral.legs[side] if part<4 else neutral.arms[side]
   var start:=2+side*3 if part<4 else 8+side*3
   var first:=Geometry3D.get_closest_point_to_segment(vertices[i],joints.root,joints.joint)
   var second:=Geometry3D.get_closest_point_to_segment(vertices[i],joints.joint,joints.end)
   a=start;b=start+1
   weight=smoothstep(0.7,1.0,joints.root.distance_to(first)/joints.root.distance_to(joints.joint))*0.5 if vertices[i].distance_squared_to(first)<vertices[i].distance_squared_to(second) else 0.5+smoothstep(0,0.3,joints.joint.distance_to(second)/joints.joint.distance_to(joints.end))*0.5
  for id in [a,b,0,0]:bones.append(id)
  for value in [1-weight,weight,0.0,0.0]:weights.append(value)
 arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=weights;arrays[Mesh.ARRAY_NORMAL]=normals
 for face in range(0,vertices.size(),3):
  var normal:Vector3=(vertices[face+2]-vertices[face]).cross(vertices[face+1]-vertices[face]).normalized()
  for corner in 3:
   var index:=face+corner;var amount:=0.52 if int(tags[index].x) in [8,9] else 0.12
   arrays[Mesh.ARRAY_NORMAL][index]=(arrays[Mesh.ARRAY_NORMAL][index] as Vector3).lerp(normal,amount).normalized()
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},(Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)|(Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)|(Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT));mesh_node.mesh=mesh;shared_skin=mesh;shared_geometry=mesh
 mesh_node.custom_aabb=AABB(Vector3(-30,-15,-35),Vector3(60,70,75))
func orient(index:int,root:Vector3,end:Vector3,rest_end:Vector3) -> void:
 posed[index]=Transform3D(Basis(Quaternion(rest[index].origin.direction_to(rest_end),root.direction_to(end))),root)
func animate(state:StringName,phase:float,left:bool = true,delta:float = 0.0) -> void:
 var target:=Motion.sample(state,phase,left)
 last_pose=Motion.blend(last_pose,target,delta) if delta>0 and not last_pose.is_empty() and state!=&"attack" else target
 var body:Transform3D=last_pose.body;posed[0]=body
 posed[1]=Transform3D(last_pose.head,body*Vector3(0,21,2.5))
 for side in 2:
  for kind in 2:
   var start:=2+side*3 if kind==0 else 8+side*3
   var limb:Dictionary=last_pose.legs[side] if kind==0 else last_pose.arms[side]
   orient(start,limb.root,limb.joint,rest[start+1].origin);orient(start+1,limb.joint,limb.end,rest[start+2].origin)
   posed[start+2]=Transform3D(Basis.IDENTITY.slerp(body.basis,last_pose.standing),limb.end)
 for i in posed.size():skeleton.set_bone_pose(i,posed[parents[i]].affine_inverse()*posed[i] if parents[i]>=0 else posed[i])
