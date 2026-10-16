extends SceneTree
const Pose = preload("res://scripts/continuous_body_pose.gd")
var checks := 0
var failures := 0
func require(ok: bool,message: String):
 checks += 1
 if not ok: failures += 1; push_error(message)
func _initialize():
 for frame in 17:
  var phase := frame/16.0
  var reference := Pose.sample(&"sword",&"action",phase,0.2,1,6)
  var lateral := Pose.sample(&"sword",&"action",phase,0.2,1,8)
  require(reference.grip.is_equal_approx(lateral.grip) and reference.shaft.is_equal_approx(lateral.shaft),"Accepted left and down-left actor-space trajectories are preserved")
  for direction in 16:
   var pose := Pose.sample(&"sword",&"action",phase,0.2,1,direction)
   require(pose.grip.is_finite() and pose.shaft.is_normalized(),"Every view has a finite grip and continuous unit strike axis")
   var previous := Pose.sample(&"sword",&"action",maxf(0,phase-0.001),0.2,1,direction)
   require(pose.grip.distance_to(previous.grip) < 0.35 and pose.shaft.distance_to(previous.shaft) < 0.1,"Gesture has no isolated flips between authored frames")
   if direction not in [6,7,8]:
    var local_grip: Vector3 = pose.body.affine_inverse()*pose.grip
    require(local_grip.z >= 6.9,"Problematic views keep the gripping hand in front of the torso")
 require(is_equal_approx(preload("res://scripts/action_motion.gd").DURATION[&"sword"],0.62*1.35),"Sword retains frames with thirty-five percent longer duration")
 print("%s: %d sword gesture checks" % ["PASS" if failures == 0 else "FAIL",checks]); quit(1 if failures else 0)
