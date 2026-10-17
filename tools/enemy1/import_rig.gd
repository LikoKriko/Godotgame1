extends SceneTree
## Preserve the user's SmartRig skeleton, original skin and source geometry.
const BASE="res://assets/enemies/first/rig/"
const TEXTURES="res://assets/enemies/first/meshy/"
func _initialize():call_deferred("run")
func run():
 var document:=GLTFDocument.new();var state:=GLTFState.new()
 assert(document.append_from_file(OS.get_cmdline_user_args()[0],state)==OK)
 var model:=document.generate_scene(state);root.add_child(model)
 var mesh_node:MeshInstance3D=model.find_children("*","MeshInstance3D",true,false)[0]
 var rig:Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
 var mesh:ArrayMesh=mesh_node.mesh
 var material:StandardMaterial3D=mesh.surface_get_material(0)
 material.albedo_texture=load(TEXTURES+"albedo.png");material.normal_texture=load(TEXTURES+"normal.png")
 material.metallic_texture=load(TEXTURES+"metallic_roughness.png");material.roughness_texture=material.metallic_texture
 material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
 mesh.surface_set_material(0,material)
 var packed:=PackedScene.new();assert(packed.pack(model)==OK)
 assert(ResourceSaver.save(packed,BASE+"model.scn",ResourceSaver.FLAG_COMPRESS)==OK)
 var head_bones:Array[int]=[]
 for i in mesh_node.skin.get_bind_count():
  if rig.get_bone_name(mesh_node.skin.get_bind_bone(i)) in ["Bone_016","Bone_015"]:head_bones.append(i)
 print("HEAD skin binds ",head_bones)
 var previous:Mesh=load(TEXTURES+"mossclaw_skin.res")
 var scale_value:float=previous.get_aabb().size.y/mesh.get_aabb().size.y
 var frame:=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*scale_value),previous.get_aabb().position-mesh.get_aabb().position*scale_value)
 var face=load("res://scripts/prototype_3d/young_face.gd").mesh(mesh,head_bones,frame)
 assert(ResourceSaver.save(face,BASE+"face.res",ResourceSaver.FLAG_COMPRESS)==OK)
 print("Imported ",rig.get_bone_count()," original bones; face frame ",frame,"; source vertices ",mesh.surface_get_array_len(0))
 model.queue_free();await process_frame;quit()
