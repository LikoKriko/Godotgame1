extends SceneTree
const BASE="res://assets/enemies/third/sprout/"
const PREFIX="Meshy_AI_Sunny_Sprout_Dragon_1016224501_texture"
func _initialize():call_deferred("run")
func run():
 var document:=GLTFDocument.new();var state:=GLTFState.new()
 assert(document.append_from_file(OS.get_cmdline_user_args()[0],state)==OK)
 var model:=document.generate_scene(state);root.add_child(model)
 var material:=StandardMaterial3D.new();material.resource_name="Sunny Sprout · originales"
 material.albedo_texture=load(BASE+PREFIX+".png")
 material.normal_enabled=true;material.normal_texture=load(BASE+PREFIX+"_normal.png")
 material.roughness_texture=load(BASE+PREFIX+"_roughness.png");material.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
 material.metallic=1;material.metallic_texture=load(BASE+PREFIX+"_metallic.png");material.metallic_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
 material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
 for node in model.find_children("*","MeshInstance3D",true,false):
  node.material_override=material
  print("MESH ",node.name," bounds ",node.get_aabb()," transform ",node.global_transform)
 for node in model.find_children("*","Skeleton3D",true,false):
  for i in node.get_bone_count():print(i," ",node.get_bone_name(i)," parent ",node.get_bone_parent(i)," rest ",node.get_bone_global_rest(i).origin)
 var packed:=PackedScene.new();assert(packed.pack(model)==OK)
 assert(ResourceSaver.save(packed,BASE+"model.scn",ResourceSaver.FLAG_COMPRESS)==OK)
 model.queue_free();await process_frame;quit()
