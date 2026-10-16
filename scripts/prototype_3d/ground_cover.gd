extends Node3D
const UNIT:=1.75/64.0
const Meshes=preload("res://scripts/prototype_3d/prop_mesh.gd")
static var meshes:Dictionary={}
static var material:Material
func configure(records:Array) -> void:
 if material==null:
  material=Meshes.material(&"leaf",Color("647646")).duplicate();material.vertex_color_use_as_albedo=true;material.next_pass=null;material.cull_mode=BaseMaterial3D.CULL_DISABLED
 var groups:Dictionary={}
 for record in records:
  var variant:int=posmod(int(record.variant),15)
  if not groups.has(variant):groups[variant]=[]
  groups[variant].append(record)
 for variant in groups:
  var node:=MultiMeshInstance3D.new();var multimesh:=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.use_colors=true;multimesh.mesh=mesh_for(variant);multimesh.instance_count=groups[variant].size();node.multimesh=multimesh;node.material_override=material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
  for i in groups[variant].size():
   var record:Dictionary=groups[variant][i];var p:Vector2=record.position*UNIT;var size:float=record.width*UNIT/0.4
   var basis:=Basis(Vector3.UP,float(i%13)*0.57).scaled(Vector3.ONE*size)
   multimesh.set_instance_transform(i,Transform3D(basis,Vector3(p.x,0.01,p.y)))
   multimesh.set_instance_color(i,Color(0.88+0.01*(i%9),0.92+0.008*(i%9),0.86+0.01*(i%9)))
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
