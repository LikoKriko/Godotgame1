extends SceneTree
const Clips=preload("res://scripts/prototype_3d/survivor_animation.gd")
const Source=preload("res://scripts/continuous_body_pose.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 require(absf(Clips.duration(&"walk")-0.78)<0.00001 and absf(Clips.duration(&"run")-0.585)<0.00001,"Walk/run cadence is 30 percent longer without changing travel speed")
 for state in [&"walk",&"run"]:
  for frame in 48:
   var t:=frame/48.0;var baseline:Dictionary=Source.sample(&"",state,t)
   var pose:Dictionary=Clips.sample(&"",state,t,t,Vector3.BACK)
   for side in 2:
    require(absf(pose.legs[side].end.z-baseline.legs[side].end.z*1.3)<0.01,"Visible foot travel really gains 30 percent instead of being shortened by IK")
    require(absf(pose.legs[side].root.distance_to(pose.legs[side].joint)-preload("res://scripts/prototype_3d/survivor_anatomy.gd").THIGH)<0.001 and absf(pose.legs[side].joint.distance_to(pose.legs[side].end)-preload("res://scripts/prototype_3d/survivor_anatomy.gd").THIGH)<0.001,"Longer stride preserves thigh and shin lengths")
    require(absf(pose.legs[side].end.y-baseline.legs[side].end.y)<0.01,"Stride adjustment preserves the support/lift curve")
   if state==&"walk":
    var hand:Vector3=pose.body.affine_inverse()*pose.hands[0]
    var old_hand:Vector3=baseline.body.affine_inverse()*baseline.hands[0]
    require(absf((hand.z-3.5*0.82)-(old_hand.z-3.5)*0.82*0.9)<0.001,"Free walking arms swing ten percent less around the same resting depth")
   else:
    var arm:Dictionary=Clips.running_arm(pose,0,t)
    var upper:Vector3=pose.body.basis.inverse()*(arm.joint-arm.root).normalized()
    require(absf(rad_to_deg(atan2(upper.z,-upper.y)))<=16.201,"Running arms reduce their shoulder swing from 18 to 16.2 degrees")
    require(absf(rad_to_deg((arm.root-arm.joint).angle_to(arm.end-arm.joint))-75)<0.01,"Running elbows retain their approved 75 degrees")
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();game.use_test_layout=true;root.add_child(game);game.paused=true;game.player.set_physics_process(false);game.set_physics_process(false)
 game.player.position=Vector3(10,0,10)
 await physics_frame
 var rig=game.camera_rig
 rig.look(Vector2(0,1e6));require(absf(rig.pitch+PI/2)<0.00001,"Downward aim reaches a full 90 degrees")
 rig.update(1);require((-rig.camera.global_basis.z).dot(Vector3.DOWN)>0.9999,"Reticle direction actually points straight down")
 require(not rig.target().is_empty() and absf(rig.target().position.y)<0.01,"Full downward reticle reaches the ground")
 rig.look(Vector2(0,-2e6));require(absf(rig.pitch-PI/2)<0.00001,"Upward aim reaches a full 90 degrees")
 for degrees in [65,85,90]:
  rig.pitch=deg_to_rad(degrees);rig.update(1)
  var fixed:Vector3=rig.camera.global_position
  for frame in 60:
   rig.update(1.0/60)
   require(rig.camera.global_position.distance_to(fixed)<0.00001,"Stationary upward camera cannot oscillate between safe and underground positions")
   require(rig.camera.global_position.y>=0.175,"Boom collision keeps the upward camera above the ground")
 rig.pitch=0;rig.yaw=0;game.player.position=Vector3(-6.55,0,-2)
 await physics_frame
 rig.update(1);require(rig.actual_distance<rig.DISTANCE,"Wall still retracts the camera")
 game.player.position=Vector3(10,0,10)
 await physics_frame
 var previous:float=rig.actual_distance
 for frame in 30:
  rig.update(1.0/60);require(rig.actual_distance>=previous and rig.actual_distance<=rig.DISTANCE,"Camera recovers smoothly after leaving an obstruction");previous=rig.actual_distance
 game.free();print("%s: %d stride, arm rhythm and pole-camera checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
