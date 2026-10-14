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
  var reference := Pose.sample(&"sword",&"action",phase,0.2,1,0)
  for direction in 16:
   var pose := Pose.sample(&"sword",&"action",phase,0.2,1,direction)
   require(pose.grip.is_equal_approx(reference.grip) and pose.shaft.is_equal_approx(reference.shaft),"Sword grip and strike axis use the same actor-space path at every view angle")
   for side in 2: require(pose.hands[side].is_equal_approx(reference.hands[side]),"Anatomical hands follow the same sword gesture in every direction")
 print("%s: %d shared sword gesture checks" % ["PASS" if failures == 0 else "FAIL",checks]); quit(1 if failures else 0)
