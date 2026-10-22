extends SceneTree
## Fixed native-rig round trip only. Does not retarget or replace approved clips.
const OUTPUT="res://assets/characters/prototype_3d/generated/aren_landing_blender_pilot_v1/"
const SCALE=1.75/64
func _initialize():call_deferred("run")
func run() -> void:
 var document:=GLTFDocument.new();var state:=GLTFState.new()
 if document.append_from_file(OUTPUT+"landing_3m.glb",state)!=OK:quit(1);return
 var source:Node3D=document.generate_scene(state,60.0,false,false);root.add_child(source)
 var skeleton:Skeleton3D=source.find_children("*","Skeleton3D",true,false)[0]
 var player:AnimationPlayer=source.find_children("*","AnimationPlayer",true,false)[0]
 for name in player.get_animation_list():
  if name!=&"RESET":player.play(name);player.seek(0,true);break
 var actor=load("res://scenes/prototype_3d/aren_fall_review_actor.tscn").instantiate();root.add_child(actor);actor.set_process(false)
 var native=actor.native;var ids:Array[int]=[];var offsets:Array[Transform3D]=[]
 var frame:=Transform3D(Basis.from_scale(Vector3.ONE*SCALE),Vector3.ZERO)
 var maximum_rest_error:=0.0
 for bone in native.parents.size():
  var name:String=native.skeleton.get_bone_name(bone)
  var index:=skeleton.find_bone(name)
  if index<0:index=skeleton.find_bone(name.replace("smartrig_","smartrig:"))
  assert(index>=0,"Native bone missing: "+name);ids.append(index)
  var original:Transform3D=skeleton.global_transform*skeleton.get_bone_global_rest(index)
  var target:Transform3D=frame*native.rest[bone]
  maximum_rest_error=maxf(maximum_rest_error,original.origin.distance_to(target.origin))

  offsets.append(original.affine_inverse()*target)
 assert(ids.size()==66 and skeleton.get_bone_count()==66,"Original 66-bone rig required")
 if maximum_rest_error>=.0001:push_error("Rest/units mismatch: "+str(maximum_rest_error));quit(1);return
 var names:=player.get_animation_list();var animation_name:StringName
 for name in names:
  if name!=&"RESET":animation_name=name;break
 assert(not animation_name.is_empty(),"Blender bake has no animation")
 var imported:Animation=player.get_animation(animation_name)
 print("BLENDER IMPORT ",animation_name," duration ",imported.length," rest delta ",maximum_rest_error)
 var clip:=Animation.new();clip.resource_name="ArenLanding3m_BlenderPilot";clip.length=155.0/60;clip.step=1.0/60;clip.loop_mode=Animation.LOOP_NONE
 for bone in native.parents.size():
  for type in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]:
   var track:=clip.add_track(type);clip.track_set_path(track,NodePath("Skeleton3D:"+str(native.skeleton.get_bone_name(bone))));clip.track_set_interpolation_type(track,Animation.INTERPOLATION_LINEAR)
 player.play(animation_name)
 for sample in 156:
  var seconds:=sample/60.0;player.seek(minf(seconds+1.0/60,imported.length),true);skeleton.force_update_all_bone_transforms()
  var poses:Array[Transform3D]=[]
  for bone in native.parents.size():
   var world:Transform3D=skeleton.global_transform*skeleton.get_bone_global_pose(ids[bone])*offsets[bone]
   var author:Transform3D=frame.affine_inverse()*world
   poses.append(native.inverse_frame*author)
  for bone in native.parents.size():
   var parent:int=native.parents[bone]
   var local:Transform3D=poses[parent].affine_inverse()*poses[bone] if parent>=0 else poses[bone]
   clip.position_track_insert_key(bone*3,seconds,local.origin)
   clip.rotation_track_insert_key(bone*3+1,seconds,local.basis.orthonormalized().get_rotation_quaternion())
   clip.scale_track_insert_key(bone*3+2,seconds,local.basis.get_scale())
 clip.set_meta("source_blend",OUTPUT+"authoring/aren_landing_3m.blend");clip.set_meta("source_glb_sha256",FileAccess.get_sha256(OUTPUT+"landing_3m.glb"));clip.set_meta("whole_body_keys",[1,17,37,48,60,71,104,156]);clip.set_meta("impact_time",47.0/60)
 var error:=ResourceSaver.save(clip,OUTPUT+"landing_3m.res");assert(error==OK)
 actor.free();source.free();print("NATIVE BLENDER CLIP SAVED: 66 bones, 156 baked samples");quit()
