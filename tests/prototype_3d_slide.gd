extends SceneTree
const Clips=preload("res://scripts/prototype_3d/survivor_animation.gd")
const Motion=preload("res://scripts/locomotion.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func angle(leg:Dictionary) -> float:return rad_to_deg((leg.root-leg.joint).angle_to(leg.end-leg.joint))
func run():
 require(Clips.duration(&"slide")==Motion.SLIDE_SECONDS and Motion.SLIDE_SECONDS==0.46,"Pose keeps the existing 0.46-second slide")
 var middle:=Clips.sample(&"",&"slide",0.5,0.3)
 require(maxf(middle.hips[0].y,middle.hips[1].y)<6,"Slide rests on a low hip rather than a standing squat")
 require(middle.hips[0].y<middle.hips[1].y,"Pelvis rolls toward the supporting hip")
 require(angle(middle.legs[1])>130 and angle(middle.legs[0])>65 and angle(middle.legs[0])<100,"The lead knee stays soft and the folded knee retains a natural bend")
 require(middle.legs[1].end.z-middle.hips[1].z>18,"Leading heel points into slide travel")
 require(middle.legs[0].joint.x<middle.legs[0].root.x-5,"Folded knee opens to the side instead of through the straight leg")
 require(middle.body.basis.get_rotation_quaternion().angle_to(middle.pelvis.basis.get_rotation_quaternion())>.15,"Chest curls relative to pelvis instead of sliding as a rigid plank")
 var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();root.add_child(actor)
 for family in Clips.FAMILIES:
  actor.family_override=family
  for i in 48:
   var phase:=i/47.0;actor.aim_contact=Vector3.INF;actor.animate(&"slide",phase,family!=&"",0,0.3)
   require(actor.grip_error<0.045,"Sliding keeps the occupied palms on the real object")
   for leg in actor.last_pose.legs:
    require(absf(leg.root.distance_to(leg.joint)-preload("res://scripts/prototype_3d/survivor_anatomy.gd").THIGH)<0.001 and absf(leg.joint.distance_to(leg.end)-preload("res://scripts/prototype_3d/survivor_anatomy.gd").THIGH)<0.001,"Folding preserves both leg bones")
    require(leg.end.y>=1.0 and leg.joint.y>=0.5,"Feet and knees stay above the floor")
  for launch_phase in [0.05,0.25,0.55,0.85]:
   var launch:=Clips.sample(family,&"slide",launch_phase,0.3)
   var start:=Clips.sample(family,&"slide_jump",0,0.3,Vector3.ZERO,Vector3.INF,launch)
   require(start.body.is_equal_approx(launch.body),"Jump starts from the exact slide posture, including early/late launches")
   for side in 2:require(start.legs[side].end.distance_to(launch.legs[side].end)<0.001,"Slide jump preserves the take-off foot positions")
 actor.family_override=&"";actor.animate(&"slide",0.3,false,0,0.4)
 var remembered:Transform3D=actor.displayed_pose.body
 actor.animate(&"slide_jump",0,false)
 require(actor.displayed_pose.body.is_equal_approx(remembered),"Runtime jump uses the actual last displayed pose")
 actor.animate(&"run",0.2,false,0,0.2)
 for i in 8:actor.animate(&"slide",i/20.0,false,0.016,0.2)
 var actual_feet:Array[Vector3]=[actor.rig.posed[12].origin,actor.rig.posed[15].origin]
 actor.animate(&"slide_jump",0,false)
 for side in 2:require(actor.rig.posed[12+side*3].origin.distance_to(actual_feet[side])<0.001,"Take-off captures feet after blended IK rather than stale targets")
 var motion:=Motion.new();motion.slide(Vector2.RIGHT);motion.advance(0.1,false)
 var expected:=motion.slide_speed()*motion.SLIDE_JUMP_DISTANCE_FACTOR
 require(motion.jump() and absf(motion.jump_speed-expected)<0.001,"Chained jump keeps actual inertia and the approved distance factor")
 motion.steer_air(Vector2.LEFT,1);require(absf(motion.jump_heading-motion.launch_heading)<=deg_to_rad(70)+0.001,"Air steering remains limited to seventy degrees")
 actor.free();print("%s: %d hip-slide, joint, grip and jump-continuity checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
