extends RefCounted
## Nine silhouettes traced from the supplied tree sheet, reconstructed in volume.
## Coordinates are fractions of the design height; +Z is the reference front.
const HEIGHTS=[2.65,2.79,3.20,3.28,2.57,1.8375,2.62,2.74,3.24]
const SPINES=[
 [Vector3(0,0,0),Vector3(-0.025,0.24,0),Vector3(-0.06,0.48,0.01),Vector3(0.015,0.70,-0.01),Vector3(0.045,0.85,0)],
 [Vector3(0,0,0),Vector3(0.04,0.25,0),Vector3(-0.03,0.49,0.02),Vector3(-0.13,0.68,0.01),Vector3(-0.22,0.83,0)],
 [Vector3(0,0,0),Vector3(0.10,0.22,0.015),Vector3(0.01,0.42,-0.025),Vector3(-0.045,0.63,0.01),Vector3(-0.01,0.88,0)],
 [Vector3(0,0,0),Vector3(-0.02,0.25,0.01),Vector3(-0.01,0.49,0),Vector3(0.025,0.70,-0.015),Vector3(-0.015,0.90,0)],
 [Vector3(0,0,0),Vector3(0.015,0.27,0.01),Vector3(-0.025,0.49,0.015),Vector3(-0.035,0.67,0),Vector3(-0.07,0.85,0)],
 [Vector3(0,0,0),Vector3(-0.04,0.28,0),Vector3(0.015,0.49,0.01),Vector3(0.005,0.68,0),Vector3(-0.015,0.85,0)],
 [Vector3(0,0,0),Vector3(-0.035,0.26,0),Vector3(0.025,0.50,0),Vector3(0.045,0.69,0.01),Vector3(-0.015,0.86,0)],
 [Vector3(0,0,0),Vector3(0.005,0.25,0),Vector3(-0.01,0.49,0.015),Vector3(-0.015,0.68,0),Vector3(-0.04,0.86,0)],
 [Vector3(0,0,0),Vector3(-0.035,0.25,0.015),Vector3(-0.005,0.45,0),Vector3(-0.045,0.66,-0.015),Vector3(-0.09,0.88,0)]
]
const TIPS=[
 [Vector2(-0.28,0.72),Vector2(-0.23,0.54),Vector2(-0.13,0.87),Vector2(0.02,0.92),Vector2(0.15,0.88),Vector2(0.27,0.65),Vector2(0.20,0.49),Vector2(-0.30,0.42)],
 [Vector2(-0.30,0.75),Vector2(-0.23,0.88),Vector2(0.02,0.94),Vector2(0.13,0.85),Vector2(0.16,0.51),Vector2(-0.20,0.59)],
 [Vector2(-0.28,0.56),Vector2(-0.30,0.72),Vector2(-0.23,0.85),Vector2(-0.10,0.94),Vector2(0.04,0.95),Vector2(0.22,0.87),Vector2(0.30,0.74),Vector2(0.20,0.58),Vector2(0.29,0.45),Vector2(0.14,0.34),Vector2(-0.26,0.43)],
 [Vector2(-0.17,0.91),Vector2(-0.02,0.97),Vector2(0.13,0.91),Vector2(0.19,0.69),Vector2(0.17,0.56),Vector2(-0.20,0.54),Vector2(-0.15,0.40),Vector2(0.17,0.29)],
 [Vector2(-0.12,0.94),Vector2(0.10,0.88),Vector2(0.22,0.71),Vector2(-0.18,0.65),Vector2(0.17,0.48)],
 [Vector2(-0.15,0.88),Vector2(0.02,0.96),Vector2(0.18,0.83),Vector2(0.14,0.55),Vector2(-0.23,0.54)],
 [Vector2(-0.12,0.95),Vector2(0.05,0.94),Vector2(0.22,0.78),Vector2(0.20,0.60),Vector2(-0.17,0.66),Vector2(-0.28,0.49)],
 [Vector2(-0.07,0.95),Vector2(0.11,0.86),Vector2(0.17,0.68),Vector2(-0.18,0.65),Vector2(-0.23,0.52),Vector2(0.15,0.43)],
 [Vector2(-0.13,0.96),Vector2(0.02,0.92),Vector2(0.19,0.86),Vector2(0.28,0.73),Vector2(0.27,0.57),Vector2(0.12,0.47),Vector2(-0.28,0.61),Vector2(-0.22,0.76),Vector2(-0.15,0.41)]
]
const GREENS=[Color("617a2e"),Color("7e9639"),Color("98af43"),Color("b1c654"),Color("4d652a")]
const WOODS=[Color("775033"),Color("9b6a3d"),Color("b4814d"),Color("cd9b5b")]
var vertices:=PackedVector3Array()
var normals:=PackedVector3Array()
var colors:=PackedColorArray()
var uvs:=PackedVector2Array()
var tags:=PackedVector2Array()
var crowns:Array[Dictionary]=[]
var trunk_points:=PackedVector3Array()
var rng:=RandomNumberGenerator.new()
var height:=3.0

func triangle(a:Vector3,b:Vector3,c:Vector3,ua:Vector2,ub:Vector2,uc:Vector2,color:Color,leaf:bool=false,outward:Vector3=Vector3.ZERO) -> void:
 var points:Array[Vector3]=[a,b,c];var tex:Array[Vector2]=[ua,ub,uc]
 if not outward.is_zero_approx() and (c-a).cross(b-a).dot(outward)<0:
  points=[a,c,b];tex=[ua,uc,ub]
 var normal:Vector3=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
 if normal.length_squared()<0.5:return
 for i in 3:
  vertices.append(points[i]);normals.append(normal);colors.append(color.srgb_to_linear().lerp(color,0.45));uvs.append(tex[i]);tags.append(Vector2(1 if leaf else 0,0))

func wood(points:PackedVector3Array,radii:PackedFloat32Array,sides:int=14,phase:float=0.0) -> void:
 var rings:Array[PackedVector3Array]=[];var lengths:Array[float]=[0.0]
 for i in points.size():
  if i>0:lengths.append(lengths[-1]+points[i].distance_to(points[i-1]))
  var tangent:Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]).normalized()
  var across:=Vector3.RIGHT-tangent*tangent.x
  if across.length_squared()<0.01:across=Vector3.BACK-tangent*tangent.z
  across=across.normalized();var forward:=tangent.cross(across).normalized();var ring:=PackedVector3Array()
  for j in sides:
   var angle:=j*TAU/sides
   var flute:=1+0.10*cos(angle*5+phase+i*0.28)+0.055*sin(angle*9-phase+i*0.13)
   var point:Vector3=points[i]+(across*cos(angle)+forward*sin(angle))*radii[i]*flute
   if i==0 and points[i].y<height*.03:point.y=maxf(0,point.y)
   ring.append(point)
  rings.append(ring)
 for row in points.size()-1:
  for j in sides:
   var n:=(j+1)%sides;var center:Vector3=(points[row]+points[row+1])*0.5
   var a:Vector3=rings[row][j];var b:Vector3=rings[row+1][j];var c:Vector3=rings[row+1][n];var d:Vector3=rings[row][n]
   var color:Color=WOODS[1].lightened((0.5+0.5*sin(j*1.7+phase))*0.065)
   var u:=j/float(sides);var un:=(j+1)/float(sides)
   triangle(a,b,c,Vector2(u,lengths[row]),Vector2(u,lengths[row+1]),Vector2(un,lengths[row+1]),color,false,(a+b+c)/3-center)
   triangle(a,c,d,Vector2(u,lengths[row]),Vector2(un,lengths[row+1]),Vector2(un,lengths[row]),color,false,(a+c+d)/3-center)
 for j in sides:
  var n:=(j+1)%sides
  triangle(points[0],rings[0][n],rings[0][j],Vector2(.5,.5),Vector2.ZERO,Vector2.ONE,WOODS[0],false,points[0]-points[1])
  triangle(points[-1],rings[-1][j],rings[-1][n],Vector2(.5,.5),Vector2.ZERO,Vector2.ONE,WOODS[1],false,points[-1]-points[-2])

func leaf(center:Vector3,axis:Vector3,outward:Vector3,length:float,width:float,color:Color) -> void:
 var long_axis:=axis.normalized();var side:=long_axis.cross(outward).normalized()
 if side.length_squared()<0.01:side=long_axis.cross(Vector3.RIGHT).normalized()
 var normal:=side.cross(long_axis).normalized()
 if normal.dot(outward)<0:normal=-normal
 # A tapered, folded, solid leaf. Both faces cast shadows; no camera-facing cards.
 var shape:Array[Vector2]=[Vector2(0,-.5),Vector2(.48,-.22),Vector2(.43,.23),Vector2(0,.5),Vector2(-.43,.23),Vector2(-.48,-.22)]
 var rim:Array[Vector3]=[];var tex:Array[Vector2]=[]
 for p in shape:rim.append(center+side*p.x*width+long_axis*p.y*length);tex.append(p+Vector2(.5,.5))
 for face:float in [-1.0,1.0]:
  var ridge:=center+normal*length*0.13*face
  for i in shape.size():
   var n:=(i+1)%shape.size()
   var before:=vertices.size()
   triangle(rim[i],rim[n],ridge,tex[i],tex[n],Vector2(.5,.45),color if face>0 else color.darkened(0.08),true,normal*face)
   for corner in range(before,vertices.size()):
    var relative:Vector3=vertices[corner]-center
    normals[corner]=(normal*face+side*relative.dot(side)/width*.65+long_axis*relative.dot(long_axis)/length*.45).normalized()

func cluster(center:Vector3,radius:Vector3,seed_value:int) -> void:
 var local:=RandomNumberGenerator.new();local.seed=seed_value
 crowns.append({"position":center,"radius":radius})
 # Small inner leaves fill natural gaps, without a visible solid ball.
 for i in 16:
  var y:=1-2*(i+0.5)/16.0;var a:=i*2.399963
  var direction:=Vector3(cos(a)*sqrt(1-y*y),y,sin(a)*sqrt(1-y*y))
  leaf(center+direction*radius*.45,Vector3.UP-direction*direction.y+Vector3(.1,0,0),direction,height*.075,height*.065,GREENS[0].darkened(.12))
 # Even angular coverage, with deterministic jitter: real volume from all views.
 for i in 96:
  var y:=1-2*(i+0.5)/96.0;var angle:=i*2.399963+local.randf_range(-0.18,0.18)
  var direction:=Vector3(cos(angle)*sqrt(1-y*y),y,sin(angle)*sqrt(1-y*y))
  var lobe:=1+0.19*sin(angle*3.0+y*2.3)+0.10*cos(angle*5.0-y*4.0)
  var point:=center+direction*radius*local.randf_range(0.56,1.03)*lobe
  var axis:=Vector3.UP-direction*direction.y
  if axis.length_squared()<0.01:axis=Vector3.BACK-direction*direction.z
  axis=axis.normalized().rotated(direction,local.randf_range(-.85,.85))
  var leaf_normal:=direction.rotated(axis,local.randf_range(-.4,.4))
  var size:=height*local.randf_range(0.052,0.070)
  var color:Color=GREENS[1].lerp(GREENS[2],local.randf_range(0.0,.65))
  color=color.lightened(maxf(0,direction.y)*0.07).darkened(maxf(0,-direction.y)*0.10)
  if i%8==0:
   var attachment:Vector3=point-axis*size*.48
   wood(PackedVector3Array([center+direction*radius*.25,attachment]),PackedFloat32Array([height*.0015,height*.0007]),4,i*.13)
  leaf(point,axis,leaf_normal,size,size*0.92,color)

func build(design:int,variation:int) -> ArrayMesh:
 design=posmod(design,9);variation=posmod(variation,4);height=HEIGHTS[design]
 rng.seed=19031+design*7919+variation*131
 var spine:Array=SPINES[design]
 # More rings describe buttress roots and the spiralling trunk, not round tubes.
 var radii:=PackedFloat32Array()
 for segment in spine.size()-1:
  for step in 4:
   var t:=step/4.0;var p:Vector3=(spine[segment] as Vector3).cubic_interpolate(spine[segment+1],spine[maxi(0,segment-1)],spine[mini(spine.size()-1,segment+2)],t)
   p.z+=sin(p.y*8+variation*0.8)*0.012*sin(p.y*PI)
   trunk_points.append(p*height)
   radii.append(height*lerpf(0.112,0.018,p.y/0.9)*(1-0.23*smoothstep(0,.12,p.y)))
 trunk_points.append((spine[-1] as Vector3)*height);radii.append(height*0.014)
 wood(trunk_points,radii,24,variation*0.8)
 # Individual buttress roots, low and broad at ground contact.
 for root in 8:
  var angle:=root*TAU/8+variation*0.21
  var radial:=Vector3(cos(angle),0,sin(angle))
  var reach:=height*rng.randf_range(.20,.27)
  wood(PackedVector3Array([radial*reach+Vector3.UP*0.008,radial*reach*.65+Vector3.UP*height*.025,radial*reach*.22+Vector3.UP*height*.10,Vector3.UP*height*.18]),PackedFloat32Array([height*.008,height*.035,height*.050,height*.040]),10,root)
 var tips:Array=TIPS[design]
 for i in tips.size():
  var tip:Vector2=tips[i]
  var anchor_index:=clampi(int((tip.y-0.30)/0.9*(trunk_points.size()-1)),3,trunk_points.size()-3)
  var anchor:Vector3=trunk_points[anchor_index]
  var endpoint:=Vector3(tip.x,tip.y,sin(i*2.399963+0.4)*0.18)*height
  var middle:Vector3=anchor.lerp(endpoint,.55)+Vector3(0,-height*.04,0)
  wood(PackedVector3Array([anchor,middle,endpoint]),PackedFloat32Array([height*.033,height*.023,height*.008]),12,i*.7)
  var size:=height*(0.105 if design in [1,4,5,7] else 0.123)
  for twig in 3:
   var angle:=twig*TAU/3+i*.9
   var end:=endpoint+Vector3(cos(angle)*size*.65,sin(angle*.5)*size*.3,sin(angle)*size*.8)
   wood(PackedVector3Array([endpoint.lerp(middle,.25),endpoint,end]),PackedFloat32Array([height*.009,height*.006,height*.002]),7,twig)
  cluster(endpoint,Vector3(size*1.35,size*.98,size*1.25),design*100003+variation*997+i*31)
 # Rear/front boughs give the same branching character from a side view.
 for i in 4:
  var angle:float=PI*.5+i*PI*.75+variation*.10
  var start:Vector3=trunk_points[7+i]
  var end:=Vector3(cos(angle)*.18,.67+i*.055,sin(angle)*.21)*height
  wood(PackedVector3Array([start,start.lerp(end,.6),end]),PackedFloat32Array([height*.027,height*.016,height*.004]),12,i)
  cluster(end,Vector3.ONE*height*.12,design*7919+variation*313+i)
 # The source has small leaves around the roots as well as crown foliage.
 for i in 18:
  var a:=i*2.4;var point:=Vector3(cos(a),0,sin(a))*height*rng.randf_range(.11,.24)+Vector3.UP*.025
  leaf(point,Vector3(cos(a)*.6,1,sin(a)*.6),Vector3.UP,height*.038,height*.026,GREENS[i%4])
 var peak:=0.0
 for point in vertices:peak=maxf(peak,point.y)
 var scale_value:=height/peak
 var scale:=Vector3(.80,1,.85)*scale_value
 for i in vertices.size():vertices[i]*=scale;normals[i]=(normals[i]/scale).normalized()
 for i in trunk_points.size():trunk_points[i]*=scale
 for group:Dictionary in crowns:group.position*=scale;group.radius*=scale
 var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_TEX_UV2]=tags
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return mesh
