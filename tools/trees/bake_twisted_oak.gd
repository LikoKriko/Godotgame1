extends SceneTree
## Godot --headless --path . --script tools/trees/bake_twisted_oak.gd -- edited.glb
const FOLDER:="res://assets/models/meshy/twisted_oak/"
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var args:=OS.get_cmdline_user_args();assert(args.size()==1)
 var provenance:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FOLDER+"source.json"))
 var profile:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://"+provenance.profile))
 var document:=GLTFDocument.new();var state:=GLTFState.new()
 assert(document.append_from_file(args[0],state)==OK)
 var scene:=document.generate_scene(state);root.add_child(scene)
 var nodes:=scene.find_children("*","MeshInstance3D",true,false)
 nodes.sort_custom(func(a,b):return a.name < b.name)
 assert(nodes.size()==2,"One original trunk and one authored branch mesh")
 var mesh:=ArrayMesh.new();var triangles:=0;var vertices:=0
 for node:MeshInstance3D in nodes:
  var authored:=str(node.name).contains("Authored")
  var input:Mesh=node.mesh
  if authored:
   var source_arrays:=input.surface_get_arrays(0)
   var first_uv:PackedVector2Array=source_arrays[Mesh.ARRAY_TEX_UV]
   var second_uv:PackedVector2Array=source_arrays[Mesh.ARRAY_TEX_UV2]
   var mask:PackedColorArray=source_arrays[Mesh.ARRAY_COLOR]
   var first_used:=0;var second_used:=0
   # Blender can reorder UV sets during glTF export. The cylinder map covers
   # all daughter branches; the delivered projection only covers the leader.
   for i in mask.size():
    if mask[i].a>.001:continue
    if first_uv[i].distance_squared_to(Vector2(0,1))>.001:first_used+=1
    if second_uv[i].distance_squared_to(Vector2(0,1))>.001:second_used+=1
   assert(first_used!=second_used,"The two UV roles must be distinguishable")
   if first_used<second_used:
    source_arrays[Mesh.ARRAY_TEX_UV]=second_uv;source_arrays[Mesh.ARRAY_TEX_UV2]=first_uv
   var ordered:=ArrayMesh.new();ordered.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,source_arrays);input=ordered
  # Generate the tangent frame only after selecting the actual bark UV set.
  var surface:=SurfaceTool.new();surface.create_from(input,0);surface.generate_tangents()
  var arrays:=surface.commit().surface_get_arrays(0)
  var positions:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
  var tangents:PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
  for i in positions.size():
   positions[i]=node.global_transform*positions[i]
   normals[i]=(node.global_basis*normals[i]).normalized()
   var tangent:=node.global_basis*Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])
   tangents[i*4]=tangent.x;tangents[i*4+1]=tangent.y;tangents[i*4+2]=tangent.z
  arrays[Mesh.ARRAY_VERTEX]=positions;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TANGENT]=tangents
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  var material:=StandardMaterial3D.new();var prefix:="bark_" if authored else ""
  material.albedo_texture=load(FOLDER+prefix+"albedo.png")
  material.normal_enabled=true;material.normal_texture=load(FOLDER+prefix+"normal.png")
  material.normal_scale=profile.branch_normal_strength if authored else profile.source_normal_strength
  material.roughness=1;material.roughness_texture=load(FOLDER+prefix+"roughness.png")
  material.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
  material.metallic=1;material.metallic_texture=load(FOLDER+prefix+"metallic.png")
  material.metallic_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
  material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
  if authored:
   var blended:=ShaderMaterial.new();blended.shader=load("res://assets/shaders/tree_bark_junction.gdshader")
   for key in ["albedo","normal","roughness","metallic"]:
    blended.set_shader_parameter(key+"_map",load(FOLDER+"bark_"+key+".png"))
    blended.set_shader_parameter("delivered_"+key,load(FOLDER+key+".png"))
   blended.set_shader_parameter("branch_normal_strength",profile.branch_normal_strength)
   blended.set_shader_parameter("source_normal_strength",profile.source_normal_strength)
   mesh.surface_set_material(mesh.get_surface_count()-1,blended)
  else:mesh.surface_set_material(mesh.get_surface_count()-1,material)
  mesh.surface_set_name(mesh.get_surface_count()-1,"radial_branches" if authored else "delivered_roots_trunk")
  triangles+=(arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()/3;vertices+=positions.size()
 assert(absf(mesh.get_aabb().size.y-1)<.00001 and absf(mesh.get_aabb().position.y)<.00001)
 mesh.set_meta("source_zip_sha256",provenance.zip_sha256)
 mesh.set_meta("branch_profile",provenance.profile)
 mesh.set_meta("runtime_triangles",triangles)
 assert(ResourceSaver.save(mesh,FOLDER+"model.res",ResourceSaver.FLAG_COMPRESS)==OK)
 provenance["runtime_triangles"]=triangles;provenance["runtime_vertices"]=vertices
 var derived:Dictionary={}
 for key in ["albedo","normal","roughness","metallic"]:derived["bark_"+key]=FileAccess.get_sha256(FOLDER+"bark_"+key+".png")
 provenance["derived_textures_sha256"]=derived
 var file:=FileAccess.open(FOLDER+"source.json",FileAccess.WRITE);file.store_string(JSON.stringify(provenance,"  ")+"\n");file.close()
 print("PASS: edited oak: ",triangles," triangles; ",vertices," vertices; ",mesh.get_aabb())
 scene.free();quit()
