extends "res://tools/enemy/young_volume.gd"
## Bind geometry follows the supplied young mole. Runtime animation is skeletal.
const Motion = preload("res://scripts/prototype_3d/young_pose.gd")
const Normals = preload("res://scripts/prototype_3d/humanoid_rig.gd")
var skeleton:=Skeleton3D.new()
var rest: Array[Transform3D]=[]
var posed: Array[Transform3D]=[]
var parents: Array[int]=[]
var region:=0
func _ready() -> void:
 mesh_node=MeshInstance3D.new();add_child(mesh_node)
 body_material=ShaderMaterial.new();body_material.shader=preload("res://shaders/prototype_3d/young_skin.gdshader")
 body_material.set_shader_parameter("materials",load("res://assets/enemies/prototype_3d/pixel_materials.png"))
 var outline:=ShaderMaterial.new();outline.shader=preload("res://shaders/prototype_3d/outline.gdshader");body_material.next_pass=outline
 mesh_node.material_override=body_material
 pose("attack",0,4,true)
 make_skeleton()
func triangle(a:Vector3,b:Vector3,c:Vector3,color:Color) -> void:
 for point in [a,b,c]:
  var patch:=Vector2.ZERO
  if color.g>0.5 and color.b<0.4:patch=Vector2(0,0.5)
  elif color.r>0.65 and color.g>0.46 and color.b<0.5:patch=Vector2(0.5,0.5)
  elif surface_tag==1:patch=Vector2(0.5,0)
  var uv:=patch+Vector2(0.004,0.004)+Vector2(fposmod(point.x*0.06+point.z*0.04,1),fposmod(point.y*0.06,1))*0.492
  if color.r<0.32 or color.r>0.8 or (color.r>0.65 and color.g<0.3):uv=Vector2(-1,-1)
  surface.set_uv(Vector2(region,0));surface.set_uv2(uv);surface.set_color(color);surface.add_vertex(point)
func head_volume(center:Vector3,size:Vector3,color:Color,tag:float,body:Transform3D) -> void:
 var previous:=region;region=1;super.head_volume(center,size,color,tag,body);region=previous
func limb(root_point:Vector3,target:Vector3,a:float,b:float,pole:Vector3,radius:float,body:Transform3D) -> Dictionary:
 var previous:=region;region=(2 if a<5 else 4)+(0 if root_point.x<0 else 1)
 var result:=super.limb(root_point,target,a,b,pole,radius,body);region=previous;return result
func volume(center:Vector3,size:Vector3,color:Color,tag:float,body:Transform3D) -> void:
 var previous:=region
 if region==0 and body.origin.y<4 and absf(body.origin.x)>3:region=6+(0 if body.origin.x<0 else 1)
 super.volume(center,size,color,tag,body);region=previous
func ellipsoid(center:Vector3,size:Vector3,color:Color,basis:Basis = Basis.IDENTITY) -> void:
 var previous:=region
 if surface_tag==1:region=8+(0 if center.x<0 else 1)
 super.ellipsoid(center,size,color,basis);region=previous
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
 var arrays:Array=mesh_node.mesh.surface_get_arrays(0)
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var tags:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
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
 arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=weights;arrays[Mesh.ARRAY_NORMAL]=Normals.smooth_normals(vertices)
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh_node.mesh=mesh
 mesh_node.custom_aabb=AABB(Vector3(-25,-10,-25),Vector3(50,60,60))
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
