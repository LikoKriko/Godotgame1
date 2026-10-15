extends StaticBody3D
const UNIT:=1.75/64.0
const Art=preload("res://scripts/raised_ground.gd")
const Meshes=preload("res://scripts/prototype_3d/prop_mesh.gd")
var footprint:Rect2
var height:=9.6*UNIT
var polygon:=PackedVector2Array()
func configure(record:Dictionary) -> void:
 Art.prepare()
 footprint=Rect2(record.rect.position*UNIT,record.rect.size*UNIT);position=Vector3(footprint.get_center().x,0,footprint.get_center().y)
 collision_layer=1;collision_mask=0;add_to_group("prototype_platforms");set_meta("physical_height",height)
 var variant:int=record.variant
 var mask:BitMap=Art.surfaces[variant]
 var contours:=mask.opaque_to_polygons(Rect2i(Vector2i.ZERO,mask.get_size()),2)
 if contours.is_empty():return
 var largest:=0
 for i in contours.size():
  if contours[i].size()>contours[largest].size():largest=i
 var uv:PackedVector2Array=contours[largest]
 for point in uv:polygon.append((point/Vector2(mask.get_size())-Vector2.ONE*0.5)*footprint.size)
 var indices:=Geometry2D.triangulate_polygon(polygon)
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(0,indices.size(),3):
  var order:=[indices[i],indices[i+1],indices[i+2]]
  if (polygon[order[2]]-polygon[order[0]]).cross(polygon[order[1]]-polygon[order[0]])>0:order.reverse()
  for index in order:
   var point:=polygon[index];surface.set_uv(uv[index]/Vector2(mask.get_size()));surface.add_vertex(Vector3(point.x,height,point.y))
 surface.generate_normals()
 var mesh:=surface.commit();var top:=MeshInstance3D.new();top.mesh=mesh
 var paint:=StandardMaterial3D.new();paint.albedo_texture=Art.textures[variant];paint.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS;paint.roughness=1;top.material_override=paint;add_child(top)
 var collision:=CollisionShape3D.new();collision.shape=mesh.create_trimesh_shape();add_child(collision)
 var sides:=SurfaceTool.new();sides.begin(Mesh.PRIMITIVE_TRIANGLES)
 var clockwise:=0.0
 for i in polygon.size():clockwise+=polygon[i].cross(polygon[(i+1)%polygon.size()])
 for i in polygon.size():
  var a:=polygon[i];var b:=polygon[(i+1)%polygon.size()]
  var outer_a:=a+a.normalized()*0.45;var outer_b:=b+b.normalized()*0.45
  var points:=[Vector3(outer_a.x,0,outer_a.y),Vector3(a.x,height,a.y),Vector3(b.x,height,b.y),Vector3(outer_a.x,0,outer_a.y),Vector3(b.x,height,b.y),Vector3(outer_b.x,0,outer_b.y)]
  for triangle in 2:
   var v:Array=points.slice(triangle*3,triangle*3+3)
   var edge:=b-a;var outward:=Vector3(edge.y,0,-edge.x)*(1 if clockwise>0 else -1)
   if (v[2]-v[0]).cross(v[1]-v[0]).dot(outward)<0:v.reverse()
   for vertex:Vector3 in v:sides.set_uv(Vector2(vertex.x+vertex.z,vertex.y));sides.add_vertex(vertex)
 sides.generate_normals()
 var side_mesh:=sides.commit();var base:=MeshInstance3D.new();base.mesh=side_mesh
 var soil:Material=Meshes.material(&"soil",Color("66513d")).duplicate();soil.next_pass=soil.next_pass.duplicate();soil.next_pass.set_shader_parameter("thickness",0.003);base.material_override=soil;add_child(base)
 var side_collision:=CollisionShape3D.new();side_collision.shape=side_mesh.create_convex_shape();add_child(side_collision)
func surface_at(point:Vector3) -> float:
 var local:=Vector2(point.x-position.x,point.z-position.z)
 return height if Geometry2D.is_point_in_polygon(local,polygon) else 0.0
