extends "res://tools/enemy/young_volume.gd"
## Bind geometry follows the supplied young mole. Runtime animation is skeletal.
const Motion = preload("res://scripts/prototype_3d/young_pose.gd")
const REFERENCE=preload("res://assets/enemies/first/reference_3d.png")
const REFERENCE_CROPS=[Rect2i(22,155,474,405),Rect2i(560,155,485,405),Rect2i(1095,155,500,405),Rect2i(1665,155,505,405)]
const Normals = preload("res://scripts/prototype_3d/humanoid_rig.gd")
var skeleton:=Skeleton3D.new()
var rest: Array[Transform3D]=[]
var posed: Array[Transform3D]=[]
var parents: Array[int]=[]
var region:=0
func _ready() -> void:
 mesh_node=MeshInstance3D.new();add_child(mesh_node)
 body_material=ShaderMaterial.new();body_material.shader=preload("res://shaders/prototype_3d/young_skin.gdshader")
 body_material.set_shader_parameter("reference_views",load("res://assets/enemies/first/reference_3d.png"))
 var outline:=ShaderMaterial.new();outline.shader=preload("res://shaders/prototype_3d/outline.gdshader");body_material.next_pass=outline
 mesh_node.material_override=body_material
 pose("attack",0,4,true)
 make_skeleton()
func triangle(a:Vector3,b:Vector3,c:Vector3,color:Color) -> void:
 # Map the four supplied views onto the bind surface, so markings stay on skin.
 var normal:Vector3=(c-a).cross(b-a).normalized()
 var view:=0 if normal.z>=0 else 2
 if absf(normal.x)>absf(normal.z):view=1 if normal.x>0 else 3
 var crop:Rect2i=REFERENCE_CROPS[view]
 for point:Vector3 in [a,b,c]:
  var u:float=0.5+point.x/35.0 if view==0 else (0.5-point.x/35.0 if view==2 else (0.47+point.z/30.0 if view==1 else 0.53-point.z/30.0))
  var v:float=0.96-point.y*0.020 if region==0 else 1-point.y/32.0
  var coordinate:=Vector2(u,v).clamp(Vector2.ZERO,Vector2.ONE)
  var texture_uv:Vector2=(Vector2(crop.position)+coordinate*Vector2(crop.size))/Vector2(REFERENCE.get_size())
  # Reuse clean fur from the back view; projecting a full face onto curved
  # cheeks/arms would duplicate eyes and paint false holes on the body.
  if color.is_equal_approx(FUR) or color.is_equal_approx(FUR.lightened(0.10)):
   var patch:=Vector2(fposmod(point.x*0.08+point.z*0.06,1),fposmod(point.y*0.09,1))
   texture_uv=(Vector2(1230,310)+patch*Vector2(65,100))/Vector2(REFERENCE.get_size())
  var sample_weight:=0.48 if color.is_equal_approx(FUR) or color.is_equal_approx(FUR.lightened(0.10)) else 0.0
  surface.set_uv(Vector2(region,sample_weight));surface.set_uv2(texture_uv);surface.set_color(color);surface.add_vertex(point)
func head_volume(center:Vector3,size:Vector3,color:Color,tag:float,body:Transform3D) -> void:
 var previous:=region;region=1
 # Seat each eye on the curved face instead of the old sprite's raised discs.
 if absf(center.x)>5 and absf(center.x)<6.5 and center.z>=9.6 and center.y>=20 and center.y<22:
  if center.y<20.45:center.z=8.7;size=Vector3(1.5,1.1,0.22)
  elif center.y<20.7:center.z=8.9;size=Vector3(0.65,0.64,0.12)
  elif center.y<21.0:center.z=8.7;size=Vector3(1.7,0.3,0.25)
  else:center.z=9.08;size=Vector3(0.16,0.16,0.08)
 if center.is_equal_approx(Vector3(0,17.3,10.5)):center=Vector3(0,17.5,9.5);size=Vector3(4.2,2.6,3.7)
 elif center.is_equal_approx(Vector3(0,17,14.7)):center=Vector3(0,17.1,12.8);size=Vector3(2.6,1.3,0.9)
 elif center.is_equal_approx(Vector3(0,17.4,15.3)):center=Vector3(0,16.8,13.45);size=Vector3(0.65,0.28,0.15)
 if color==MOSS:
  var anchor:=Vector3(0,21,2.5)
  var frame:Basis=(body.basis*Basis(Vector3.UP,head_yaw)*Basis(Vector3.RIGHT,-head_look_adjust)).scaled(Vector3.ONE*HEAD_SCALE)
  crest_leaf(center,size,Transform3D(frame,body*anchor-frame*anchor));region=previous;return
 if color==IVORY and size.x<0.6 and center.y<16:
  var anchor:=Vector3(0,21,2.5)
  var frame:Basis=(body.basis*Basis(Vector3.UP,head_yaw)*Basis(Vector3.RIGHT,-head_look_adjust)).scaled(Vector3.ONE*HEAD_SCALE)
  fang(center,Transform3D(frame,body*anchor-frame*anchor));region=previous;return
 if center.is_equal_approx(Vector3(0,17.1,12.8)):
  var anchor:=Vector3(0,21,2.5)
  var frame:Basis=(body.basis*Basis(Vector3.UP,head_yaw)*Basis(Vector3.RIGHT,-head_look_adjust)).scaled(Vector3.ONE*HEAD_SCALE)
  nose_wedge(center,Transform3D(frame,body*anchor-frame*anchor))
 elif center.is_equal_approx(Vector3(0,17.5,9.5)) or (color==IVORY and size.x>1):
  var anchor:=Vector3(0,21,2.5)
  var frame:Basis=(body.basis*Basis(Vector3.UP,head_yaw)*Basis(Vector3.RIGHT,-head_look_adjust)).scaled(Vector3.ONE*HEAD_SCALE)
  var local:=Transform3D(frame,body*anchor-frame*anchor)
  if color==IVORY:cheek_mark(center,size,local)
  else:faceted_volume(local*center,size,color,local.basis)
 else:super.head_volume(center,size,color,tag,body)
 region=previous
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
 if region==1 and color.r<0.32 and size.x>1:
  size.z*=0.20;size.y*=0.75
 elif region==1 and color==IVORY and size.x>1:size.z*=0.22
 if (size.x>=3 and size.y>=3) or (surface_tag==1 and size.x>1):
  faceted_volume(center,size,color,basis)
 else:super.ellipsoid(center,size,color,basis)
 region=previous
func crest_leaf(center:Vector3,size:Vector3,frame:Transform3D) -> void:
 # Low pointed overlapping leaves; the ridge is part of the skinned head.
 var c:=center+Vector3(0,0.6,0)
 var points:=[c+Vector3(-size.x*0.8,0,0),c+Vector3(0,0.5,-1.7),c+Vector3(size.x*0.8,0,0),c+Vector3(0,-0.05,2.3),c+Vector3(0,0.9,0)]
 for i in points.size():
  var radial:=1-pow(points[i].x/9.5,2)-pow((points[i].z-2.5)/7.8,2)
  points[i].y=21+8.6*sqrt(maxf(0.05,radial))+0.15+(0.28 if i==4 else 0.0)
 for face:Array in [[0,1,4],[1,2,4],[2,3,4],[3,0,4]]:
  triangle(frame*points[face[0]],frame*points[face[1]],frame*points[face[2]],MOSS)
func fang(center:Vector3,frame:Transform3D) -> void:
 center.y+=0.6
 var tip:=center+Vector3(0,-1.0,0.25)
 for i in 6:
  var a:=i*TAU/6;var b:float=(i+1)*TAU/6
  triangle(frame*(center+Vector3(cos(a)*0.45,0.35,sin(a)*0.35)),frame*tip,frame*(center+Vector3(cos(b)*0.45,0.35,sin(b)*0.35)),Color("eee8d8"))
func cheek_mark(center:Vector3,size:Vector3,frame:Transform3D) -> void:
 var sign_side:float=-1 if center.x<0 else 1
 var corners:=[Vector3(-size.x,-0.2,0),Vector3(-0.2,0.35,0.05),Vector3(size.x,0.2,0),Vector3(size.x,0.55,0),Vector3(-0.15,0.7,0.05),Vector3(-size.x,0.15,0)]
 if sign_side<0:
  for i in corners.size():corners[i].y=-corners[i].y
 for index in range(1,corners.size()-1):triangle(frame*(center+corners[0]),frame*(center+corners[index]),frame*(center+corners[index+1]),Color("eee8d8"))
func nose_wedge(center:Vector3,frame:Transform3D) -> void:
 var points:=[Vector3(-2.5,0.8,-0.4),Vector3(2.5,0.8,-0.4),Vector3(1.5,-1.2,0.2),Vector3(-1.5,-1.2,0.2),Vector3(-1.8,0.8,0.8),Vector3(1.8,0.8,0.8),Vector3(0.9,-1.0,0.9),Vector3(-0.9,-1.0,0.9)]
 for face:Array in [[4,5,6,7],[0,4,7,3],[5,1,2,6],[0,1,5,4],[7,6,2,3]]:
  for indices:Array in [[face[0],face[1],face[2]],[face[0],face[2],face[3]]]:
   triangle(frame*(center+points[indices[0]]),frame*(center+points[indices[1]]),frame*(center+points[indices[2]]),PINK)
func faceted_volume(center:Vector3,size:Vector3,color:Color,basis:Basis) -> void:
 var rings:Array[PackedVector3Array]=[]
 var profile:=[Vector2(-1,0.08),Vector2(-0.68,0.69),Vector2(-0.2,0.98),Vector2(0.34,0.93),Vector2(0.75,0.61),Vector2(1,0.08)]
 if region==1 and color==FUR:profile=[Vector2(-1,0.34),Vector2(-0.75,0.65),Vector2(-0.4,0.89),Vector2(-0.05,1),Vector2(0.35,0.95),Vector2(0.7,0.68),Vector2(1,0.2)]
 elif region==0:profile=[Vector2(-1,0.35),Vector2(-0.65,0.72),Vector2(-0.15,0.9),Vector2(0.35,1),Vector2(0.7,0.82),Vector2(1,0.3)]
 if surface_tag==1:profile=[Vector2(-1,0.70),Vector2(-0.65,0.94),Vector2(0.55,1),Vector2(1,0.70)]
 for level:Vector2 in profile:
  var ring:=PackedVector3Array()
  for i in 10:
   var angle:float=(i+0.5)*TAU/10
   ring.append(center+basis*(Vector3(cos(angle)*level.y,level.x,sin(angle)*level.y)*size))
  rings.append(ring)
 for row in rings.size()-1:
  for i in 10:
   var next:=(i+1)%10
   var tone:=Color("bdb8aa").darkened(float((i*7+row*3)%5)*0.025) if surface_tag==1 else color
   triangle(rings[row][i],rings[row+1][next],rings[row+1][i],tone);triangle(rings[row][i],rings[row][next],rings[row+1][next],tone)
 for i in 10:
  triangle(center-basis*Vector3.UP*size.y,rings[0][(i+1)%10],rings[0][i],color)
  triangle(center+basis*Vector3.UP*size.y,rings[-1][i],rings[-1][(i+1)%10],color)
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
 for face in range(0,vertices.size(),3):
  var normal:Vector3=(vertices[face+2]-vertices[face]).cross(vertices[face+1]-vertices[face]).normalized()
  for corner in 3:
   var index:=face+corner;var amount:=0.75 if int(tags[index].x) in [8,9] else 0.68
   arrays[Mesh.ARRAY_NORMAL][index]=(arrays[Mesh.ARRAY_NORMAL][index] as Vector3).lerp(normal,amount).normalized()
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
