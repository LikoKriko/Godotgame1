extends "res://tests/aren_air_integration.gd"
## Physical support loss must animate before the fall classifier confirms it.
var pose_times:Array[float]=[]
var frozen_ticks:=0
var entry_peak:=0.0
func body_delta(a:Dictionary,b:Dictionary) -> float:
 var result:=0.0
 for id in scene.actor.native.spine+scene.actor.native.arms[0].ids+scene.actor.native.arms[1].ids:
  var old:Basis=a.poses[id].basis;var current:Basis=b.poses[id].basis
  result=maxf(result,maxf(old.x.distance_to(current.x),maxf(old.y.distance_to(current.y),old.z.distance_to(current.z))))
 return result
func run() -> void:
 Engine.physics_ticks_per_second=240
 scene=load("res://scenes/prototype_3d/aren_terrain_test.tscn").instantiate()
 root.add_child(scene);scene.automated=true;scene.set_physics_process(false)
 foot_support.configure(scene.actor.native)
 var prepared_landing=scene.motion.air.landing
 check(prepared_landing.playback_ready,"contact cache prepared during scene load")
 var short_run:bool="--probe" in OS.get_cmdline_user_args()
 for height in ([3.0] if short_run else [3.0,7.0]):
  for style in (["normal"] if short_run else ["normal","cautious","tired"]):
   for gait in (["walk"] if short_run else ["idle","walk","run"]):
    case_name="entry/"+str(height)+"/"+style+"/"+gait
    var key:=InputEventKey.new();key.pressed=true;key.keycode=KEY_8 if height==3 else KEY_0
    scene._unhandled_input(key)
    await reset(scene.body.position,style,"idle")
    check(scene.motion.air.landing==prepared_landing,"platform/reset reuses contact cache")
    var collider:CollisionShape3D
    if gait=="idle":
     var ray:=PhysicsRayQueryParameters3D.create(scene.body.position+Vector3.UP*.2,scene.body.position-Vector3.UP*.3,1,[scene.body.get_rid()])
     var hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(ray)
     check(not hit.is_empty(),"idle fixture has real support")
     collider=hit.collider.get_child(0);collider.set_deferred("disabled",true)
    scene.test_input=Vector2.ZERO if gait=="idle" else Vector2(0,-1);scene.test_run=gait=="run"
    var saw_air:=false;var saw_landing:=false;var saw_palm:=false;var unsupported_ticks:=0
    var before_pose:Dictionary=scene.actor.capture_pose()
    for tick in 500:
     var old_velocity:Vector3=scene.body.velocity;var old_heading:float=scene.actor.rotation.y
     var old_y:float=scene.body.position.y
     await step();pose_times.append(scene.pose_ms)
     var air=scene.motion.air;var current:Dictionary=scene.actor.capture_pose()
     if air.stage in ["unsupported","fall"]:
      if not saw_air:
       print(case_name," first unsupported pose ",scene.pose_ms," ms")
       check(air.landing.playback_ready,"first airborne tick never builds contact samples")
       check(body_delta(before_pose,current)>.00001,"body reacts on first unsupported physics tick")
       check(scene.body.position.y<old_y,"physical descent begins without delay")
       check(absf(wrapf(scene.actor.rotation.y-old_heading,-PI,PI))<.001,"entry heading retained")
       check(Vector2(scene.body.velocity.x,scene.body.velocity.z).distance_to(Vector2(old_velocity.x,old_velocity.z))<.1,"entry momentum retained")
      saw_air=true
      if air.air_time<=.30:
       var delta:=body_delta(before_pose,current)
       if delta<=.00001:frozen_ticks+=1
       check(delta>.00001,"no frozen upper-body ticks during release")
       entry_peak=maxf(entry_peak,delta)
       check(delta<.30,"continuous upper body release")
      if air.stage=="unsupported":unsupported_ticks+=1
     if air.landing.active:saw_landing=true;saw_palm=saw_palm or air.landing.palm_planted
     if saw_air and air.contacts>0:
      check(scene.body.is_on_floor(),"landing begins at physical contact")
      if not air.landing.active and air.recovery_clock>=air.recovery_duration:break
     before_pose=current
    check(saw_air and saw_landing and saw_palm,"fall and approved Blender contacts complete")
    check(unsupported_ticks>0,"classifier grace retained independently of visual release")
    check(scene.motion.air.falls==1 and scene.motion.air.contacts==1,"single classified fall/contact")
    if is_instance_valid(collider):collider.set_deferred("disabled",false)
    print(case_name," unsupported ",unsupported_ticks," ticks; duration ",scene.motion.air.recovery_duration)
 pose_times.sort()
 print("FALL ENTRY ",checks," checks; frozen ticks ",frozen_ticks," upper body basis step ",entry_peak," contact degrees ",worst_contact," pose p95 ",pose_times[int(pose_times.size()*.95)]," ms; max ",pose_times.back()," ms; failures ",failures)
 scene.free();quit(0 if failures.is_empty() else 1)
