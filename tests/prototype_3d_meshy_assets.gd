extends SceneTree
## These replace the retired procedural painting/scalp projection checks.
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var definitions=[
  ["res://assets/characters/prototype_3d/meshy/","survivor_skin.res",31182,64.0],
  ["res://assets/items/prototype_3d/bottle_meshy/","bottle.res",883250,10.4],
  ["res://assets/models/meshy/axe/","model.res",3104,19.2],
  ["res://assets/models/meshy/pickaxe/","model.res",255100,21.6],
  ["res://assets/models/meshy/bow/","model.res",5215,28.0],
  ["res://assets/models/meshy/leaf_armor/","model.res",10425,29.0],
  ["res://assets/models/meshy/rock1/","model.res",11931,1.0]]
 for definition in definitions:
  var folder:String=definition[0]
  var provenance:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"source.json"))
  require(FileAccess.get_sha256("res://"+provenance.source_fbx)==provenance.fbx_sha256,"The delivered FBX remains byte-identical to the release")
  for key in provenance.textures_sha256:
   require(FileAccess.get_sha256(folder+key+".png")==provenance.textures_sha256[key],"Original "+key+" pixels preserved")
  var mesh:Mesh=load(folder+definition[1]);var arrays:=mesh.surface_get_arrays(0)
  require(mesh.get_surface_count()==1,"Exactly one source surface; no procedural duplicate body")
  require((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()/3==definition[2],"Every original triangle is retained")
  require(absf(mesh.get_aabb().size.y-definition[3])<0.001,"Uniform authoring scale preserves proportions")
  require(mesh.get_meta("source_zip_sha256")==provenance.zip_sha256,"Runtime mesh identifies its exact release archive")
  if mesh.has_meta("skin_surface_profile"):
   var rendered:ShaderMaterial=mesh.surface_get_material(0)
   require(rendered.shader.resource_path=="res://shaders/prototype_3d/survivor_skin.gdshader","Skin polish uses original UV shading in one surface")
   var original:StandardMaterial3D=mesh.get_meta("source_material")
   require(rendered.get_shader_parameter("albedo_map")==original.albedo_texture and rendered.get_shader_parameter("normal_map")==original.normal_texture and rendered.get_shader_parameter("roughness_map")==original.roughness_texture and rendered.get_shader_parameter("metallic_map")==original.metallic_texture,"Rendered skin uses every supplied source map")
   require(is_equal_approx(rendered.get_shader_parameter("skin_normal_strength"),.15),"Skin-only normal detail is attenuated without changing source pixels")
   var mask:PackedColorArray=arrays[Mesh.ARRAY_COLOR];var skin:=0;var unchanged:=0;var protected:=true
   var positions:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   for i in mask.size():
    if mask[i].a>.5:skin+=1
    else:unchanged+=1
    if positions[i].y>52.01:protected=protected and mask[i].a<.01
   require(mask.size()==positions.size() and skin>0 and unchanged>0 and protected,"Surface correction targets skin and preserves hair/face detail")
   var hair_count:=0;var face_count:=0;var masks_valid:=true
   for i in mask.size():
    if mask[i].r>.5:hair_count+=1;masks_valid=masks_valid and positions[i].y>52.9
    if mask[i].g>.5:face_count+=1;masks_valid=masks_valid and positions[i].y>52.8 and positions[i].y<61.0
   require(hair_count>100 and face_count>100 and masks_valid,"Facial masks isolate hair and facial skin from body and clothes")
   require(mesh.get_meta("face_surface_profile")=="face_materials_v1" and rendered.get_shader_parameter("face_detail_map")!=null,"Face uses the authored subtle relief material")
   require(FileAccess.get_sha256(folder+provenance.face_material.detail_normal)==provenance.face_material.detail_sha256,"Facial relief matches the authored texture")
   require(original.cull_mode==BaseMaterial3D.CULL_DISABLED,"Open hair planes remain visible from both sides")
  var material:Material=mesh.get_meta("source_material",mesh.surface_get_material(0))
  require(material is StandardMaterial3D and material.next_pass==null,"Source UV material replaces procedural projection and outline passes")
  var filter:int=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC if mesh.has_meta("face_surface_profile") else BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
  require(material.texture_filter==filter,"Sampling and mipmaps follow the current material finish")
  require(material.albedo_texture!=null and material.normal_texture!=null and material.roughness_texture!=null and material.metallic_texture!=null,"All four supplied texture maps are assigned")
  var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
  var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
  var valid:=uv.size()==points.size() and normals.size()==points.size()
  for i in points.size():valid=valid and points[i].is_finite() and normals[i].is_finite() and uv[i].is_finite() and uv[i].x>=-0.0001 and uv[i].x<=1.0001 and uv[i].y>=-0.0001 and uv[i].y<=1.0001
  require(valid,"Source geometry, UVs and normals are finite and normalized")
 var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();root.add_child(actor)
 var other=load("res://scripts/prototype_3d/survivor_model.gd").new();root.add_child(other)
 require(actor.mesh_node.mesh==other.mesh_node.mesh,"World and portrait reuse the same immutable source mesh")
 require(actor.rig.skeleton!=other.rig.skeleton and actor.native.skeleton!=other.native.skeleton,"Shared immutable skin bindings retain independent control and native poses")
 var rest:Transform3D=other.rig.skeleton.get_bone_global_pose(7)
 actor.family_override=&"axe";actor.animate(&"action",0.5,true)
 require(other.rig.skeleton.get_bone_global_pose(7).is_equal_approx(rest),"Animating one character cannot move another")
 var parts:Array=actor.held_props[&"bottle"].find_children("*","MeshInstance3D",true,false)
 require(parts.size()==1 and parts[0].mesh==load("res://assets/items/prototype_3d/bottle_meshy/bottle.res"),"Held bottle displays only the supplied shared mesh")
 actor.family_override=&"bottle";actor.animate(&"drink",0.5,true)
 var tip:Vector3=preload("res://scripts/prototype_3d/held_profiles.gd").profile(&"bottle").tip
 var mouth:Vector3=preload("res://scripts/prototype_3d/survivor_anatomy.gd").MOUTH
 require((actor.grip_socket.transform*tip).distance_to(actor.last_pose.body*mouth)<0.001,"The imported bottle mouth meets the new character's lips")
 var ground:Node3D=preload("res://scripts/prototype_3d/item_models.gd").create({"id":&"botella","water_ml":500})
 var held_size:Vector3=parts[0].mesh.get_aabb().size*preload("res://scripts/prototype_3d/survivor_anatomy.gd").HEIGHT_METRES/64.0
 var ground_size:Vector3=preload("res://scripts/prototype_3d/item_models.gd").bounds(ground).size
 require(absf(held_size[held_size.max_axis_index()]-ground_size[ground_size.max_axis_index()])<0.0001,"Dropping the bottle preserves its physical size")
 ground.free();actor.free();other.free()
 print("%s: %d Meshy provenance, geometry, material, shared skin and bottle contact checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
