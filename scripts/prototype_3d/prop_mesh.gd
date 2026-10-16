extends RefCounted
## Shared solid geometry and restrained materials; coordinates are authoring units.
static var materials:Dictionary={}
static var cylinder_mesh:CylinderMesh
static func material(kind:StringName,color:Color=Color.WHITE) -> Material:
 var key:=String(kind)+color.to_html()
 if materials.has(key):return materials[key]
 var paint:=StandardMaterial3D.new();paint.roughness=1;paint.albedo_color=color;paint.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
 if kind!=&"plain":paint.albedo_texture=detail_texture(kind)
 var outline:=ShaderMaterial.new();outline.shader=load("res://shaders/prototype_3d/outline.gdshader");outline.set_shader_parameter("thickness",0.11);paint.next_pass=outline
 materials[key]=paint;return paint
static var details:Dictionary={}
static func detail_texture(kind:StringName) -> Texture2D:
 var key:StringName=&"leaf" if kind==&"leaf" else (&"stone" if kind==&"stone" else (&"soil" if kind==&"soil" else (&"rope" if kind==&"rope" else &"wood")))
 if details.has(key):return details[key]
 var atlas:Texture2D=load("res://assets/enemies/prototype_3d/pixel_materials.png" if key in [&"stone",&"leaf"] else "res://assets/characters/prototype_3d/pixel_materials.png")
 var size:=Vector2(atlas.get_size());var offset:=Vector2(0.03 if key==&"leaf" else 0.53,0.53 if key in [&"rope",&"leaf"] else 0.03)
 var image:=atlas.get_image().get_region(Rect2i(Vector2i(offset*size),Vector2i(size*0.44)))
 if key==&"soil":image=load("res://assets/environment/imported/terreno_1_4.png").get_image()
 image.resize(256,256,Image.INTERPOLATE_NEAREST);image.convert(Image.FORMAT_RGB8)
 for y in image.get_height():
  for x in image.get_width():
   var sample:=image.get_pixel(x,y);var value:=0.83+sample.get_luminance()*0.17
   image.set_pixel(x,y,Color(value,value,value))
 details[key]=ImageTexture.create_from_image(image);return details[key]
static func segment(parent:Node3D,a:Vector3,b:Vector3,radius:float,paint:Material) -> MeshInstance3D:
 if cylinder_mesh==null:
  cylinder_mesh=CylinderMesh.new();cylinder_mesh.height=1;cylinder_mesh.top_radius=1;cylinder_mesh.bottom_radius=1;cylinder_mesh.radial_segments=8
 var node:=MeshInstance3D.new();node.mesh=cylinder_mesh;node.material_override=paint;parent.add_child(node)
 orient_segment(node,a,b,radius);return node
static func orient_segment(node:Node3D,a:Vector3,b:Vector3,radius:float) -> void:
 var span:=b-a;node.position=(a+b)*0.5
 var rotation_basis:=Basis(Quaternion(Vector3.UP,span.normalized()))
 node.basis=Basis(rotation_basis.x*radius,rotation_basis.y*maxf(0.001,span.length()),rotation_basis.z*radius)
static func sphere(parent:Node3D,point:Vector3,radius:Vector3,paint:Material) -> MeshInstance3D:
 var mesh:=SphereMesh.new();mesh.radius=1;mesh.height=2;mesh.radial_segments=16;mesh.rings=8
 var node:=MeshInstance3D.new();node.mesh=mesh;node.position=point;node.scale=radius;node.material_override=paint;parent.add_child(node);return node
static func slab(parent:Node3D,points:PackedVector2Array,half_depth:float,paint:Material) -> MeshInstance3D:
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var indices:=Geometry2D.triangulate_polygon(points)
 var low:=points[0];var high:=low
 for point in points:low=low.min(point);high=high.max(point)
 for side in [-1.0,1.0]:
  for i in range(0,indices.size(),3):
   var order:=[indices[i],indices[i+1],indices[i+2]] if side>0 else [indices[i+2],indices[i+1],indices[i]]
   if (points[order[2]]-points[order[0]]).cross(points[order[1]]-points[order[0]])*side<0:order.reverse()
   for index in order:
    var point:=points[index];surface.set_uv((point-low)/(high-low).max(Vector2.ONE*0.01));surface.add_vertex(Vector3(point.x,point.y,side*half_depth))
 var area:=0.0
 for i in points.size():area+=points[i].cross(points[(i+1)%points.size()])
 for i in points.size():
  var a:=points[i];var b:=points[(i+1)%points.size()]
  var vertices:=[Vector3(a.x,a.y,-half_depth),Vector3(b.x,b.y,-half_depth),Vector3(b.x,b.y,half_depth),Vector3(a.x,a.y,-half_depth),Vector3(b.x,b.y,half_depth),Vector3(a.x,a.y,half_depth)]
  var edge:=b-a;var outward:=Vector3(edge.y,-edge.x,0)*(1 if area>0 else -1)
  for triangle in 2:
   var v:Array=vertices.slice(triangle*3,triangle*3+3)
   if (v[2]-v[0]).cross(v[1]-v[0]).dot(outward)<0:v.reverse()
   for vertex:Vector3 in v:
    surface.set_uv(Vector2((vertex.x-low.x)/maxf(0.01,high.x-low.x),(vertex.y-low.y)/maxf(0.01,high.y-low.y)));surface.add_vertex(vertex)
 surface.generate_normals()
 var node:=MeshInstance3D.new();node.mesh=surface.commit();node.material_override=paint;parent.add_child(node);return node
static func bindings(parent:Node3D,y:float,radius:float=1.7) -> void:
 var rope:=material(&"rope",Color("b5ac72"))
 for offset in [-1.4,0.0,1.4]:
  var mesh:=TorusMesh.new();mesh.inner_radius=radius-0.35;mesh.outer_radius=radius;mesh.rings=12;mesh.ring_segments=5
  var node:=MeshInstance3D.new();node.mesh=mesh;node.position.y=y+offset;node.material_override=rope;parent.add_child(node)
 for side in [-1,1]:segment(parent,Vector3(-2,y-3.5,side*1.1),Vector3(2,y+3.5,side*1.1),0.35,rope)

static func beveled_blade(parent:Node3D,polygon:PackedVector2Array,depth:float,paint:Material) -> MeshInstance3D:
 # Preserve the cutting silhouette, with a thin edge and recessed bevel ring.
 var center:=Vector2.ZERO
 for p in polygon:center+=p
 center/=polygon.size()
 var inset:=PackedVector2Array()
 for p in polygon:inset.append(center+(p-center)*0.77)
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for side in [-1.0,1.0]:
  var indices:=Geometry2D.triangulate_polygon(inset)
  for i in range(0,indices.size(),3):
   var order:=[indices[i],indices[i+1],indices[i+2]]
   if (inset[order[2]]-inset[order[0]]).cross(inset[order[1]]-inset[order[0]])*side<0:order.reverse()
   for index in order:
    var point:=inset[index];surface.set_uv(point*0.12);surface.add_vertex(Vector3(point.x,point.y,side*depth))
  for i in polygon.size():
   var next:=(i+1)%polygon.size()
   var a:=Vector3(polygon[i].x,polygon[i].y,0);var b:=Vector3(polygon[next].x,polygon[next].y,0)
   var c:=Vector3(inset[next].x,inset[next].y,side*depth);var d:=Vector3(inset[i].x,inset[i].y,side*depth)
   for points:Array in [[a,b,c],[a,c,d]]:
    if side<0:points.reverse()
    for p:Vector3 in points:surface.set_uv(Vector2(p.x,p.y)*0.12);surface.add_vertex(p)
 surface.generate_normals()
 var node:=MeshInstance3D.new();node.name="BeveledStoneBlade";node.mesh=surface.commit();node.material_override=paint;parent.add_child(node);return node
static func polyline(parent:Node3D,points:PackedVector3Array,radii:PackedFloat32Array,paint:Material,sides:int=7) -> MeshInstance3D:
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var rings:Array[PackedVector3Array]=[]
 for i in points.size():
  var tangent:Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]).normalized()
  var across:=Vector3.RIGHT-tangent*tangent.x
  if across.length_squared()<0.01:across=Vector3.BACK-tangent*tangent.z
  across=across.normalized();var other:=tangent.cross(across).normalized();var ring:=PackedVector3Array()
  for j in sides:ring.append(points[i]+(across*cos(j*TAU/sides)+other*sin(j*TAU/sides))*radii[i])
  rings.append(ring)
 for i in points.size()-1:
  for j in sides:
   var next:=(j+1)%sides
   for point:Vector3 in [rings[i][j],rings[i+1][j],rings[i+1][next],rings[i][j],rings[i+1][next],rings[i][next]]:
    surface.set_uv(Vector2(point.x*0.2+point.z*0.1,point.y*0.12));surface.add_vertex(point)
 for j in sides:
  for point:Vector3 in [points[0],rings[0][(j+1)%sides],rings[0][j],points[-1],rings[-1][j],rings[-1][(j+1)%sides]]:
   surface.set_uv(Vector2(point.x,point.z));surface.add_vertex(point)
 surface.generate_normals()
 var node:=MeshInstance3D.new();node.mesh=surface.commit();node.material_override=paint;parent.add_child(node);return node
