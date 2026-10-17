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
 require(current[Mesh.ARRAY_VERTEX].size()==manifest.optimization.runtime_vertices and current[Mesh.ARRAY_VERTEX].size()<original[Mesh.ARRAY_VERTEX].size(),"Runtime really reduces vertex processing")
 require(current[Mesh.ARRAY_INDEX].size()/3==manifest.optimization.runtime_triangles,"Runtime uses the reduced surface")
 require(node.mesh.get_aabb().position.distance_to(baked_node.mesh.get_aabb().position)<.000002 and node.mesh.get_aabb().size.distance_to(baked_node.mesh.get_aabb().size)<.000002,"Optimization preserves height and extreme silhouette bounds")
 var buckets:Dictionary={}
 for vertex in current[Mesh.ARRAY_VERTEX].size():
  var cell:=Vector3i((current[Mesh.ARRAY_VERTEX][vertex] as Vector3)/.00001)
  if not buckets.has(cell):buckets[cell]=[]
  buckets[cell].append(vertex)
  var total:=0.0
  for slot in 4:total+=current[Mesh.ARRAY_WEIGHTS][vertex*4+slot]
  require(absf(total-1)<.0001,"Reduced surface retains normalized skin weights")
 var protected_count:=0
 for vertex in original[Mesh.ARRAY_VERTEX].size():
  var head_weight:=0.0;var foot_weight:=0.0
  for slot in 4:
   var name:=rig.get_bone_name(node.skin.get_bind_bone(original[Mesh.ARRAY_BONES][vertex*4+slot]))
   if name in ["Bone_016","Bone_015"]:head_weight+=original[Mesh.ARRAY_WEIGHTS][vertex*4+slot]
   if name in ["Bone_007","Bone_008","Bone_009","Bone_010","Bone_011","Bone_012","Bone_013","Bone_014"]:foot_weight+=original[Mesh.ARRAY_WEIGHTS][vertex*4+slot]
  if head_weight<=.25 and not (foot_weight>.4 and original[Mesh.ARRAY_VERTEX][vertex].y<.14):continue
  # Boundary faces can disappear during collapse. Require their position and
  # skin; the central face and actual sole also retain their source UV corners.
  var preserve_uv:bool=head_weight>.5 or (foot_weight>.4 and original[Mesh.ARRAY_VERTEX][vertex].y<.065)
  protected_count+=1
  var point:Vector3=original[Mesh.ARRAY_VERTEX][vertex];var cell:=Vector3i(point/.00001);var found:=false
  for x in range(-1,2):
   for y in range(-1,2):
    for z in range(-1,2):
     for candidate in buckets.get(cell+Vector3i(x,y,z),[]):
      if point.distance_to(current[Mesh.ARRAY_VERTEX][candidate])>=.000002:continue
      if preserve_uv and original[Mesh.ARRAY_TEX_UV][vertex].distance_to(current[Mesh.ARRAY_TEX_UV][candidate])>=.000002:continue
      var matching_skin:=true
      for slot in 4:
       var bone:int=original[Mesh.ARRAY_BONES][vertex*4+slot];var weight:=0.0
       for current_slot in 4:
        if current[Mesh.ARRAY_BONES][candidate*4+current_slot]==bone:weight+=current[Mesh.ARRAY_WEIGHTS][candidate*4+current_slot]
       if absf(weight-original[Mesh.ARRAY_WEIGHTS][vertex*4+slot])>.0001:matching_skin=false
      if matching_skin:found=true
  require(found,"Head, facial UVs, soles and their original skin weights remain in the reduced mesh")
 require(protected_count>1000,"Protection check covers detailed source features")
 require(FileAccess.get_sha256("res://assets/enemies/first/rig/"+manifest.optimization.normal_map)==manifest.optimization.normal_map_sha256,"Baked tangent normal is the approved derived texture")
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
