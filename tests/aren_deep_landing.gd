extends SceneTree
const Motion=preload("res://scripts/animation/authoring/aren_landing_motion.gd")
var failures:Array[String]=[]
var checks:=0
var scenario:=""
var maximum_pose:=0.0
var worst_pose:=""
func _initialize():call_deferred("run")
func check(value:bool,message:String) -> void:
 checks+=1
 var label:=scenario+": "+message
 if not value and label not in failures:failures.append(label);push_error(label)
func run() -> void:
 var actor=load("res://scenes/prototype_3d/aren_landing_review_actor.tscn").instantiate();root.add_child(actor);actor.set_process(false)
 for style in ["normal","cautious","tired"]:
  actor.set_style(style)
  for height in [3.0,3.5,4.8,6.0,7.9]:
   actor.review_height=height
   for gait in ["idle_to_fall","walk_to_fall","run_to_fall"]:
    scenario=style+"/"+str(height)+"/"+gait
    actor.begin_preview(gait)
    var seen:=false;var support_frames:=0;var elbow_low:=180.0;var elbow_high:=0.0
    var previous:Array[Transform3D]=[];var old_stage:=""
    for frame in 900:
     actor.advance_jump_preview(1.0/120)
     var native=actor.native
     for bone in native.parents.size():
      check(native.posed[bone].is_finite(),"nonfinite pose")
      var pose:Transform3D=native.skeleton.get_bone_pose(bone)
      if previous.size()>bone and actor.preview_stage=="landing":
       var angle:=rad_to_deg(previous[bone].basis.get_rotation_quaternion().angle_to(pose.basis.get_rotation_quaternion()))
       check(angle<25,"pose discontinuity "+native.skeleton.get_bone_name(bone))
       if angle>maximum_pose:maximum_pose=angle;worst_pose=scenario+" "+old_stage+"->"+actor.preview_stage+" "+native.skeleton.get_bone_name(bone)+" t"+str(actor.stage_time)
      if previous.size()<=bone:previous.append(pose)
      else:previous[bone]=pose
     old_stage=actor.preview_stage
     if actor.preview_stage=="landing":
      seen=true
      check(actor.landing.foot_error<.001,"foot IK target unreachable")
      for side in 2:
       var leg:Dictionary=native.legs[side];var ids:Array=leg.ids
       var hip:Vector3=native.posed[ids[0]].origin;var knee:Vector3=native.posed[ids[1]].origin;var ankle:Vector3=native.posed[ids[2]].origin
       check(absf(hip.distance_to(knee)-leg.a)*actor.SCALE<.00005,"thigh length")
       check(absf(knee.distance_to(ankle)-leg.b)*actor.SCALE<.00005,"shin length")
       check(rad_to_deg((knee-hip).angle_to(ankle-knee))<151,"excessive knee flexion")
       if frame%4==0:
        var low:=INF
        for point in actor.landing.sole_support.world_skin_points(native,side,actor.global_transform):low=minf(low,point.y-actor.floor_y)
        check(low>=-.001,"sole penetration")
       if side==1 and actor.stage_time<actor.landing.parameters.rise_end-.04:
        var foot:Vector3=actor.global_transform*native.posed[ids[2]].origin
        var anchor:Vector3=actor.landing.feet[side].origin
        check(Vector2(foot.x-anchor.x,foot.z-anchor.z).length()<.001,"planted foot slid")
      if frame%6==0:check(actor.landing.knee_gap(actor,true)>=-.002,"right knee/shin penetration")
      if actor.landing.support_loaded:
       var knee:Vector3=actor.global_transform*native.posed[native.legs[0].ids[1]].origin
       check(Vector2(knee.x-actor.landing.knee_anchor.x,knee.z-actor.landing.knee_anchor.z).length()<.001,"right knee slid")
       check(actor.landing.knee_minimum>=.03 and actor.landing.knee_minimum<=.05,"right knee clearance outside 3–5 cm")
       check(not actor.landing.knee_planted,"right knee incorrectly bears weight")
       var rear_low:=INF
       for point in actor.landing.sole_support.world_skin_points(native,0,actor.global_transform):rear_low=minf(rear_low,point.y-actor.floor_y)
       check(absf(rear_low)<.002,"rear forefoot lost support")
       var left_knee:Vector3=native.posed[native.legs[1].ids[1]].origin
       var left_hip:Vector3=native.posed[native.legs[1].ids[0]].origin
       var heading:=absf(rad_to_deg(atan2(left_knee.x-left_hip.x,left_knee.z-left_hip.z)))
       check(heading<30,"left knee points sideways")
       var left_ankle:Vector3=native.posed[native.legs[1].ids[2]].origin
       check(absf(left_knee.x-left_ankle.x)*actor.SCALE<.06,"left knee not aligned over supporting foot")
       var ankle:Vector3=actor.global_transform*native.posed[native.legs[0].ids[2]].origin
       check(ankle.z<knee.z-.25,"right shin did not trail behind knee")
      for bone in actor.landing.finger_bones:
       var parent:int=native.parents[bone]
       var actual:float=native.posed[parent].origin.distance_to(native.posed[bone].origin)
       var expected:float=native.rest[parent].origin.distance_to(native.rest[bone].origin)*native.grip.HAND_SCALE
       check(absf(actual-expected)*actor.SCALE<.00005,"finger length")
      for arm in native.arms:
       var ids:Array=arm.ids
       check(absf(native.posed[ids[1]].origin.distance_to(native.posed[ids[2]].origin)-arm.a)*actor.SCALE<.00005,"humerus length")
       check(absf(native.posed[ids[2]].origin.distance_to(native.posed[ids[3]].origin)-arm.b)*actor.SCALE<.00005,"forearm length")
      if actor.landing.palm_planted:
       support_frames+=1
       elbow_low=minf(elbow_low,actor.landing.elbow_degrees);elbow_high=maxf(elbow_high,actor.landing.elbow_degrees)
       check(actor.landing.elbow_degrees>18,"support elbow nearly locked")
       check(actor.landing.elbow_degrees<100,"excessive support elbow flexion")
       check(actor.landing.palm_error<.001,"palm IK target unreachable")
       check(absf(actor.landing.palm_minimum)<.001,"actual palm skin left plane")
       if frame%6==0:
        var hand_low:=INF
        for point in actor.landing.skin_points(actor,true):hand_low=minf(hand_low,point.y-actor.floor_y)
        check(hand_low>=-.002,"finger/thenar penetration")
     if actor.preview_done:break
    check(seen and support_frames>20,"no sustained palm reception")
    check(elbow_high-elbow_low>3,"support elbow held constant")
    check(actor.preview_done,"recovery did not complete")
    print("CASE ",scenario," elbow ",elbow_low,"..",elbow_high)
 print("DEEP LANDING ",checks," checks; pose peak ",maximum_pose," ",worst_pose," failures ",failures)
 actor.free();quit(0 if failures.is_empty() else 1)
