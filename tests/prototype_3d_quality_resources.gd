extends SceneTree
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func triangles(mesh:Mesh) -> int:
 var total:=0
 for surface in mesh.get_surface_count():
  var arrays:=mesh.surface_get_arrays(surface)
  total+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
 return total
func run():
 var builder=load("res://scripts/prototype_3d/quality_meshes.gd").new()
 for source:Mesh in [load("res://assets/characters/prototype_3d/meshy/survivor_skin.res"),load("res://assets/models/meshy/axe/model.res"),load("res://assets/models/meshy/bow/deformable.res"),load("res://assets/models/meshy/leaf_armor/worn.res"),preload("res://scripts/prototype_3d/young_face.gd").mesh(load("res://assets/enemies/first/meshy/mossclaw_skin.res"))]:
  builder.prepare(source);builder.collect()
  var reduced:Mesh=builder.mesh(source,35)
  require(builder.mesh(source,100)==source,"Full quality is the exact immutable source mesh")
  require(triangles(reduced)<=triangles(source) and triangles(reduced)>0,"Derived LOD retains valid triangles without adding geometry")
  require(reduced.get_blend_shape_count()==source.get_blend_shape_count(),"LOD preserves every facial/rope blend shape")
  for surface in reduced.get_surface_count():
   var arrays:=reduced.surface_get_arrays(surface)
   var count:int=arrays[Mesh.ARRAY_VERTEX].size()
   for index in arrays[Mesh.ARRAY_INDEX]:require(index>=0 and index<count,"Every simplified triangle references an existing weighted vertex")
   for shape in reduced.surface_get_blend_shape_arrays(surface):require(shape[Mesh.ARRAY_VERTEX].size()==count,"Morph deltas still match the LOD vertex buffer")
  if source.resource_path.contains("axe/"):require(triangles(reduced)<triangles(source),"A detailed source actually renders fewer triangles at distance")
 var materials=load("res://scripts/prototype_3d/quality_materials.gd").new()
 var source:Material=load("res://assets/models/meshy/axe/model.res").surface_get_material(0)
 var original_texture:Texture2D=source.albedo_texture
 var low:ShaderMaterial=materials.material(source,50)
 require(low.get_shader_parameter("distance_quality")==.5,"Texture mip bias is controlled by the exact requested quality")
 require(low.get_shader_parameter("albedo_map")==original_texture and source.albedo_texture==original_texture,"Quality variants reuse the original texture without altering source assets")
 require(materials.material(source,100)==source,"Close range restores the original material")
 require(original_texture.get_image().has_mipmaps(),"World textures contain real reduced-resolution mip levels")
 var terrain:=ShaderMaterial.new();terrain.shader=load("res://shaders/prototype_3d/chunk_ground.gdshader")
 terrain.set_shader_parameter("seed_value",123)
 var low_terrain:ShaderMaterial=materials.material(terrain,65)
 require(low_terrain.get_shader_parameter("seed_value")==123 and low_terrain.shader.code.contains("quality_texture"),"Procedural terrain retains seed and gains texture quality control")
 low_terrain.set_shader_parameter("ambient_tint",Vector3(.2,.3,.4))
 var restored:ShaderMaterial=materials.material(terrain,100,low_terrain)
 require(restored.get_shader_parameter("ambient_tint")==Vector3(.2,.3,.4),"Quality changes preserve live terrain lighting updates")
 var procedural:Mesh=preload("res://scripts/prototype_3d/tree_geometry.gd").new().build(0,0)
 var original_arrays:=procedural.surface_get_arrays(0)
 builder.prepare(procedural);builder.collect()
 var distant:Mesh=builder.mesh(procedural,35)
 require(triangles(distant)>=triangles(procedural)*.15 and triangles(distant)<=triangles(procedural)*.6,"Triangle-soup trees receive a useful intermediate LOD, not the final collapsed index buffer")
 require(builder.mesh(procedural,95)==procedural,"Near-full budget retains the source rather than inheriting a lower budget's indices")
 var distant_indices:PackedInt32Array=distant.surface_get_arrays(0)[Mesh.ARRAY_INDEX].duplicate()
 builder.mesh(procedural,45);builder.mesh(procedural,75)
 require(distant.surface_get_arrays(0)[Mesh.ARRAY_INDEX]==distant_indices,"Independent quality variants do not mutate one another")
 require(procedural.surface_get_arrays(0)==original_arrays,"Generating indexed variants leaves procedural source buffers untouched")
 builder.finish();print("%s: %d derived mesh and texture resource checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
