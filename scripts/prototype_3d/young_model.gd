extends "res://tools/enemy/young_volume.gd"
## Bind geometry follows the supplied young mole. Runtime animation is skeletal.
const COAT_COLOR := Color8(144,104,75)
const CREST_COLOR := Color8(194,179,85)
const Motion = preload("res://scripts/prototype_3d/young_pose.gd")
const REFERENCE=preload("res://assets/enemies/first/reference_3d.png")
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
 for point:Vector3 in [a,b,c]:
  var texture_uv:=Vector2.ZERO
  # A clean fur patch preserves the supplied coat palette without painting
  # the reference's stone fists, muzzle or studio backdrop onto curved skin.
  var fur:=color.is_equal_approx(COAT_COLOR) or color.is_equal_approx(COAT_COLOR.lightened(0.10))
  if fur:
   var patch:=Vector2(fposmod(point.x*0.06+point.z*0.05,1),fposmod(point.y*0.06,1))
   texture_uv=(Vector2(1230,335)+patch*Vector2(30,34))/Vector2(REFERENCE.get_size())
  var sample_weight:=0.18 if fur else 0.0
  surface.set_uv(Vector2(region,sample_weight));surface.set_uv2(texture_uv);surface.set_color(color);surface.add_vertex(point)
func pose(_state:String,_phase:float,_direction:int,_left:bool=true) -> void:
 # Author a neutral bind mesh once. Every runtime pose uses the same 14 bones.
 surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 region=0;surface_tag=0
 shell(Vector3(0,14.0,-1.4),Vector3(6.4,8.6,6.8),COAT_COLOR,Transform3D.IDENTITY,16,12)
 fur_coat(Vector3(0,14.0,-1.4),Vector3(6.4,8.6,6.8),Transform3D.IDENTITY,12,26)
 var anchor:=Vector3(0,21,2.5)
 var head_frame:=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*HEAD_SCALE),anchor-anchor*HEAD_SCALE)
 region=1
 shell(Vector3(0,21.2,2.8),Vector3(9.2,8.6,7.6),COAT_COLOR,head_frame,20,16)
 fur_coat(Vector3(0,21.2,2.8),Vector3(9.2,8.6,7.6),head_frame,13,32,true)
 # Full rounded digging muzzle, wide pink nose and two dark nostrils.
 shell(Vector3(0,17.7,10.0),Vector3(4.1,2.9,3.7),COAT_COLOR.lightened(0.12),head_frame,16,10)
 shell(Vector3(0,18.2,12.5),Vector3(3.25,2.25,1.8),PINK.lightened(0.05),head_frame,16,10)
 for side in [-1.0,1.0]:
  shell(Vector3(side*1.25,17.8,14.05),Vector3(0.55,0.42,0.22),Color('4d2924'),head_frame,10,6)
  shell(Vector3(side*8.3,26.2,2.1),Vector3(1.8,1.9,0.8),COAT_COLOR,head_frame,12,8)
  shell(Vector3(side*8.45,26.3,2.85),Vector3(1.2,1.3,0.3),PINK,head_frame,12,8)
  # Sockets are seated against the cheeks. Elongated red irises and brows
  # reproduce the reference expression rather than protruding circular eyes.
  shell(Vector3(side*5.0,21.6,8.85),Vector3(1.85,2.0,0.50),Color('33231d'),head_frame,16,10)
  shell(Vector3(side*5.0,21.6,9.18),Vector3(1.05,1.55,0.35),Color('a92c20'),head_frame,14,10)
  shell(Vector3(side*5.0,21.6,9.47),Vector3(0.43,1.08,0.14),Color('1c1713'),head_frame,10,8)
  shell(Vector3(side*5.0-0.32,22.15,9.63),Vector3(0.32,0.4,0.10),Color('fff2cd'),head_frame,10,6)
  shell(Vector3.ZERO,Vector3(1.9,0.55,0.55),COAT_COLOR.darkened(0.18),head_frame*Transform3D(Basis(Vector3.BACK,side*0.25),Vector3(side*5.0,23.0,9.3)),12,6)
  # Three pale stone whiskers, and small downward ivory fangs.
  for mark in 3:
   var base:=Vector3(side*(4.25+mark*0.65),19.6-mark*0.82,9.6-mark*0.25)
   spike(base,base+Vector3(side*2.2,-0.1-mark*0.35,0.6),0.48,Color('e5debd'),head_frame)
  spike(Vector3(side*1.65,15.9,12.0),Vector3(side*1.75,13.9,12.5),0.56,IVORY,head_frame)
 # Overlapping golden crest runs from forehead to nape, not a flat painted cap.
 for row in 6:
  for column in 3:
   var z:=6.5-row*1.7;var x:float=(column-1)*2.0
   var y:=21.2+8.6*sqrt(maxf(0.05,1-pow(x/9.2,2)-pow((z-2.8)/7.6,2)))
   var tip_z:=z+2.6 if row<3 else z-2.3
   var tip_y:=21.2+8.6*sqrt(maxf(0.05,1-pow(x/9.2,2)-pow((tip_z-2.8)/7.6,2)))+0.3
   tuft(Vector3(x,y+0.15,z),Vector3(x*1.1,tip_y,tip_z),1.4,CREST_COLOR.lightened(0.03*((row+column)%3)),head_frame)
 for row in 3:
  for column in 3:
   var x:float=(column-1)*1.6;var z:=2.5+row*1.5
   var y:=21.2+8.6*sqrt(maxf(0.05,1-pow(x/9.2,2)-pow((z-2.8)/7.6,2)))
   tuft(Vector3(x,y,z),Vector3(x*1.12,y+2.0-absf(x)*0.15,z+1.0),1.05,CREST_COLOR.lightened(0.02*(row%2)),head_frame)
 region=0
 # Back ridge, visible side patches and little fleshy tail from the back view.
 for row in 5:
  for side in [-1.0,1.0]:
   tuft(Vector3(side*1.2,21-row*2.5,-7.2),Vector3(side*1.6,18.8-row*2.5,-8.1),1.25,CREST_COLOR,Transform3D.IDENTITY)
 shell(Vector3(0,8.8,-8),Vector3(1.55,1.5,2.7),PINK,Transform3D.IDENTITY,12,8)
 var neutral:=Motion.sample(&"attack",0)
 for side in 2:
  var sign_side:float=-1 if side==0 else 1
  region=2+side;surface_tag=0
  var leg:Dictionary=neutral.legs[side]
  limb_surface(leg,2.4,1.9,COAT_COLOR)
  region=6+side
  shell(leg.end+Vector3(0,-0.2,0.4),Vector3(2.8,1.5,3.0),COAT_COLOR,Transform3D.IDENTITY,12,8)
  for toe in 3:
   spike(leg.end+Vector3((toe-1)*1.3,-0.1,2.3),leg.end+Vector3((toe-1)*1.4,-0.5,3.6),0.65,IVORY,Transform3D.IDENTITY)
  region=4+side
  var arm:Dictionary=neutral.arms[side]
  limb_surface(arm,3.0,2.6,COAT_COLOR)
  for row in 3:
   var c:Vector3=arm.root.lerp(arm.joint,(row+0.4)/3.5)
   for direction in [Vector3.BACK,Vector3.RIGHT*sign_side]:
    tuft(c+direction*2.5,c+direction*3.1+Vector3(0,-1.8,0),0.9,CREST_COLOR if row<2 else COAT_COLOR,Transform3D.IDENTITY)
  region=8+side;surface_tag=1
  stone_fist(arm.end)
 surface.generate_normals();mesh_node.mesh=surface.commit();mesh_node.position.y=0
func shell(center:Vector3,size:Vector3,color:Color,frame:Transform3D,columns:int=16,rows:int=10) -> void:
 for row in rows:
  for i in columns:
   var quad:Array[Vector3]=[]
   for uv:Vector2 in [Vector2(i,row),Vector2(i,row+1),Vector2(i+1,row+1),Vector2(i+1,row)]:
    var lat:=uv.y*PI/rows;var lon:=uv.x*TAU/columns
    var p:=Vector3(sin(lat)*cos(lon),cos(lat),sin(lat)*sin(lon))
    var ripple:=1.0+0.016*sin(lon*5+lat*4)
    quad.append(frame*(center+p*size*ripple))
   triangle(quad[0],quad[1],quad[2],color);triangle(quad[0],quad[2],quad[3],color)
func tuft(root_point:Vector3,tip:Vector3,width:float,color:Color,frame:Transform3D) -> void:
 var axis:=root_point.direction_to(tip)
 var coat_center:=Vector3(0,21.2,2.8) if region==1 else Vector3(0,14.0,-1.4)
 var outward:Vector3=(root_point-coat_center).normalized()
 var across:=axis.cross(outward).normalized()
 if across.length_squared()<0.1:across=Vector3.RIGHT
 var middle:=root_point.lerp(tip,0.35)
 var ridge:=middle+outward*width*0.38
 var rim:=[root_point-across*width*0.45,middle-across*width,tip,middle+across*width,root_point+across*width*0.45]
 for i in rim.size():
  var a:Vector3=rim[i];var b:Vector3=rim[(i+1)%rim.size()]
  if (ridge-a).cross(b-a).dot(outward)<0:
   var swap:=a;a=b;b=swap
  triangle(frame*a,frame*b,frame*ridge,color.lightened(0.025 if i%2==0 else 0.0))
func fur_coat(center:Vector3,size:Vector3,frame:Transform3D,rows:int,columns:int,face:bool=false) -> void:
 for row in range(1,rows):
  var lat:=row*PI/rows
  for i in columns:
   var lon:float=(i+float(row%2)*0.5)*TAU/columns
   var p:=Vector3(sin(lat)*cos(lon),cos(lat),sin(lat)*sin(lon))
   if face and p.z>0.45 and p.y<0.23 and absf(p.x)<0.72:continue
   var root_point:=center+p*(size+Vector3.ONE*0.04)
   var next_lat:=minf(PI-0.12,lat+0.16)
   var tip:=center+Vector3(sin(next_lat)*cos(lon),cos(next_lat),sin(next_lat)*sin(lon))*(size+Vector3.ONE*0.22)
   tuft(root_point,tip,0.72 if face else 0.78,COAT_COLOR.lightened(0.018*((i*3+row)%4)),frame)
func spike(root_point:Vector3,tip:Vector3,width:float,color:Color,frame:Transform3D) -> void:
 var axis:=root_point.direction_to(tip);var across:=axis.cross(Vector3.UP).normalized()
 if across.length_squared()<0.1:across=Vector3.RIGHT
 var other:=axis.cross(across).normalized()
 for i in 8:
  var a:=i*TAU/8;var b:float=(i+1)*TAU/8
  triangle(frame*(root_point+(across*cos(a)+other*sin(a))*width),frame*tip,frame*(root_point+(across*cos(b)+other*sin(b))*width),color)
func limb_surface(joints:Dictionary,upper:float,lower:float,color:Color) -> void:
 # One continuous tapered tube across the two bones, with flexion at the joint.
 var rings:Array[PackedVector3Array]=[]
 for row in 13:
  var t:=row/12.0;var c:Vector3=joints.root.lerp(joints.joint,t*2) if t<=0.5 else joints.joint.lerp(joints.end,(t-0.5)*2)
  var tangent:Vector3=joints.root.direction_to(joints.joint) if t<0.5 else joints.joint.direction_to(joints.end)
  var across:=tangent.cross(Vector3.BACK).normalized()
  if across.length_squared()<0.1:across=Vector3.RIGHT
  var front:=tangent.cross(across).normalized();var ring:=PackedVector3Array()
  var radius:=lerpf(upper,lower,t)*(0.92+0.12*sin(t*PI*2))
  for i in 12:ring.append(c+(across*cos(i*TAU/12)+front*sin(i*TAU/12))*radius)
  rings.append(ring)
 for row in rings.size()-1:
  for i in 12:
   var n:=(i+1)%12
   triangle(rings[row][i],rings[row+1][i],rings[row+1][n],color);triangle(rings[row][i],rings[row+1][n],rings[row][n],color)
func stone_fist(center:Vector3) -> void:
 # Closed, irregular plates share bevelled edges. No added spherical knuckles.
 var rings:Array[PackedVector3Array]=[]
 for row in 8:
  var ring:=PackedVector3Array()
  for i in 12:
   var lat:=row*PI/7
   if row>0 and row<7:lat+=0.045*sin(i*2.7+row*3.1)
   var lon:float=i*TAU/12+sin(row*2.4)*0.24+float(row%2)*0.12
   var radial:=1+0.035*sin(i*2.7+row*3.3)
   var p:=Vector3(sin(lat)*cos(lon),cos(lat),sin(lat)*sin(lon))
   p=Vector3(signf(p.x)*pow(absf(p.x),0.88),signf(p.y)*pow(absf(p.y),0.9),signf(p.z)*pow(absf(p.z),0.85))
   ring.append(center+p*Vector3(4.6,4.15,4.35)*radial)
  rings.append(ring)
 for row in 7:
  for i in 12:
   var n:=(i+1)%12
   var outer:=[rings[row][i],rings[row+1][i],rings[row+1][n],rings[row][n]]
   var middle:Vector3=(outer[0]+outer[1]+outer[2]+outer[3])/4
   var inner:Array[Vector3]=[]
   var outward:Vector3=center.direction_to(middle)
   for point:Vector3 in outer:inner.append(middle+(point-middle)*0.87+outward*0.17)
   var tone:=Color('c0b49b').darkened(float((row*7+i*3)%7)*0.014)
   triangle(inner[0],inner[1],inner[2],tone);triangle(inner[0],inner[2],inner[3],tone)
   for corner in 4:
    var next:=(corner+1)%4
    triangle(outer[corner],outer[next],inner[next],tone.darkened(0.13));triangle(outer[corner],inner[next],inner[corner],tone.darkened(0.13))
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
