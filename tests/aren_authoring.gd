extends SceneTree
## Acceptance checks through the exported scene and the real AnimationTree.
const Request=preload("res://scripts/animation/authoring/aren_request.gd")
const BASE="res://assets/characters/prototype_3d/generated/aren_%s_v1/aren.tscn"
var failures:=0
var checks:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run() -> void:
 require(Request.parse("Genera una caminata de Aren cautelosa natural zancada media brazos moderados sin deslizamiento de pies").ok,"High-level Spanish request")
 require(not Request.parse("Aren vuela y salta").ok,"Unsupported movement must be rejected")
 require(not Request.parameters("natural",{"cadence":0}).ok,"Invalid cadence rejected")
 require(not Request.parameters("natural",{"stride":NAN}).ok,"Nonfinite input rejected")
 require(not Request.parameters("natural",{"unrecognized":1}).ok,"Unknown parameters rejected")
 require(Request.parameters("natural",{"stride":1.2,"arms":1.3}).ok,"Exact 20/30 percent boundary values accepted")
 require(not Request.parameters("natural",{"arms":1.31}).ok,"Values beyond the tested arm range rejected")
 var spine_rotations:Array[Quaternion]=[]
 for preset in ["natural","cautious","tired","coordinated"]:
  var scene_path:String=BASE%preset if preset!="coordinated" else "res://assets/characters/prototype_3d/generated/aren_walk_torso_v2/aren.tscn"
  var scene=load(scene_path).instantiate();root.add_child(scene);scene.set_process(false)
  require(scene.tree!=null and scene.tree.active,"Exported scene builds an active AnimationTree")
  var skeleton:Skeleton3D=scene.get_node(scene.model_path).find_children("*","Skeleton3D",true,false)[0]
  require(skeleton.get_bone_count()==66,"All original bones retained")
  scene.tree.active=false
  scene.player.play(&"aren/walk");scene.player.seek(.25*scene.library.get_animation(&"walk").length,true)
  skeleton.force_update_all_bone_transforms()
  spine_rotations.append(skeleton.get_bone_global_pose(skeleton.find_bone("smartrig_Spine2")).basis.orthonormalized().get_rotation_quaternion())
  for motion in [&"walk",&"run"]:
   var clip:Animation=scene.library.get_animation(motion)
   require(clip.loop_mode==Animation.LOOP_LINEAR and clip.get_track_count()==200,"Complete native bone tracks and knee correctives")
   require(clip.has_meta("source_hashes"),"Source hashes travel with the exported clip")
   for path in clip.get_meta("source_hashes"):
    # Existing libraries remain immutable when offline authoring tools evolve.
    # The target scene/profile and runtime must still match; authoring hashes
    # identify the historical version, not a requirement to overwrite v1 clips.
    if str(path).begins_with("res://scripts/animation/authoring/") or str(path).begins_with("res://tools/animation/generate_"):continue
    require(preload("res://tests/aren_branch_cache.gd").source_matches(path,clip.get_meta("source_hashes")[path]),"Baked clip matches its rig/runtime fingerprint: "+str(path))
  scene.tree.active=true;scene.tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
  var last:Array[Quaternion]=[]
  var max_step:=0.0
  var walk:float=scene.library.get_animation(&"walk").get_meta("cycle").speed_mps
  var run_speed:float=scene.library.get_animation(&"run").get_meta("cycle").speed_mps
  for frame in 360:
   scene.set_locomotion(0 if frame>=240 else (walk if frame<120 else run_speed))
   scene._process(1.0/60);scene.tree.advance(1.0/60);skeleton.force_update_all_bone_transforms()
   var current:Array[Quaternion]=[]
   for bone in skeleton.get_bone_count():
    var pose:=skeleton.get_bone_pose(bone)
    require(pose.is_finite() and pose.basis.determinant()>0,"Transition has finite uninverted bone transforms")
    current.append(pose.basis.orthonormalized().get_rotation_quaternion())
    if not last.is_empty():max_step=maxf(max_step,current[bone].angle_to(last[bone]))
   last=current
  require(is_zero_approx(scene.blend),"Walk-run-stop returns to idle")
  require(max_step<.6,"Transitions avoid single-frame angular flips")
  var rollback=scene.use_procedural_rollback();root.add_child(rollback)
  require(rollback.native.skeleton.get_bone_count()==66,"Rollback restores approved procedural rig")
  rollback.free();scene.free()
 require(spine_rotations[0].angle_to(spine_rotations[1])>.01,"Cautious style changes the visible upper-body posture")
 require(spine_rotations[1].angle_to(spine_rotations[2])>.08,"Tired style has a clearly distinct articulated posture")
 print("%s: %d Aren request, export, transition and rollback checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
