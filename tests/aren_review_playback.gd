extends SceneTree
## Review-only optimization must reproduce the unchanged actor at every frame.
var checks:=0
var failures:Array[String]=[]
func _initialize():call_deferred("run")
func check(ok:bool,message:String) -> void:
 checks+=1
 if not ok and message not in failures:failures.append(message);push_error(message)
func compare(review:Control,reference:Node3D) -> void:
 var lead=review.actors[0]
 check(is_equal_approx(lead.distance_m,reference.distance_m),"Displacement changed")
 check(is_equal_approx(lead.phase,reference.phase),"Support phase changed")
 check(is_equal_approx(lead.current_speed,reference.current_speed),"Acceleration changed")
 for view in review.actors.size():
  var actor=review.actors[view]
  check(actor.position.is_equal_approx(lead.position),"Views disagree on displacement")
  for bone in reference.native.skeleton.get_bone_count():
   check(actor.native.skeleton.get_bone_pose(bone).is_equal_approx(reference.native.skeleton.get_bone_pose(bone)),"Displayed bone pose differs, view %d bone %d"%[view,bone])
  for shape in reference.native.mesh.mesh.get_blend_shape_count():
   check(is_equal_approx(actor.native.mesh.get_blend_shape_value(shape),reference.native.mesh.get_blend_shape_value(shape)),"Displayed morph differs")
func run() -> void:
 var review=load("res://scenes/prototype_3d/aren_authoring_review.tscn").instantiate()
 root.add_child(review);review.set_process(false)
 for source in [7,12]:
  review.select_source(source)
  var reference:Node3D=load(review.sources[source].path).instantiate()
  root.add_child(reference);reference.set_process(false)
  for state in 3:
   review.select_state(state);reference.set_style(["normal","cautious","tired"][state])
   for fps in [30,60,120]:
    var dt:float=1.0/fps
    # All six complete transitions, including their settled support state.
    for name in review.CHAIN:
     review.select_motion(review.MOTIONS.find(name))
     reference.reset_motion(reference.profile.recipes[name].from);reference.request_transition(name)
     var follower_clock:float=review.actors[1].clock
     for frame in ceili((review.actors[0].transition_duration+.15)*fps):
      review.process_transitions(dt);reference.advance_transition(dt);compare(review,reference)
     check(review.actors[1].clock==follower_clock,"Follower redundantly advanced simulation")
    # Independently reproduce the original scheduler, including .45 s holds.
    review.select_motion(3);reference.reset_motion("idle");reference.request_transition(review.CHAIN[0])
    var wait:=0.0;var index:=0;var visited:Dictionary={0:true}
    for frame in ceili(19.0*fps):
     if reference.recipe.is_empty():
      wait+=dt
      if wait>=.45:
       wait=0;index=(index+1)%review.CHAIN.size();visited[index]=true
       reference.request_transition(review.CHAIN[index])
     review.process_transitions(dt);reference.advance_transition(dt);compare(review,reference)
    check(visited.size()==6,"Chain did not exercise every link")
    # Interrupt acceleration, braking, and recovery before they finish.
    review.select_motion(5);reference.reset_motion("idle");reference.request_transition("idle_to_run")
    for item in [["",.55],["run_to_walk",.18],["walk_to_idle",.22],["idle_to_run",.37],["run_to_idle",.24],["idle_to_walk",.32],["walk_to_run",2.8]]:
     if not item[0].is_empty():
      review.actors[0].request_transition(item[0]);reference.request_transition(item[0])
     for frame in ceili(float(item[1])*fps):
      review.process_transitions(dt);reference.advance_transition(dt);compare(review,reference)
    # Cycle playback also uses one pose, including legacy AnimationPlayer seek.
    for clip in ["idle","walk","run"]:
     for seconds in [0.0,.173,.57,1.21]:
      review.show_frame(clip,seconds)
      var duration:float=reference.library.get_animation(StringName(clip)).length
      if reference.has_method("seek_cycle"):reference.seek_cycle(clip,fposmod(seconds,duration))
      else:
       reference.player.play(StringName("aren/"+clip));reference.player.seek(fposmod(seconds,duration),true);reference.player.pause()
      # Cycle seek does not integrate either actor's transition clock.
      reference.distance_m=review.actors[0].distance_m;reference.phase=review.actors[0].phase;reference.current_speed=review.actors[0].current_speed
      compare(review,reference)
    print("PASS review: source=",source," state=",state," fps=",fps)
  reference.free()
 review.free()
 print("Review checks: ",checks," failures: ",failures.size())
 quit(0 if failures.is_empty() else 1)
