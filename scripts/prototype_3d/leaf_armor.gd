extends Node3D
## One torso shell, leaf tiles and seams; follows the same body transform as skin.
const Meshes=preload("res://scripts/prototype_3d/prop_mesh.gd")
var shell:MeshInstance3D
static var shared_mesh:ArrayMesh
static var shared_material:StandardMaterial3D
static func radius(y:float) -> Vector2:
 var rings:=[Vector3(24.5,6.5,3.2),Vector3(29,6.4,3.25),Vector3(35,6.2,3.25),Vector3(40,7.2,3.6),Vector3(44.5,7.9,3.65),Vector3(46.8,7.8,3.4),Vector3(49,2.4,1.95)]
 for i in rings.size()-1:
  if y<=rings[i+1].x:
   var ring:Vector3=rings[i].lerp(rings[i+1],clampf((y-rings[i].x)/(rings[i+1].x-rings[i].x),0,1));return Vector2(ring.y,ring.z)
 return Vector2(2.4,1.95)
static func point(angle:float,y:float,offset:float=0) -> Vector3:
 var r:=radius(y)+Vector2.ONE*offset
 return Vector3(sin(angle)*r.x,y,cos(angle)*r.y)
static func triangle(surface:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,color:Color) -> void:
 var vertices:=[a,b,c]
 var outward:=(a+b+c)*Vector3(1,0,1)
 if (c-a).cross(b-a).dot(outward)<0:vertices.reverse()
 for vertex:Vector3 in vertices:
  surface.set_color(color);surface.set_uv(Vector2(fposmod(vertex.x*0.08+vertex.z*0.07,1),fposmod(vertex.y*0.07,1)));surface.add_vertex(vertex)
func _ready() -> void:
 if shared_mesh==null:build()
 shell=MeshInstance3D.new();shell.mesh=shared_mesh;shell.material_override=shared_material;add_child(shell)
static func build() -> void:
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 # Continuous woven backing covers chest, abdomen, back and shoulders; neck open.
 for row in 12:
  var top:=lerpf(49,24.5,row/12.0);var bottom:=lerpf(49,24.5,(row+1)/12.0)
  for column in 32:
   var a:=column*TAU/32;var b:float=(column+1)*TAU/32
   var p:=point(a,top);var q:=point(b,top);var r:=point(b,bottom);var s:=point(a,bottom)
   triangle(surface,p,q,r,Color("41492b"));triangle(surface,p,r,s,Color("41492b"))
 # Overlapping, mostly flat leaves: three tones, a fine dark seam at each edge.
 for row in 5:
  var top:=47.8-row*4.6;var bottom:=maxf(24.5,top-6.0)
  for column in 16:
   var a:float=(column+float(row%2)*0.5)*TAU/16;var width:=TAU/16*0.47
   var shape:=[point(a,top,0.4),point(a-width*0.65,top-0.65,0.36),point(a-width,top-2.0,0.32),point(a-width*0.6,bottom+1.2,0.3),point(a,bottom,0.28),point(a+width*0.6,bottom+1.2,0.3),point(a+width,top-2.0,0.32),point(a+width*0.65,top-0.65,0.36)]
   var middle:=point(a,lerpf(top,bottom,0.4),0.47)
   var tone:Color=[Color("627b36"),Color("6f8840"),Color("597132")][(row+column)%3]
   for edge_index in shape.size():
    var p:Vector3=shape[edge_index];var q:Vector3=shape[(edge_index+1)%shape.size()]
    triangle(surface,p,q,middle,tone.darkened(0.025) if edge_index<4 else tone)
    var edge:Vector3=(q-p).normalized();var side:=edge.cross((p*Vector3(1,0,1)).normalized()).normalized()*0.045
    triangle(surface,p-side,p+side,q+side,Color("29341d"));triangle(surface,p-side,q+side,q-side,Color("29341d"))
   var vein_top:Vector3=shape[0];var vein_tip:Vector3=shape[4]
   var tangent:=Vector3(cos(a),0,-sin(a))*0.035
   triangle(surface,vein_top-tangent,vein_top+tangent,vein_tip+tangent,Color("455b29"));triangle(surface,vein_top-tangent,vein_tip+tangent,vein_tip-tangent,Color("455b29"))
 # Thin cordage across the chest and waist, with the same shared torso motion.
 for y in [28.0,40.5,46.2]:
  for column in 64:
   var a:=column*TAU/64;var b:float=(column+1)*TAU/64
   var p:=point(a,y,0.6);var q:=point(b,y,0.6)
   triangle(surface,p+Vector3.UP*0.16,q+Vector3.UP*0.16,q-Vector3.UP*0.16,Color("b1a16e"));triangle(surface,p+Vector3.UP*0.16,q-Vector3.UP*0.16,p-Vector3.UP*0.16,Color("b1a16e"))
 surface.generate_normals();shared_mesh=surface.commit()
 shared_material=Meshes.material(&"plain").duplicate() as StandardMaterial3D;shared_material.vertex_color_use_as_albedo=true;shared_material.cull_mode=BaseMaterial3D.CULL_DISABLED
