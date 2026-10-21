extends SceneTree
## Real controller/collisions: ground regressions live in aren_locomotion_integration.
const Support=preload("res://scripts/animation/terrain/terrain_foot_support.gd")
const Fall=preload("res://scripts/animation/authoring/aren_fall_motion.gd")
var failures:Array[String]=[]
var checks:=0
var foot_support=Support.new()
var contact_frame:=100
var scene:Node3D
var case_name:=""
var worst_pose:=0.0
var worst_contact:=0.0
var worst_case:=""
var previous:Array[Transform3D]=[]
var previous_stage:=""
func _initialize():call_deferred("run")
func check(value:bool,message:String) -> void:
 checks+=1
 var text:=case_name+": "+message
 if not value and text not in failures:failures.append(text);push_error(text)
func step() -> void:
 await physics_frame
 scene._physics_process(1.0/60)
 var actor=scene.actor
 if previous_stage in ["flight","fall"] and scene.motion.air.stage=="grounded":contact_frame=0
 else:contact_frame+=1
 if contact_frame in [0,5,15,30] and not case_name.begins_with("terrain jump"):
  var lowest:=INF
  for side in 2:
   for point in foot_support.world_skin_points(actor.native,side,actor.global_transform):lowest=minf(lowest,point.y)
  check(lowest>=-.006,"sole penetrated physical floor")
 for pose in actor.native.posed:check(pose.is_finite(),"nonfinite pose")
 for side in 2:
  var leg:Dictionary=actor.native.legs[side];var ids:Array=leg.ids
  var a:Vector3=actor.native.posed[ids[0]].origin;var b:Vector3=actor.native.posed[ids[1]].origin;var c:Vector3=actor.native.posed[ids[2]].origin
  check(absf(a.distance_to(b)-leg.a)*actor.SCALE<.0001,"thigh length")
  check(absf(b.distance_to(c)-leg.b)*actor.SCALE<.0001,"shin length")
 if not previous.is_empty():
  for bone in actor.native.parents.size():
   var parent:int=actor.native.parents[bone]
   var old_local:Transform3D=previous[parent].affine_inverse()*previous[bone] if parent>=0 else previous[bone]
   var new_local:Transform3D=actor.native.posed[parent].affine_inverse()*actor.native.posed[bone] if parent>=0 else actor.native.posed[bone]
   var angle:float=rad_to_deg(old_local.basis.orthonormalized().get_rotation_quaternion().angle_to(new_local.basis.orthonormalized().get_rotation_quaternion()))
   if angle>worst_pose:worst_case=case_name+" "+previous_stage+" -> "+scene.motion.air.stage+" bone "+str(bone)
   worst_pose=maxf(worst_pose,angle)
   if previous_stage in ["flight","fall"] and scene.motion.air.stage=="grounded":
    worst_contact=maxf(worst_contact,angle)
    check(angle<20,"contact pose discontinuity bone "+str(bone)+" angle "+str(angle))
 previous=actor.native.posed.duplicate();previous_stage=scene.motion.air.stage
func reset(at:Vector3,style:String,gait:String) -> void:
 previous.clear();contact_frame=100;scene.actor.change_style(style);scene.reset_at(at)
 scene.test_input=Vector2.ZERO;scene.test_run=gait=="run"
 for tick in 45:await step()
 check(scene.body.is_on_floor(),"initial contact")
 scene.test_input=Vector2.ZERO if gait=="idle" else Vector2(0,-1)
func run() -> void:
 scene=load("res://scenes/prototype_3d/aren_terrain_test.tscn").instantiate()
 root.add_child(scene);scene.automated=true;scene.set_physics_process(false)
 foot_support.configure(scene.actor.native)
 for index in 3:
  var h:float=[.55,1.5,3.0][index]
  check(is_equal_approx(Fall.recovery_scale(h),[1.1,1.2,1.3][index]),"relative compression scale")
  check(is_equal_approx(Fall.recovery_duration(h),.34*[1.1,1.2,1.3][index]),"relative recovery duration")
 for style in ["normal","cautious","tired"]:
  for gait in ["idle","walk","run"]:
   case_name="jump/"+style+"/"+gait
   await reset(Vector3(0,.01,40),style,gait)
   for tick in 90:await step()
   scene.motion.jump_requested=true
   var peak:float=scene.body.position.y;var initial_y:float=peak;var speed:=0.0
   for tick in 180:
    await step();peak=maxf(peak,scene.body.position.y)
    if scene.motion.air.stage=="flight":
     check(scene.motion.air.detection.mode=="voluntary","voluntary classification")
     if speed==0:speed=Vector2(scene.body.velocity.x,scene.body.velocity.z).length()
   check(scene.motion.air.launches==1 and scene.motion.air.contacts==1,"full jump cycle")
   check(scene.motion.air.falls==0,"jump falsely fell")
   check(peak-initial_y>.65 and peak-initial_y<.82,"ballistic height")
   check(scene.body.is_on_floor(),"jump recovered contact")
   print("PASS ",case_name)
  for index in 4:
   for gait in ["walk","run"]:
    var h:float=Fall.HEIGHTS[index]
    case_name="fall/"+style+"/"+gait+"/"+str(h)
    # 70 cm before the edge lets the physical body accelerate first.
    await reset(Vector3(-24+index*6,h+.01,25.2),style,gait)
    for tick in 270:await step()
    check(scene.motion.air.falls==1,"one automatic fall")
    check(scene.motion.air.launches==0,"fall triggered launch")
    check(scene.motion.air.contacts==1,"fall recovered contact")
    check(scene.motion.air.landing_height>h-.12 and scene.motion.air.landing_height<h+.02,"physical drop height")
    if h==8:check(scene.motion.air.landing_pending,"8 m collapse pending")
    check(scene.body.is_on_floor(),"fall grounded")
    if h<=3:check(absf(scene.motion.air.impact_scale-Fall.recovery_scale(h))<.002,"height-based absorption")
    print("PASS ",case_name)
 # Idle loss of support: remove the actual platform, retaining the idle pose.
 for style in ["normal","cautious","tired"]:
  case_name="idle fall/"+style
  await reset(Vector3(-18,1.51,28),style,"idle")
  var platform:CollisionShape3D
  for child in scene.get_children():
   if child is StaticBody3D and child.position.is_equal_approx(Vector3(-18,.75,28)):platform=child.get_child(0)
  check(platform!=null,"idle platform fixture")
  platform.set_deferred("disabled",true)
  for tick in 150:await step()
  check(scene.motion.air.falls==1 and scene.motion.air.launches==0,"idle support removal")
  check(scene.motion.air.contacts==1 and scene.body.is_on_floor(),"idle fall recovery")
  platform.set_deferred("disabled",false)
  print("PASS ",case_name)
 # Six entry/exit links with intent changing while airborne.
 for style in ["normal","cautious","tired"]:
  for link in [["idle","walk"],["walk","run"],["run","idle"]]:
   case_name="jump transition/"+style+"/"+link[0]+"->"+link[1]
   await reset(Vector3(0,.01,40),style,link[0])
   for tick in 75:await step()
   scene.motion.jump_requested=true
   while scene.motion.air.stage!="flight":await step()
   scene.test_input=Vector2.ZERO if link[1]=="idle" else Vector2(0,-1)
   scene.test_run=link[1]=="run"
   while scene.motion.air.stage=="flight":await step()
   var contact_speed:=Vector2(scene.body.velocity.x,scene.body.velocity.z)
   await step()
   check(Vector2(scene.body.velocity.x,scene.body.velocity.z).distance_to(contact_speed)<.35,"instant horizontal landing reset")
   for tick in 100:await step()
   check(scene.motion.requested_gait==link[1],"wrong exit gait")
   check(scene.motion.air.contacts==1 and scene.motion.air.falls==0,"transition jump classification")
   print("PASS ",case_name)
 # Existing irregular patches and slope, using their actual collider/IK.
 for style in ["normal","cautious","tired"]:
  for terrain in ["slope","dirt","forest"]:
   case_name="terrain jump/"+style+"/"+terrain
   var at:Vector3={"slope":Vector3(0,1.2,-6),"dirt":Vector3(-17,.8,-6),"forest":Vector3(19,1.2,-8)}[terrain]
   await reset(at,style,"idle")
   for tick in 60:await step()
   var baseline_falls:int=scene.motion.air.falls
   scene.test_input=Vector2(0,-1)
   scene.motion.jump_requested=true
   for tick in 210:await step()
   check(scene.motion.air.launches==1,"terrain jump launch")
   check(scene.motion.air.falls==baseline_falls,"terrain jump false fall")
   check(scene.body.is_on_floor(),"terrain jump contact")
   print("PASS ",case_name)
 # Control in flight, input release conserves horizontal momentum.
 case_name="air control"
 await reset(Vector3(0,.01,40),"normal","run")
 for tick in 90:await step()
 scene.motion.jump_requested=true
 while scene.motion.air.stage!="flight":await step()
 var velocity:=Vector2(scene.body.velocity.x,scene.body.velocity.z)
 scene.test_input=Vector2.ZERO
 for tick in 8:
  await step()
  check(Vector2(scene.body.velocity.x,scene.body.velocity.z).distance_to(velocity)<.001,"released input lost momentum")
 scene.test_input=Vector2(1,0)
 for tick in 8:
  var before:=Vector2(scene.body.velocity.x,scene.body.velocity.z)
  await step()
  check(Vector2(scene.body.velocity.x,scene.body.velocity.z).distance_to(before)<=2.5/60+.001,"air steering acceleration")
 check(scene.body.velocity.x>0,"air steering ineffective")
 print("Air integration ",checks," checks; contact peak ",worst_contact," deg; overall peak ",worst_pose," deg (",worst_case,"); failures ",failures)
 scene.free();quit(0 if failures.is_empty() else 1)
