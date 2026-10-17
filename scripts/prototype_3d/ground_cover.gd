extends Node3D
const UNIT:=1.75/64.0
const Meshes=preload("res://scripts/prototype_3d/prop_mesh.gd")
static var meshes:Dictionary={}
static var material:Material
var instance_count:=0
func configure(records:Array,paint:Material=null,prepared:Dictionary={}) -> void:
 instance_count=records.size()
 if paint==null:
  if material==null:material=create_material()
  paint=material
 var data:=prepared
 if data.is_empty():
  var shapes:Array=[]
  for variant in 15:shapes.append(mesh_for(variant).surface_get_arrays(0))
  data=build_arrays(records,Vector2.ZERO,shapes)
 if data.arrays[Mesh.ARRAY_VERTEX].is_empty():return
 var geometry:=ArrayMesh.new();geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data.arrays)
 var node:=MeshInstance3D.new();node.mesh=geometry;node.position=data.origin
 node.set_meta("quality_bucket",true);node.material_override=paint
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
static func create_material() -> ShaderMaterial:
 var paint:=ShaderMaterial.new();paint.shader=preload("res://shaders/prototype_3d/grass_batch.gdshader")
 paint.set_shader_parameter("detail",Meshes.detail_texture(&"leaf"))
 paint.set_shader_parameter("tint",Color("647646"));return paint
static func build_arrays(records:Array,origin:Vector2,shapes:Array) -> Dictionary:
 var vertices:=PackedVector3Array();var normals:=PackedVector3Array()
 var uvs:=PackedVector2Array();var centers:=PackedVector2Array();var colors:=PackedColorArray()
 var counts:Dictionary={}
 for record in records:
  var variant:int=posmod(int(record.variant),15);var i:int=counts.get(variant,0);counts[variant]=i+1
  var p:Vector2=record.position*UNIT-origin;var size:float=record.width*UNIT/0.4
  var rotation:=Basis(Vector3.UP,float(i%13)*0.57)
  var transform:=Transform3D(rotation.scaled(Vector3.ONE*size),Vector3(p.x,.01,p.y))
  var color:=Color(0.88+0.01*(i%9),0.92+0.008*(i%9),0.86+0.01*(i%9))
  var source:Array=shapes[variant]
  for v in source[Mesh.ARRAY_VERTEX].size():
   vertices.append(transform*source[Mesh.ARRAY_VERTEX][v])
   normals.append(rotation*source[Mesh.ARRAY_NORMAL][v]);uvs.append(source[Mesh.ARRAY_TEX_UV][v])
   centers.append(p);colors.append(color)
 var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
 arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_TEX_UV2]=centers;arrays[Mesh.ARRAY_COLOR]=colors
 return {"arrays":arrays,"origin":Vector3(origin.x,0,origin.y)}
static func mesh_for(variant:int) -> ArrayMesh:
 if meshes.has(variant):return meshes[variant]
 var rng:=RandomNumberGenerator.new();rng.seed=7759+variant*3571
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for blade in 7:
  var point:=Vector3(rng.randf_range(-0.2,0.2),0,rng.randf_range(-0.2,0.2));var angle:=rng.randf()*TAU
  var width:=Vector3(cos(angle),0,sin(angle))*rng.randf_range(0.012,0.025)
  var tip:=point+Vector3(rng.randf_range(-0.04,0.04),rng.randf_range(0.07,0.15),rng.randf_range(-0.04,0.04))
  for vertex:Vector3 in [point-width,tip,point+width]:
   surface.set_uv(Vector2(vertex.x+0.5,vertex.y*5));surface.add_vertex(vertex)
 surface.generate_normals();meshes[variant]=surface.commit();return meshes[variant]
