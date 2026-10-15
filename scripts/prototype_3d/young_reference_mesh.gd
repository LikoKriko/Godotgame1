extends RefCounted
## Solid reference reconstruction. Authoring units share the fourteen-bone rig;
## all fur, moss, cartilage, teeth and rock plates have closed volume.
const Motion=preload("res://scripts/prototype_3d/young_pose.gd")
const COAT=Color("7e6652")
const MOSS=Color("a49d68")
const STONE=Color("aaa494")
const PINK=Color("bf8f82")
const IVORY=Color("c6c5bd")
# (height, half-width, half-depth, longitudinal centre), measured against all views.
const BODY=[Vector4(4.5,3.7,3.2,-1.8),Vector4(6.2,5.5,4.8,-1.9),Vector4(9,6.6,6.0,-2.2),Vector4(13,7.2,6.6,-2.3),Vector4(17,7.1,6.7,-2.3),Vector4(20,6.7,6.1,-1.8),Vector4(22,5.4,4.8,-1.4),Vector4(24,2.9,2.7,-0.7),Vector4(24.8,0.15,0.15,-0.5)]
const HEAD=[Vector4(10.5,3.9,4.3,3.0),Vector4(12.5,6.8,6.3,2.7),Vector4(16,8.9,7.8,2.3),Vector4(20,9.6,8.35,2.0),Vector4(24,8.8,7.8,1.5),Vector4(27,6.4,5.9,1.0),Vector4(28.6,3.1,3.0,0.8),Vector4(29.1,0.1,0.1,0.8)]
var surface:=SurfaceTool.new()
var region:=0
var material_kind:StringName=&"fur"
var counts:Dictionary={"fur_locks":0,"moss_locks":0,"rock_plates":0,"ears":0,"claws":0}
func build() -> ArrayMesh:
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 region=0;loft(BODY,COAT)
 coat(BODY,22,35,false)
 region=1;loft(HEAD,COAT)
 coat(HEAD,19,37,true)
 face()
 crest()
 region=0
 # A dense, interrupted golden ridge follows the arch of the back.
 for row in 9:
  var y:=lerpf(12.8,22.0,row/8.0)
  for column in 3:
   var a:float=-PI/2+(column-1)*0.19+0.035*sin(row*1.9)
   var root_point:=profile_point(BODY,y,a,0.55)
   var tip:=profile_point(BODY,maxf(10.2,y-2.6),a+(column-1)*0.10,1.35)
   lock(root_point,tip,0.95+0.12*sin(row+column),moss_color(row*3+column),Vector3(0,0.25,-1),true)
 # The small tail is fleshy, tapered and ridged rather than a pink sphere.
 material_kind=&"skin"
 var tail_root:=Vector3(0,8.2,-8.8)
 curved_taper(tail_root,Vector3(0,7.6,-13.2),1.45,PINK.darkened(0.08),Vector3(0,0.8,0))
 var neutral:=Motion.sample(&"attack",0)
 for side in 2:
  var sign_side:float=-1 if side==0 else 1
  region=2+side;material_kind=&"fur"
  var leg:Dictionary=neutral.legs[side]
  limb(leg,3.2,2.85,COAT)
  limb_coat(leg,3.2,2.85,6,12,false,side)
  region=6+side
  ellipsoid(leg.end+Vector3(0,-0.05,0.5),Vector3(3.65,1.55,3.55),COAT,Transform3D.IDENTITY,20,12)
  for row in 2:
   for column in 6:
    var x:float=(column-2.5)*1.02
    lock(leg.end+Vector3(x,1.1-row*0.8,0.2+row*1.4),leg.end+Vector3(x*1.06,0.1,2.4+row*0.5),0.8,fur_color(row*6+column),Vector3(0,0.5,1))
  material_kind=&"stone"
  for toe in 3:
   counts.claws+=1
   var center:Vector3=leg.end+Vector3((toe-1)*1.75,-0.12,3.55)
   claw(center)

  region=4+side;material_kind=&"fur"
  var arm:Dictionary=neutral.arms[side]
  limb(arm,3.4,3.0,COAT)
  limb_coat(arm,3.4,3.0,9,14,true,side)
  # Broad moss cuffs and shoulder patches remain rooted on the arm skin.
  for row in 3:
   var t:float=0.22+row*0.13
   var center:Vector3=arm.root.lerp(arm.joint,t*2) if t<0.5 else arm.joint.lerp(arm.end,(t-0.5)*2)
   for column in 5:
    var a:float=column*TAU/5+0.25*row
    var outward:=Vector3(sign_side*maxf(0.2,cos(a)),0,sin(a)).normalized()
    var root_point:=center+outward*3.9
    lock(root_point,root_point+Vector3(sign_side*0.25,-2.2,0.4)+outward*0.8,1.0,moss_color(row+column),outward,true)
  region=8+side;material_kind=&"stone"
  stone_fist(arm.end,side)
 surface.generate_normals()
 return surface.commit()
func triangle(a:Vector3,b:Vector3,c:Vector3,color:Color,outward:Vector3=Vector3.ZERO) -> void:
 if outward.length_squared()>0.0001 and (c-a).cross(b-a).dot(outward)<0:
  var swap:=b;b=c;c=swap
 for point:Vector3 in [a,b,c]:
  var patch:=Vector2(fposmod(point.x*0.035+point.z*0.04,1),fposmod(point.y*0.04,1))
  var uv:Vector2=(Vector2(1400,350)+patch*Vector2(35,40))/Vector2(2172,724)
  surface.set_uv(Vector2(region,0.22 if material_kind==&"fur" else 0.0))
  surface.set_uv2(uv);surface.set_color(color);surface.add_vertex(point)
func quad(a:Vector3,b:Vector3,c:Vector3,d:Vector3,color:Color,outward:Vector3) -> void:
 triangle(a,b,c,color,outward);triangle(a,c,d,color,outward)
func profile(values:Array,y:float) -> Vector4:
 for i in values.size()-1:
  if y<=values[i+1].x:
   return (values[i] as Vector4).lerp(values[i+1],clampf((y-values[i].x)/(values[i+1].x-values[i].x),0,1))
 return values[-1]
func profile_point(values:Array,y:float,a:float,lift:float=0.0) -> Vector3:
 var p:=profile(values,y)
 var x:=cos(a)*(p.y+lift)
 # The broad back narrows into the belly instead of forming a cylinder.
 if values==BODY:x*=1-0.10*maxf(0,sin(a))
 return Vector3(x,y,p.w+sin(a)*(p.z+lift))
func back_point(y:float,a:float,lift:float) -> Vector3:
 var head:=profile_point(HEAD,clampf(y,HEAD[0].x,HEAD[-1].x),a,lift)
 var body:=profile_point(BODY,clampf(y,BODY[0].x,BODY[-1].x),a,lift)
 return head if head.z<body.z else body
func loft(values:Array,color:Color) -> void:
 var rings:Array[PackedVector3Array]=[]
 for section in values.size()-1:
  for step in 3:
   var y:float=lerpf(values[section].x,values[section+1].x,step/3.0)
   var ring:=PackedVector3Array()
   for column in 40:ring.append(profile_point(values,y,column*TAU/40))
   rings.append(ring)
 var last:=PackedVector3Array()
 for column in 40:last.append(profile_point(values,values[-1].x,column*TAU/40))
 rings.append(last)
 for row in rings.size()-1:
  for column in 40:
   var n:=(column+1)%40
   var center:Vector3=(rings[row][column]+rings[row+1][n])*0.5
   var outward:=Vector3(center.x,0,center.z-profile(values,center.y).w)
   quad(rings[row][column],rings[row+1][column],rings[row+1][n],rings[row][n],color,outward)
 for i in 40:
  triangle(Vector3(0,values[0].x,values[0].w),rings[0][i],rings[0][(i+1)%40],color,Vector3.DOWN)
  triangle(Vector3(0,values[-1].x,values[-1].w),rings[-1][i],rings[-1][(i+1)%40],color,Vector3.UP)
func ellipsoid(center:Vector3,size:Vector3,color:Color,frame:Transform3D=Transform3D.IDENTITY,columns:int=20,rows:int=12) -> void:
 for row in rows:
  for column in columns:
   var points:Array[Vector3]=[]
   for index:Vector2 in [Vector2(column,row),Vector2(column,row+1),Vector2(column+1,row+1),Vector2(column+1,row)]:
    var lat:=PI*index.y/rows;var lon:=TAU*index.x/columns
    points.append(frame*(center+Vector3(sin(lat)*cos(lon),cos(lat),sin(lat)*sin(lon))*size))
   var outward:Vector3=(points[0]+points[1]+points[2]+points[3])*0.25-frame*center
   quad(points[0],points[1],points[2],points[3],color,outward)
func fur_color(seed_value:int) -> Color:
 return COAT.lightened(0.018*sin(seed_value*2.399)+0.008*cos(seed_value*1.31))
func moss_color(seed_value:int) -> Color:
 return MOSS.lightened(0.026*sin(seed_value*2.399))
func lock(root_point:Vector3,tip:Vector3,width:float,color:Color,outward:Vector3,golden:bool=false) -> void:
 if golden:counts.moss_locks+=1
 else:counts.fur_locks+=1
 var previous:=material_kind
 material_kind=&"moss" if golden else previous
 var axis:=root_point.direction_to(tip)
 var normal:Vector3=(outward-axis*outward.dot(axis)).normalized()
 if normal.length_squared()<0.1:normal=axis.cross(Vector3.RIGHT).normalized()
 if normal.length_squared()<0.1:normal=Vector3.BACK
 var across:=axis.cross(normal).normalized()
 var sections:=[Vector3(0,0.48,0.28),Vector3(0.22,0.87,0.44),Vector3(0.5,0.92,0.43),Vector3(0.77,0.45,0.24),Vector3(1,0.025,0.025)]
 var rings:Array[PackedVector3Array]=[];var centers:Array[Vector3]=[]
 for section:Vector3 in sections:
  var center:=root_point.lerp(tip,section.x)+normal*sin(section.x*PI)*width*0.23
  centers.append(center)
  var ring:=PackedVector3Array()
  for i in 12:
   var a:=i*TAU/12
   ring.append(center+across*cos(a)*width*section.y+normal*sin(a)*width*section.z)
  rings.append(ring)
 for row in rings.size()-1:
  for i in 12:
   var n:=(i+1)%12
   var middle:Vector3=(rings[row][i]+rings[row+1][n])*0.5
   var radial:Vector3=middle-centers[row].lerp(centers[row+1],0.5)
   var tone:=color.darkened(0.035*(1-row/4.0))
   quad(rings[row][i],rings[row+1][i],rings[row+1][n],rings[row][n],tone,radial)
 for i in 12:
  triangle(centers[0],rings[0][(i+1)%12],rings[0][i],color,-axis)
  triangle(centers[-1],rings[-1][i],rings[-1][(i+1)%12],color,axis)
 material_kind=previous
func coat(values:Array,rows:int,columns:int,is_head:bool) -> void:
 material_kind=&"fur"
 for row in rows:
  var y:float=lerpf(values[0].x+1.0,values[-1].x-0.7,(row+0.20*sin(row*2.1))/float(rows-1))
  for column in columns:
   var a:float=(column+row*0.381)*TAU/columns+0.035*sin(column*2.7+row)
   var root_point:=profile_point(values,y,a,0.07)
   if is_head and sin(a)>0.38 and y<22.8 and absf(root_point.x)<7.0:continue
   var length:=1.65+0.40*sin(column*1.9+row*2.1)+(0.25 if not is_head else 0.0)
   var target_y:=maxf(values[0].x-0.5,y-length)
   var sweep:=0.07*sin(column*1.7+row)
   var tip:=profile_point(values,maxf(values[0].x,target_y),a+sweep,1.05)
   tip.y=target_y
   if is_head and sin(a)>0.4:tip.x*=0.91
   var normal:=Vector3(cos(a),0.20,sin(a)).normalized()
   var width:=0.62+0.13*sin(column*2.3+row)
   if not is_head:width+=0.06
   lock(root_point,tip,width,fur_color(column*3+row*7),normal)
func face() -> void:
 region=1;material_kind=&"fur"
 # A low, broad face beneath the forehead: no detached spherical muzzle.
 for side in [-1.0,1.0]:
  ellipsoid(Vector3(side*1.7,15.7,10.5),Vector3(2.1,1.7,2.8),COAT.lightened(0.07))
 material_kind=&"skin"
 ellipsoid(Vector3(0,17.3,10.8),Vector3(1.55,2.7,1.7),PINK.darkened(0.03))
 ellipsoid(Vector3(0,15.6,13.55),Vector3(3.0,2.05,1.65),PINK)
 for side in [-1.0,1.0]:
  ellipsoid(Vector3.ZERO,Vector3(0.50,0.42,0.19),Color("62392f"),Transform3D(Basis(Vector3.BACK,-side*0.18),Vector3(side*1.25,14.95,15.0)),16,9)
 # The forehead fur points towards the snout instead of covering the eyes.
 material_kind=&"fur"
 for row in 5:
  for column in 9:
   var x:float=(column-4)*(1.15-row*0.075)
   var y:float=25.7-row*0.9+0.10*sin(column*1.7+row)
   var tip_x:float=x*0.88
   var tip_y:float=y-1.45
   if tip_y<21 and absf(tip_x)>2.3:continue
   var section:=profile(HEAD,y);var end_section:=profile(HEAD,tip_y)
   var z:float=section.w+section.z*sqrt(maxf(0.05,1-pow(x/section.y,2)))+0.10
   var tip_z:float=end_section.w+end_section.z*sqrt(maxf(0.05,1-pow(tip_x/end_section.y,2)))+0.75
   lock(Vector3(x,y,z),Vector3(tip_x,tip_y,tip_z),0.60+0.06*sin(column*2.4+row),fur_color(row*9+column),Vector3.BACK)
 for i in 11:
  var x:float=(i-5)*0.70
  lock(Vector3(x,13.1+0.25*sin(i*2.2),9.4),Vector3(x*1.04,11.5+0.30*sin(i*2.0),9.9),0.50,fur_color(i).darkened(0.06),Vector3.BACK)
 for side in [-1.0,1.0]:
  ear(side)
  # Narrow almond openings, recessed under the inward-sloping brow.
  material_kind=&"eye"
  eye(side)
  material_kind=&"fur"
  for i in 4:
   var root_point:=Vector3(side*(7.7-i*0.8),22.8-i*0.22,8.2+i*0.4)
   var tip:=Vector3(side*(5.7-i*0.78),20.3-i*0.30,10.1+i*0.16)
   lock(root_point,tip,1.0,fur_color(i),Vector3(side*0.3,0.5,1).normalized())
  # Cheek fans follow the front and side silhouettes, broadening the face.
  for row in 4:
   for column in 3:
    var root_point:=Vector3(side*(7.0+column*0.55),21.5-row*1.6,6.6-column*0.75)
    var tip:=root_point+Vector3(side*(1.7-column*0.1),-2.3,0.45)
    lock(root_point,tip,0.98,fur_color(row*3+column),Vector3(side,0,0.6).normalized())
  material_kind=&"stone"
  for i in 3:
   var root_point:=Vector3(side*(4.3+i*0.25),15.8-i*0.72,11.0-i*0.2)
   var tip:=Vector3(side*(7.6-i*0.25),16.4-i*1.65,10.8-i*0.24)
   shard(root_point,tip,0.48,IVORY)
   if i==1:shard(root_point+Vector3(side*0.6,-0.1,0.10),tip+Vector3(side*0.7,0.6,0.0),0.34,IVORY)
  shard(Vector3(side*6.8,21.0,8.7),Vector3(side*7.9,22.1,8.45),0.45,IVORY)
  shard(Vector3(side*6.6,20.5,9.0),Vector3(side*7.6,20.9,9.05),0.37,IVORY)
  curved_taper(Vector3(side*2.2,13.7,11.6),Vector3(side*2.35,11.65,12.0),0.55,IVORY,Vector3(side*0.2,-0.1,0.6))
func eye(side:float) -> void:
 var origin:=Vector3(side*4.55,18.5,9.8)
 var contour:Array[Vector2]=[Vector2(-1.12,0.45),Vector2(-0.80,0.72),Vector2(-0.30,1.18),Vector2(0.20,1.60),Vector2(0.70,1.65),Vector2(1.10,1.2),Vector2(1.30,0.5),Vector2(1.20,-0.4),Vector2(0.8,-1.2),Vector2(0.1,-1.50),Vector2(-0.60,-1.2),Vector2(-1.0,-0.60)]
 var rim:Array[Vector3]=[];var iris:Array[Vector3]=[]
 for p:Vector2 in contour:
  rim.append(origin+Vector3(p.x*side,p.y,0.30))
  iris.append(origin+Vector3(p.x*side*0.80,p.y*0.86,0.48))
 for i in rim.size():
  var n:=(i+1)%rim.size()
  quad(rim[i],rim[n],iris[n],iris[i],Color("38261e"),Vector3.BACK)
  triangle(origin+Vector3(0,0,0.58),iris[i],iris[n],Color("a92f29").darkened(0.05 if i<4 else 0.0),Vector3.BACK)
  triangle(origin-Vector3.BACK*0.25,rim[n],rim[i],Color("38261e"),Vector3.FORWARD)
 ellipsoid(origin+Vector3(0,-0.04,0.65),Vector3(0.40,1.0,0.12),Color("201a15"),Transform3D.IDENTITY,18,12)
 ellipsoid(origin+Vector3(-side*0.33,0.57,0.74),Vector3(0.23,0.34,0.07),Color("f5eee1"),Transform3D.IDENTITY,12,8)
 ellipsoid(origin+Vector3(side*0.42,-0.65,0.64),Vector3(0.13,0.16,0.06),Color("eac2ad"),Transform3D.IDENTITY,10,7)
func ear(side:float) -> void:
 counts.ears+=1;material_kind=&"skin"
 var rim:Array[Vector3]=[]
 for point:Vector3 in [Vector3(7.5,23.7,1.4),Vector3(9.0,23.5,1.5),Vector3(9.9,24.2,1.7),Vector3(10.5,25.7,1.6),Vector3(10.6,26.5,1.6),Vector3(10.2,27.1,1.7),Vector3(9.4,27.2,1.9),Vector3(8.4,26.8,2.3),Vector3(7.8,26.2,2.5),Vector3(7.3,25,2.6)]:
  rim.append(Vector3(point.x*side,point.y,point.z))
 var center:=Vector3(side*8.9,25.4,1.25)
 var inner:Array[Vector3]=[]
 for point:Vector3 in rim:inner.append(center+(point-center)*0.72)
 for i in rim.size():
  var n:=(i+1)%rim.size()
  quad(rim[i],rim[n],inner[n],inner[i],COAT.darkened(0.04),Vector3.BACK)
  triangle(center,inner[i],inner[n],PINK.darkened(0.05 if i%2==0 else 0.12),Vector3.BACK)
  triangle(center-Vector3.BACK*0.6,rim[n],rim[i],COAT,Vector3.FORWARD)
func shard(root_point:Vector3,tip:Vector3,width:float,color:Color) -> void:
 var old:=material_kind;lock(root_point,tip,width,color,Vector3.BACK);counts.fur_locks-=1;material_kind=old
func curved_taper(root_point:Vector3,tip:Vector3,width:float,color:Color,bend:Vector3) -> void:
 var axis:=root_point.direction_to(tip);var across:=axis.cross(Vector3.BACK).normalized()
 if across.length_squared()<0.1:across=Vector3.RIGHT
 var other:=axis.cross(across).normalized()
 var rings:Array[PackedVector3Array]=[];var centers:Array[Vector3]=[]
 for row in 7:
  var t:=row/6.0;var center:=root_point.lerp(tip,t)+bend*sin(t*PI)
  centers.append(center);var ring:=PackedVector3Array()
  for i in 12:ring.append(center+(across*cos(i*TAU/12)+other*sin(i*TAU/12))*width*pow(1-t,0.68))
  rings.append(ring)
 for row in 6:
  for i in 12:
   var n:=(i+1)%12
   quad(rings[row][i],rings[row+1][i],rings[row+1][n],rings[row][n],color,(rings[row][i]+rings[row+1][n])*0.5-centers[row].lerp(centers[row+1],0.5))
 for i in 12:triangle(centers[0],rings[0][(i+1)%12],rings[0][i],color,-axis)
func claw(center:Vector3) -> void:
 var rings:Array[PackedVector3Array]=[]
 for shape:Vector4 in [Vector4(-0.8,0.92,1.00,0.0),Vector4(0.25,1.02,1.04,0.0),Vector4(1.28,0.68,0.72,-0.30),Vector4(1.55,0.24,0.42,-0.40)]:
  var ring:=PackedVector3Array()
  for i in 10:
   var a:=i*TAU/10
   var point:=center+Vector3(cos(a)*shape.y,sin(a)*shape.z+shape.w,shape.x)
   point.y=maxf(0.03,point.y);ring.append(point)
  rings.append(ring)
 for row in rings.size()-1:
  for i in 10:
   var n:=(i+1)%10
   quad(rings[row][i],rings[row+1][i],rings[row+1][n],rings[row][n],Color("b4b3aa"),Vector3(cos(i*TAU/10),sin(i*TAU/10),0.2))
 for i in 10:
  triangle(center+Vector3(0,0,-0.8),rings[0][i],rings[0][(i+1)%10],Color("b4b3aa"),Vector3.FORWARD)
  triangle(center+Vector3(0,-0.4,1.55),rings[-1][(i+1)%10],rings[-1][i],Color("b4b3aa"),Vector3.BACK)
func crest() -> void:
 region=1;material_kind=&"moss"
 # Interleaved pointed tufts rise at the crown and sweep back along its arch.
 for row in 8:
  var z:float=6.2-row*1.45
  for column in 5:
   var x:float=(column-2)*1.08+0.12*sin(row*2.4)
   var y:=28.9-0.075*x*x-0.11*pow(z-1.4,2)
   var root_point:=Vector3(x,y,z)
   var tip:=Vector3(x*1.04,y+1.45+0.35*sin(row*1.3+column),z-1.8)
   lock(root_point,tip,0.98,moss_color(row*5+column),Vector3(x*0.07,1,(z-1.4)*0.12).normalized(),true)
 for row in 3:
  for column in 5:
   var x:float=(column-2)*1.5+0.16*sin(row*2.7+column)
   lock(Vector3(x,28.4-row*0.85+0.35*sin(column*2.1),6.9+row*0.7),Vector3(x*0.50,25.3-row*1.0+0.45*sin(column*1.7+row),10.4+row*0.7),0.86+0.10*sin(column+row),moss_color(row*5+column),Vector3(0,0.6,1).normalized(),true)
 for i in 7:
  var x:float=(i-3)*0.82
  lock(Vector3(x,28.2,0.6),Vector3(x+0.35,31.5-0.40*absf(x)+0.65*sin(i*2.4),-0.4),0.92,moss_color(i),Vector3.UP,true)
 for row in 3:
  for column in 3:
   var y:float=28.5-row*0.8
   var a:float=-PI/2+(column-1)*0.16
   lock(back_point(y,a,0.45),back_point(y-1.6,a,1.35),1.0,moss_color(row*3+column),Vector3.FORWARD,true)
func limb(joints:Dictionary,upper:float,lower:float,color:Color) -> void:
 var rings:Array[PackedVector3Array]=[];var centers:Array[Vector3]=[]
 for row in 19:
  var t:=row/18.0
  var c:Vector3=joints.root.lerp(joints.joint,t*2) if t<=0.5 else joints.joint.lerp(joints.end,(t-0.5)*2)
  centers.append(c)
  var tangent:Vector3=joints.root.direction_to(joints.joint).slerp(joints.joint.direction_to(joints.end),smoothstep(0.38,0.62,t))
  var across:=tangent.cross(Vector3.BACK).normalized()
  if across.length_squared()<0.1:across=Vector3.RIGHT
  var front:=tangent.cross(across).normalized();var ring:=PackedVector3Array()
  var radius:=lerpf(upper,lower,t)*(0.96+0.05*sin(t*PI*2))
  for i in 20:ring.append(c+(across*cos(i*TAU/20)+front*sin(i*TAU/20))*radius)
  rings.append(ring)
 for row in rings.size()-1:
  for i in 20:
   var n:=(i+1)%20
   quad(rings[row][i],rings[row+1][i],rings[row+1][n],rings[row][n],color,(rings[row][i]+rings[row+1][n])*0.5-centers[row].lerp(centers[row+1],0.5))
 for i in 20:
  triangle(centers[0],rings[0][(i+1)%20],rings[0][i],color,joints.joint.direction_to(joints.root))
  triangle(centers[-1],rings[-1][i],rings[-1][(i+1)%20],color,joints.joint.direction_to(joints.end))
func limb_coat(joints:Dictionary,upper:float,lower:float,rows:int,columns:int,arm:bool,side:int) -> void:
 for row in rows:
  var t:float=0.06+row/float(rows)*(0.87 if arm else 0.78)
  var center:Vector3=joints.root.lerp(joints.joint,t*2) if t<=0.5 else joints.joint.lerp(joints.end,(t-0.5)*2)
  var axis:Vector3=joints.root.direction_to(joints.joint).slerp(joints.joint.direction_to(joints.end),smoothstep(0.4,0.6,t))
  var across:=axis.cross(Vector3.BACK).normalized()
  if across.length_squared()<0.1:across=Vector3.RIGHT
  var front:=axis.cross(across).normalized()
  for column in columns:
   var a:float=(column+row*0.39)*TAU/columns
   var normal:Vector3=across*cos(a)+front*sin(a)
   var radius:=lerpf(upper,lower,t)
   var root_point:=center+normal*(radius-0.05)
   var tip:=root_point+axis*(2.1+0.35*sin(column+row*1.7))+normal*0.35
   lock(root_point,tip,0.84+0.1*sin(column*2.1+row),fur_color(row*13+column+side*7),normal)
func stone_fist(center:Vector3,side:int) -> void:
 # Dual cells of an irregular geodesic shell: pentagonal/hexagonal boulders,
 # independent bevels and fine cracks, without the old latitude/longitude grid.
 var phi:float=(1+sqrt(5.0))/2
 var points:Array[Vector3]=[]
 for p:Vector3 in [Vector3(-1,phi,0),Vector3(1,phi,0),Vector3(-1,-phi,0),Vector3(1,-phi,0),Vector3(0,-1,phi),Vector3(0,1,phi),Vector3(0,-1,-phi),Vector3(0,1,-phi),Vector3(phi,0,-1),Vector3(phi,0,1),Vector3(-phi,0,-1),Vector3(-phi,0,1)]:points.append(p.normalized())
 var faces:Array=[Vector3i(0,11,5),Vector3i(0,5,1),Vector3i(0,1,7),Vector3i(0,7,10),Vector3i(0,10,11),Vector3i(1,5,9),Vector3i(5,11,4),Vector3i(11,10,2),Vector3i(10,7,6),Vector3i(7,1,8),Vector3i(3,9,4),Vector3i(3,4,2),Vector3i(3,2,6),Vector3i(3,6,8),Vector3i(3,8,9),Vector3i(4,9,5),Vector3i(2,4,11),Vector3i(6,2,10),Vector3i(8,6,7),Vector3i(9,8,1)]
 var splits:Dictionary={};var refined:Array=[]
 for face:Vector3i in faces:
  var ids:Array[int]=[]
  for edge:Vector2i in [Vector2i(face.x,face.y),Vector2i(face.y,face.z),Vector2i(face.z,face.x)]:
   var key:=Vector2i(mini(edge.x,edge.y),maxi(edge.x,edge.y))
   if not splits.has(key):splits[key]=points.size();points.append((points[edge.x]+points[edge.y]).normalized())
   ids.append(splits[key])
  refined.append_array([Vector3i(face.x,ids[0],ids[2]),Vector3i(face.y,ids[1],ids[0]),Vector3i(face.z,ids[2],ids[1]),Vector3i(ids[0],ids[1],ids[2])])
 for i in points.size():points[i]=(points[i]+Vector3(sin(i*2.7+side),sin(i*1.3),cos(i*3.1+side))*0.14).normalized()
 var size:=Vector3(4.95,4.45,4.8)
 ellipsoid(center,size*0.97,STONE.darkened(0.02),Transform3D.IDENTITY,24,16)
 for i in points.size():
  var normal:=points[i];var corners:Array[Vector3]=[]
  for face:Vector3i in refined:
   if i in [face.x,face.y,face.z]:corners.append((points[face.x]+points[face.y]+points[face.z]).normalized())
  var axis:=normal.cross(Vector3.UP).normalized()
  if axis.length_squared()<0.1:axis=Vector3.RIGHT
  var other:=normal.cross(axis).normalized()
  corners.sort_custom(func(a:Vector3,b:Vector3):return atan2(a.dot(other),a.dot(axis))<atan2(b.dot(other),b.dot(axis)))
  var radius:float=1.0+0.063*sin(i*3.1+side)
  var mid:Vector3=center+normal*size*(radius+0.028)
  var outer:Array[Vector3]=[];var inner:Array[Vector3]=[]
  for corner:Vector3 in corners:
   var p:=center+corner*size*radius
   outer.append(p);inner.append(mid+(p-mid)*0.82+normal*0.075)
  var color:=STONE.darkened(0.015*float(i%4))
  for corner in outer.size():
   var n:=(corner+1)%outer.size()
   triangle(mid,inner[corner],inner[n],color,normal)
   quad(outer[corner],outer[n],inner[n],inner[corner],color.darkened(0.025),normal)
  counts.rock_plates+=1
