extends SceneTree
## Focused regression: isolated run/idle revision; approved walk is immutable.
const BASE="res://assets/characters/prototype_3d/generated/aren_walk_torso_v2/aren.tscn"
const REVISED="res://assets/characters/prototype_3d/generated/aren_run_idle_v3/aren.tscn"
var failures:Array[String]=[]
func _initialize():call_deferred("run")
func check(condition:bool,message:String):
 if not condition:failures.append(message);push_error(message)
func equal_clip(a:Animation,b:Animation) -> bool:
 if a.length!=b.length or a.loop_mode!=b.loop_mode or a.get_track_count()!=b.get_track_count():return false
 for key in a.get_meta_list():
  if a.get_meta(key)!=b.get_meta(key):return false
 for track in a.get_track_count():
  if a.track_get_type(track)!=b.track_get_type(track) or a.track_get_path(track)!=b.track_get_path(track) or a.track_get_key_count(track)!=b.track_get_key_count(track):return false
  if a.track_get_interpolation_type(track)!=b.track_get_interpolation_type(track) or a.track_get_interpolation_loop_wrap(track)!=b.track_get_interpolation_loop_wrap(track):return false
  for key in a.track_get_key_count(track):
   if a.track_get_key_time(track,key)!=b.track_get_key_time(track,key) or a.track_get_key_value(track,key)!=b.track_get_key_value(track,key) or a.track_get_key_transition(track,key)!=b.track_get_key_transition(track,key):return false
 return true
func pose(actor:Node3D,clip:String,time:float) -> Array[Transform3D]:
 actor.player.play(StringName("aren/"+clip));actor.player.seek(time,true)
 var skeleton:Skeleton3D=actor.get_node(actor.model_path).find_children("*","Skeleton3D",true,false)[0]
 skeleton.force_update_all_bone_transforms()
 var result:Array[Transform3D]=[]
 for bone in skeleton.get_bone_count():result.append(skeleton.get_bone_global_pose(bone))
 return result
func run():
 var old:Node3D=load(BASE).instantiate();root.add_child(old);old.set_process(false);old.tree.active=false
 var revised:Node3D=load(REVISED).instantiate();root.add_child(revised);revised.set_process(false);revised.tree.active=false
 check(equal_clip(old.library.get_animation(&"walk"),revised.library.get_animation(&"walk")),"Approved walk keys, clock or metadata changed")
 var before:Animation=old.library.get_animation(&"run");var after:Animation=revised.library.get_animation(&"run")
 check(is_equal_approx(after.length,before.length/.9),"Run cadence not reduced ten percent")
 check(is_equal_approx(before.get_meta("cycle").speed_mps,after.get_meta("cycle").speed_mps),"Run displacement speed changed")
 check(is_equal_approx(after.get_meta("cycle").distance_m/after.length,before.get_meta("cycle").speed_mps),"Run stride does not match its clock")
 check(is_equal_approx(after.get_meta("cycle").support*after.length,before.get_meta("cycle").support*before.length),"Run support duration changed")
 check(not equal_clip(before,after),"Run poses were not replaced")
 for path in after.get_meta("source_hashes"):
  check(FileAccess.get_sha256(path)==after.get_meta("source_hashes")[path],"Stale generated source: "+path)
 var idle:Animation=revised.library.get_animation(&"idle")
 check(is_equal_approx(idle.length,4.5),"Idle breathing must last 4.5 seconds")
 var skeleton:Skeleton3D=revised.get_node(revised.model_path).find_children("*","Skeleton3D",true,false)[0]
 var hips:=skeleton.find_bone("smartrig_Hips");var chest:=skeleton.find_bone("smartrig_Spine2")
 var abdomen:=skeleton.find_bone("smartrig_Spine");var shoulder:=skeleton.find_bone("smartrig_RightShoulder")
 var first:=pose(revised,"idle",0);var chest_span:=0.0;var abdomen_span:=0.0;var shoulder_span:=0.0
 var maximum_balance:=0.0;var foot_motion:=0.0
 for frame in 121:
  var values:=pose(revised,"idle",frame/120.0*idle.length)
  check(absf(values[hips].origin.y-first[hips].origin.y)<.001,"Idle pelvis bobs vertically")
  maximum_balance=maxf(maximum_balance,(skeleton.global_transform.basis*(values[hips].origin-first[hips].origin)).length())
  chest_span=maxf(chest_span,values[chest].basis.get_rotation_quaternion().angle_to(first[chest].basis.get_rotation_quaternion()))
  abdomen_span=maxf(abdomen_span,values[abdomen].basis.get_rotation_quaternion().angle_to(first[abdomen].basis.get_rotation_quaternion()))
  shoulder_span=maxf(shoulder_span,values[shoulder].basis.get_rotation_quaternion().angle_to(first[shoulder].basis.get_rotation_quaternion()))
  for side in ["Right","Left"]:
   var foot:=skeleton.find_bone("smartrig_"+side+"Foot")
   foot_motion=maxf(foot_motion,(skeleton.global_transform.basis*(values[foot].origin-first[foot].origin)).length())
 check(chest_span>deg_to_rad(.3) and chest_span>abdomen_span*3,"Breathing is not concentrated in chest")
 check(shoulder_span>0 and shoulder_span<deg_to_rad(1),"Shoulder breathing missing or exaggerated")
 check(maximum_balance<.002 and maximum_balance>.0005,"Idle balance excessive or absent")
 check(foot_motion<.0005,"Idle feet drift")
 # Validate seam and short-time angular continuity in every actual native bone.
 for clip in ["run","idle"]:
  var animation:Animation=revised.library.get_animation(StringName(clip))
  var seam:=pose(revised,clip,0)
  var end:=pose(revised,clip,animation.length)
  var previous:=pose(revised,clip,animation.length-animation.length/480)
  var max_step:=0.0
  for frame in 480:
   var values:=pose(revised,clip,frame/480.0*animation.length)
   for bone in values.size():
    max_step=maxf(max_step,values[bone].basis.get_rotation_quaternion().angle_to(previous[bone].basis.get_rotation_quaternion()))
    if frame==0:
     check(seam[bone].origin.distance_to(end[bone].origin)<.002,"Loop position seam: "+clip)
     check(seam[bone].basis.get_rotation_quaternion().angle_to(end[bone].basis.get_rotation_quaternion())<.002,"Loop angular seam: "+clip)
   previous=values
  print(clip," maximum 1/480-cycle angular step deg=",rad_to_deg(max_step))
  check(max_step<deg_to_rad(8),"Abrupt joint change in "+clip)
 # The tree must retain slow idle breathing, not compress it to a one-second gait.
 var space:AnimationNodeBlendSpace1D=revised.tree.tree_root.get_node(&"Gait")
 check(is_equal_approx(space.get_blend_point_node(0).timeline_length,4.5),"AnimationTree compresses idle breathing")
 revised.tree.active=true;revised.tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 revised.blend=0;revised.set_locomotion(0);revised._process(0);revised.tree.advance(0)
 revised.tree.advance(idle.length*.25)
 var from_tree:Transform3D=skeleton.get_bone_pose(chest)
 revised.tree.active=false;pose(revised,"idle",idle.length*.25)
 check(from_tree.origin.distance_to(skeleton.get_bone_pose(chest).origin)<.002 and from_tree.basis.get_rotation_quaternion().angle_to(skeleton.get_bone_pose(chest).basis.get_rotation_quaternion())<.002,"AnimationTree idle differs from slow baked clip")
 print("idle balance_m=",maximum_balance," feet_motion_m=",foot_motion," chest_breath_deg=",rad_to_deg(chest_span))
 old.free();revised.free()
 if failures.is_empty():print("PASS: run/idle poses, speed, loops, idle playback and exact approved walk preservation")
 quit(0 if failures.is_empty() else 1)
