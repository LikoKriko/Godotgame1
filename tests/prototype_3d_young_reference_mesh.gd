extends SceneTree
## Compare the runtime against the supplied GLB, including its native skin.
const Model=preload("res://scripts/prototype_3d/young_model.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/enemies/first/rig/source.json"))
 require(FileAccess.get_sha256(manifest.source_path)==manifest.source_sha256,"Original supplied GLB remains byte-identical")
 var document:=GLTFDocument.new();var state:=GLTFState.new()
 require(document.append_from_file(manifest.source_path,state)==OK,"Supplied rig imports")
 var source:=document.generate_scene(state);root.add_child(source)
 var rig:Skeleton3D=source.find_children("*","Skeleton3D",true,false)[0]
 var node:MeshInstance3D=source.find_children("*","MeshInstance3D",true,false)[0]
 var baked:=Model.SOURCE.instantiate();root.add_child(baked)
 var baked_node:MeshInstance3D=baked.find_children("*","MeshInstance3D",true,false)[0]
 var actor:=Model.new();root.add_child(actor)
 var second:=Model.new();root.add_child(second)
 var original:Array=node.mesh.surface_get_arrays(0)
 var current:Array=baked_node.mesh.surface_get_arrays(0)
 var facial:Array=actor.mesh_node.mesh.surface_get_arrays(0)
 for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_INDEX,Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS]:
  require(original[channel].to_byte_array()==current[channel].to_byte_array(),"Original geometry, UV and skin channel survives native conversion: "+str(channel))
 for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS]:
  var expected:PackedByteArray=current[channel].to_byte_array()
  require(facial[channel].to_byte_array().slice(0,expected.size())==expected,"Facial derivation preserves the original vertex prefix: "+str(channel))
 require(original[Mesh.ARRAY_VERTEX].size()==manifest.source_vertices,"Original vertex count")
 require(original[Mesh.ARRAY_INDEX].size()/3==manifest.source_triangles,"Original triangle count")
 require(actor.skeleton.get_bone_count()==rig.get_bone_count() and rig.get_bone_count()==25,"Original 25-bone hierarchy")
 for bone in rig.get_bone_count():
  require(actor.skeleton.get_bone_name(bone)==rig.get_bone_name(bone),"Original bone names")
  require(actor.parents[bone]==rig.get_bone_parent(bone),"Original hierarchy")
  require(actor.skeleton.get_bone_rest(bone).is_equal_approx(rig.get_bone_rest(bone)),"Original bind axes")
 for bind in node.skin.get_bind_count():
  require(actor.mesh_node.skin.get_bind_bone(bind)==node.skin.get_bind_bone(bind),"Original skin bind indices")
  require(actor.mesh_node.skin.get_bind_pose(bind).is_equal_approx(node.skin.get_bind_pose(bind)),"Original inverse bind matrices")
 for filename in manifest.textures:
  require(FileAccess.get_sha256(manifest.texture_directory+filename)==manifest.textures[filename],"Original PNG: "+filename)
 require(actor.mesh_node.mesh==second.mesh_node.mesh,"Enemies share the baked facial mesh")
 require(actor.skeleton!=second.skeleton,"Enemies retain independent skeletons")
 actor.animate(&"reference",0)
 for bone in rig.get_bone_count():require(actor.posed[bone].is_equal_approx(rig.get_bone_global_pose(bone)),"Reference reproduces supplied pose")
 actor.animate(&"attack",.5)
 for bone in rig.get_bone_count():require(second.posed[bone].is_equal_approx(rig.get_bone_global_pose(bone)),"Animating one enemy cannot affect another")
 actor.free();second.free();baked.free();source.free()
 print("%s: %d supplied rig, mesh, UV, skin and source integrity checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
