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
