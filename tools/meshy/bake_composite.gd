extends SceneTree
const DEST="res://assets/characters/prototype_3d/composite/"
func _initialize():call_deferred("run")
func run():
 var args:=OS.get_cmdline_user_args();assert(args.size()==1)
 var doc:=GLTFDocument.new();var state:=GLTFState.new();assert(doc.append_from_file(args[0],state)==OK)
 var model:=doc.generate_scene(state);root.add_child(model);model.name="SurvivorNative"
 var node:MeshInstance3D=model.find_children("*","MeshInstance3D",true,false)[0]
 var skeleton:Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
 var reference_document:=GLTFDocument.new();var reference_state:=GLTFState.new()
 assert(reference_document.append_from_file(args[0].get_base_dir()+"/body_reference.glb",reference_state)==OK)
 var reference:=reference_document.generate_scene(reference_state);root.add_child(reference)
 var reference_rig:Skeleton3D=reference.find_children("*","Skeleton3D",true,false)[0]
 var reference_node:MeshInstance3D=reference.find_children("*","MeshInstance3D",true,false)[0]
 assert(reference_rig.get_bone_count()==skeleton.get_bone_count())
 for bone in skeleton.get_bone_count():
  assert(skeleton.get_bone_name(bone)==reference_rig.get_bone_name(bone))
  assert(skeleton.get_bone_parent(bone)==reference_rig.get_bone_parent(bone))
  assert(skeleton.get_bone_rest(bone).is_equal_approx(reference_rig.get_bone_rest(bone)),"Preserve native rest axes")
 for bind in node.skin.get_bind_count():
  var label:=skeleton.get_bone_name(node.skin.get_bind_bone(bind));var found:=false
  for original_bind in reference_node.skin.get_bind_count():
   if reference_rig.get_bone_name(reference_node.skin.get_bind_bone(original_bind))!=label:continue
   assert(node.skin.get_bind_pose(bind).is_equal_approx(reference_node.skin.get_bind_pose(original_bind)),"Preserve native inverse binds")
   found=true;break
  assert(found)
 print("Verified original native hierarchy, rest axes and inverse binds")
 var height:float=JSON.parse_string(FileAccess.get_file_as_string(args[0].get_basename()+".json")).native_height
 model.scale=Vector3.ONE*(64/height);model.position=Vector3(0,0,2.6)
 var head_document:=GLTFDocument.new();var head_state:=GLTFState.new()
 assert(head_document.append_from_file("res://entregables/personajes/personaje1/source/approved_head_source.glb",head_state)==OK)
 var approved_model:=head_document.generate_scene(head_state);root.add_child(approved_model)
 var original:Mesh=approved_model.mesh if approved_model is MeshInstance3D else approved_model.find_children("*","MeshInstance3D",true,false)[0].mesh
 var head_material:Material=load("res://assets/characters/prototype_3d/meshy/survivor_axilla.res").surface_get_material(0)
 var approved:Array=original.surface_get_arrays(0);var buckets:Dictionary={}
 for i in approved[Mesh.ARRAY_VERTEX].size():
  var point:Vector3=approved[Mesh.ARRAY_VERTEX][i]
  if point.y<52.99:continue
  var cell:=Vector3i((point*100).round())
  if not buckets.has(cell):buckets[cell]=[]
  buckets[cell].append(i)
 var rebuilt:=ArrayMesh.new();var matched:=0
 rebuilt.blend_shape_mode=node.mesh.blend_shape_mode
 for shape in node.mesh.get_blend_shape_count():rebuilt.add_blend_shape(node.mesh.get_blend_shape_name(shape))
 for surface in node.mesh.get_surface_count():
  var arrays:Array=node.mesh.surface_get_arrays(surface)
  if surface==1:
   var colors:=PackedColorArray();colors.resize(arrays[Mesh.ARRAY_VERTEX].size())
   for i in colors.size():
    var point:Vector3=arrays[Mesh.ARRAY_VERTEX][i]*(64/1.7)+Vector3(0,-1,2.6)
    var cell:=Vector3i((point*100).round());var best:=-1;var error:=INF
    for x in range(-1,2):
     for y in range(-1,2):
      for z in range(-1,2):
       for candidate:int in buckets.get(cell+Vector3i(x,y,z),[]):
        var distance:float=point.distance_to(approved[Mesh.ARRAY_VERTEX][candidate])
        if distance<.005 and distance<error and arrays[Mesh.ARRAY_TEX_UV][i].distance_to(approved[Mesh.ARRAY_TEX_UV][candidate])<.0001:best=candidate;error=distance
    if best<0:
     assert(absf(point.y-53)<.01,"Preserve every approved head corner above the neck cut")
     continue
    matched+=1;colors[i]=approved[Mesh.ARRAY_COLOR][best];arrays[Mesh.ARRAY_NORMAL][i]=approved[Mesh.ARRAY_NORMAL][best]
    for slot in 4:arrays[Mesh.ARRAY_TANGENT][i*4+slot]=approved[Mesh.ARRAY_TANGENT][best*4+slot]
   arrays[Mesh.ARRAY_COLOR]=colors
  var shapes:Array=node.mesh.surface_get_blend_shape_arrays(surface)
  if surface==1:
   # Both knee morphs leave the approved face and its shading unchanged.
   for shape:Array in shapes:
    shape[Mesh.ARRAY_NORMAL]=arrays[Mesh.ARRAY_NORMAL].duplicate()
    shape[Mesh.ARRAY_TANGENT]=arrays[Mesh.ARRAY_TANGENT].duplicate()
  rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,shapes,{},node.mesh.surface_get_format(surface))
  rebuilt.surface_set_material(surface,node.mesh.surface_get_material(surface))
 node.mesh=rebuilt
 print("Approved head corners restored: ",matched)
 for surface in node.mesh.get_surface_count():
  var material:Material=node.mesh.surface_get_material(surface)
  print("SURFACE ",surface," ",material.resource_name," vertices ",node.mesh.surface_get_array_len(surface)," format ",node.mesh.surface_get_format(surface))
  if material.resource_name=="ApprovedHead":node.mesh.surface_set_material(surface,head_material)
  elif material.resource_name=="NeckTransition":
   var bridge:=StandardMaterial3D.new();bridge.vertex_color_use_as_albedo=true;bridge.roughness=.85;bridge.cull_mode=BaseMaterial3D.CULL_DISABLED
   node.mesh.surface_set_material(surface,bridge)
  else:
   var body:=StandardMaterial3D.new();body.albedo_texture=load(DEST+"body_albedo.png");body.roughness=.85;body.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
   node.mesh.surface_set_material(surface,body)
 var packed:=PackedScene.new();assert(packed.pack(model)==OK);assert(ResourceSaver.save(packed,DEST+"model.scn",ResourceSaver.FLAG_COMPRESS)==OK)
 var records:=[]
 for bone in skeleton.get_bone_count():records.append({"name":skeleton.get_bone_name(bone),"parent":skeleton.get_bone_parent(bone),"rest":var_to_str(skeleton.get_bone_rest(bone))})
 var file:=FileAccess.open(DEST+"rig.json",FileAccess.WRITE);file.store_string(JSON.stringify(records,"  ")+"\n");file.close()
 var parts:=[]
 for surface in node.mesh.get_surface_count():parts.append({"vertices":node.mesh.surface_get_array_len(surface),"triangles":node.mesh.surface_get_array_index_len(surface)/3})
 var manifest:Dictionary={"source_fbx":"entregables/personajes/personaje1/source/psnj1_3d_rigged.fbx","fbx_sha256":FileAccess.get_sha256("res://entregables/personajes/personaje1/source/psnj1_3d_rigged.fbx"),"url":"https://github.com/LikoKriko/Godotgame1/releases/download/Personaje1_Renewed_3d/psnj1_3d_rigged.fbx","head_source":"entregables/personajes/personaje1/source/approved_head_source.glb","head_sha256":FileAccess.get_sha256("res://entregables/personajes/personaje1/source/approved_head_source.glb"),"head_source_commit":"7c93acb","scene":"model.scn","game_height_m":1.75,"author_height":64,"native_height_m":height,"original_bones":66,"profile":"res://data/animation/characters/survivor_native.tres","rig_method":"Original T-pose hierarchy, rest axes and inverse binds; original body skin; approved head bound to native Neck/Head","head_material":"face_materials_v1","body_albedo_sha256":FileAccess.get_sha256(DEST+"body_albedo.png"),"surfaces":parts,"neck":{"body_cut_m":52.5*1.7/64,"head_cut_m":54*1.7/64,"method":"Conforming angular zipper; shared boundary skin; source color gradient","boundary_vertices":[91,64]},"ground_profile":"ground_supports.tres","knee_correctives":{"shapes":["KneeFoldRight","KneeFoldLeft"],"posterior_offset_m":0.08,"radius_m":0.13,"activation":"sin(flexion/2)^2; smooth fade at 115-145 degrees"}}
 file=FileAccess.open(DEST+"source.json",FileAccess.WRITE);file.store_string(JSON.stringify(manifest,"  ")+"\n");file.close()
 print("Native rig ",skeleton.get_bone_count()," bones; parts ",parts)
 model.free();reference.free();approved_model.free();quit()
