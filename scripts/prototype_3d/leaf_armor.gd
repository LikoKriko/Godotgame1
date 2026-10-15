extends Node3D
## A leaf vest with open armholes and woven shoulder straps, not a closed poncho.
const Meshes=preload("res://scripts/prototype_3d/prop_mesh.gd")
const Anatomy=preload("res://scripts/prototype_3d/survivor_anatomy.gd")
var shell:MeshInstance3D
static var shared_mesh:ArrayMesh
static var shared_material:StandardMaterial3D
static func radius(y:float) -> Vector2:
 var rings:=[Vector3(24.5,6.5,3.2),Vector3(29,6.8,3.1),Vector3(35,6.7,3.2),Vector3(40,8.4,3.6),Vector3(44.5,8.5,3.4),Vector3(46.8,4.2,2.3)]
 for i in rings.size()-1:
  if y<=rings[i+1].x:
   var r:Vector3=rings[i].lerp(rings[i+1],clampf((y-rings[i].x)/(rings[i+1].x-rings[i].x),0,1))
   return Vector2(r.y*Anatomy.BODY_WIDTH+0.25,r.z*Anatomy.BODY_DEPTH+0.25)
 return Vector2(3.8,2.15)
static func point(angle:float,y:float,offset:float=0) -> Vector3:
 var r:=radius(y)+Vector2.ONE*offset
 return Vector3(sin(angle)*r.x,y,cos(angle)*r.y)
static func triangle(surface:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,color:Color) -> void:
 var points:=[a,b,c];var outward:=(a+b+c)*Vector3(1,0,1)
 if (c-a).cross(b-a).dot(outward)<0:points.reverse()
 for p:Vector3 in points:surface.set_color(color);surface.set_uv(Vector2(p.x*0.08,p.y*0.08));surface.add_vertex(p)
static func line(surface:SurfaceTool,points:PackedVector3Array,radius_value:float,color:Color,sides:int=5) -> void:
 var rings:Array[PackedVector3Array]=[]
 for i in points.size():
  var tangent:Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]).normalized()
  var across:=Vector3.RIGHT-tangent*tangent.x
  if across.length_squared()<0.01:across=Vector3.BACK-tangent*tangent.z
  across=across.normalized();var other:=tangent.cross(across).normalized();var ring:=PackedVector3Array()
  for j in sides:ring.append(points[i]+(across*cos(j*TAU/sides)+other*sin(j*TAU/sides))*radius_value)
  rings.append(ring)
 for i in points.size()-1:
  for j in sides:
   var next:=(j+1)%sides
   for vertex:Vector3 in [rings[i][j],rings[i+1][j],rings[i+1][next],rings[i][j],rings[i+1][next],rings[i][next]]:
    surface.set_color(color);surface.set_uv(Vector2(vertex.x,vertex.y)*0.08);surface.add_vertex(vertex)
static func cord(surface:SurfaceTool,path:PackedVector3Array,width:float=0.12) -> void:
 # Three strands keep a visible over/under twist without an extra material pass.
 for strand in 3:
  var points:=PackedVector3Array()
  for i in path.size():
   var tangent:Vector3=(path[mini(i+1,path.size()-1)]-path[maxi(0,i-1)]).normalized()
   var across:=tangent.cross(Vector3.UP)
   if across.length_squared()<0.01:across=Vector3.RIGHT
   across=across.normalized();var other:=tangent.cross(across).normalized();var angle:=i*1.2+strand*TAU/3
   points.append(path[i]+(across*cos(angle)+other*sin(angle))*width)
  line(surface,points,width*0.68,[Color("b1a16e"),Color("c6b985"),Color("8b7850")][strand])
static func leaf(surface:SurfaceTool,angle:float,top:float,length:float,width:float,tone:Color) -> void:
 var rim:=PackedVector3Array();var mid:Vector3=point(angle,top-length*0.44,0.6)
 # A pointed burdock leaf: serrated outline, gentle fold, thin veins.
 var shape:=[Vector2(0,0),Vector2(-0.5,0.1),Vector2(-0.85,0.25),Vector2(-0.76,0.35),Vector2(-1,0.42),Vector2(-0.83,0.58),Vector2(-0.67,0.62),Vector2(-0.64,0.73),Vector2(0,1),Vector2(0.64,0.73),Vector2(0.67,0.62),Vector2(0.83,0.58),Vector2(1,0.42),Vector2(0.76,0.35),Vector2(0.85,0.25),Vector2(0.5,0.1)]
 for p:Vector2 in shape:rim.append(point(angle+p.x*width,top-p.y*length,0.32+sin(p.y*PI)*0.12))
 for i in rim.size():
  var next:=(i+1)%rim.size();triangle(surface,rim[i],rim[next],mid,tone if i<8 else tone.lightened(0.035))
  line(surface,PackedVector3Array([rim[i],rim[next]]),0.04,Color("29391d"),4)
 var spine:=PackedVector3Array()
 for i in 8:spine.append(point(angle,top-length*i/7.0,0.64))
 line(surface,spine,0.045,Color("91a34c"),4)
 for i in range(2,6):
  var y:=top-length*i/7.0
  for side in [-1,1]:line(surface,PackedVector3Array([point(angle,y,0.65),point(angle+side*width*0.7,y+length*0.13,0.5)]),0.022,Color("4f682f"),4)
func _ready() -> void:
 if shared_mesh==null:build()
 shell=MeshInstance3D.new();shell.mesh=shared_mesh;shell.material_override=shared_material;add_child(shell)
static func build() -> void:
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 # Lower woven lining closes around the waist. Above it leave both armholes open.
 for row in 16:
  var top:=lerpf(45.5,24.5,row/16.0);var bottom:=lerpf(45.5,24.5,(row+1)/16.0)
  for column in 48:
   var a:=column*TAU/48;var b:float=(column+1)*TAU/48
   var p:=point(a,top);var q:=point(b,top);var r:=point(b,bottom);var t:=point(a,bottom)
   if top>37.5:
    var limit:=4.15 if top>43 else 5.8
    if maxf(maxf(absf(p.x),absf(q.x)),maxf(absf(r.x),absf(t.x)))>limit:continue
   triangle(surface,p,q,r,Color("48502c"));triangle(surface,p,r,t,Color("48502c"))
 for row in 4:
  var top:=44.8-row*5.0
  if row<2:
   for back in [0.0,PI]:
    for column in 3:leaf(surface,back+(column-1)*(0.52 if row==1 else 0.4)+(0.1 if row==1 else 0.0),top,6.3,0.31,[Color("627b36"),Color("6e853b"),Color("586f31")][(row+column)%3])
  else:
   for column in 12:leaf(surface,(column+float(row%2)*0.5)*TAU/12,top,6.8,0.29,[Color("627b36"),Color("6e853b"),Color("586f31")][(row+column)%3])
 # The shoulder bands rest on the inner shoulder slope and clear the deltoid.
 for side in [-1,1]:
  var path:=PackedVector3Array()
  for i in 21:
   var t:=i/20.0;path.append(Vector3(side*3.1,44.8+sin(t*PI)*1.85,lerpf(3.25,-3.25,t)))
  for offset in [-0.5,0,0.5]:
   var strand:=PackedVector3Array()
   for p in path:strand.append(p+Vector3.RIGHT*offset)
   cord(surface,strand,0.13)
  for z in [-2.8,2.8]:
   var tie:=PackedVector3Array()
   for i in 13:tie.append(Vector3(side*3.1+cos(i*TAU/12)*0.60,45.5+sin(i*TAU/12)*0.35,z))
   cord(surface,tie,0.09)
 # Waist belt, collar binding, two vertical supports and a front knot.
 for y in [28.2,29.3]:
  var path:=PackedVector3Array()
  for i in 97:path.append(point(i*TAU/96,y,0.88))
  cord(surface,path,0.16)
 for back in [0.0,PI]:
  for side in [-1,1]:
   var path:=PackedVector3Array()
   for i in 25:path.append(point(back+side*0.45,44.8-i*16.5/24,0.8))
   cord(surface,path,0.10)
  var collar:=PackedVector3Array()
  for i in 25:
   var angle:float=back+lerpf(-0.46,0.46,i/24.0);collar.append(point(angle,44.7-1.5*sin(i*PI/24),0.85))
  cord(surface,collar,0.14)
 for side in [-1,1]:
  var knot:=PackedVector3Array()
  for i in 21:
   var angle:=i*TAU/20;knot.append(Vector3(1.7+side*0.7*(1-cos(angle)),28.7+sin(angle)*0.55,radius(28.7).y+1.15))
  cord(surface,knot,0.1)
 surface.generate_normals();shared_mesh=surface.commit()
 shared_material=Meshes.material(&"plain").duplicate() as StandardMaterial3D;shared_material.next_pass=null;shared_material.vertex_color_use_as_albedo=true;shared_material.cull_mode=BaseMaterial3D.CULL_DISABLED
