extends "res://tests/aren_air_integration.gd"
## Real collisions, entry momentum, all styles and genuine irregular support.
var pose_times:Array[float]=[]
var deepest_foot:=0.0
var deepest_hand:=0.0
func run() -> void:
 Engine.physics_ticks_per_second=240
 scene=load("res://scenes/prototype_3d/aren_terrain_test.tscn").instantiate()
 root.add_child(scene);scene.automated=true;scene.set_physics_process(false)
 foot_support.configure(scene.actor.native)
 var terrains:Array=["forest"] if "--forest-only" in OS.get_cmdline_user_args() else ["flat","dirt"]
 for terrain in terrains:
  var heights:Array={"flat":[3.0,5.5,7.9],"dirt":[3.2,5.2,7.5],"forest":[3.8]}[terrain]
  for height in heights:
   for style in ["normal","cautious","tired"]:
    for gait in ["idle","walk","run"]:
     case_name="Blender/"+terrain+"/"+str(height)+"/"+style+"/"+gait
     var x:float={"flat":0.0,"dirt":-17.0,"forest":19.0}[terrain]
     var z:float=10 if terrain=="flat" else -4
     scene.box(Vector3(3,height,2),Vector3(x,height*.5,z))
     var fixture:StaticBody3D=scene.get_child(scene.get_child_count()-1)
     await reset(Vector3(x,height+.01,z+.5),style,"idle")
     scene.test_input=Vector2.ZERO if gait=="idle" else Vector2(0,-1);scene.test_run=gait=="run"
     if gait=="idle":fixture.get_child(0).set_deferred("disabled",true)
     var saw_landing:=false;var saw_palm:=false;var impact:=0.0
     var previous_hand:=Vector3.ZERO;var hand_locked:=false
     for tick in 360:
      await step()
      var air=scene.motion.air;var actor=scene.actor
      pose_times.append(scene.pose_ms)
      if air.landing.active:
       saw_landing=true;impact=air.landing.impact_speed
       check(absf(air.landing.parameters.duration-air.BlenderLanding.Family.profile(-impact).duration)<.000001,"profile follows actual impact velocity")
       check(is_equal_approx(air.landing.parameters.absorb,lerpf(.20,.16,air.landing.parameters.intensity)),"stronger impact accelerates approved compression")
       if tick%4==0:
        var cached:bool=air.landing.cache_ready;air.landing.cache_ready=false
        for side in 2:
         var low:float=air.landing.gap(actor,foot_support.world_skin_points(actor.native,side,actor.global_transform))
         if is_finite(low):deepest_foot=minf(deepest_foot,low);check(low>=-.003,"physical sole clearance")
        if air.landing.palm_planted:
         var low:float=air.landing.gap(actor,air.landing.skin_points(actor,true))
         deepest_hand=minf(deepest_hand,low);check(low>=-.002,"physical palm and finger clearance")
         var knee_points:=PackedVector3Array()
         for record in air.landing.knee_samples:
          var point:=Vector3.ZERO
          for influence in record:
           var pose:Transform3D=actor.native.posed[influence[0]]
           point+=pose.basis*influence[1]+pose.origin*influence[2]
          knee_points.append(actor.global_transform*point)
         check(air.landing.gap(actor,knee_points)>=-.003,"suspended knee clears physical terrain")
        air.landing.cache_ready=cached
       if air.landing.palm_planted:
        saw_palm=true
        var point:Vector3=actor.global_transform*actor.native.posed[actor.native.arms[0].ids[3]].origin
        if hand_locked:check(Vector2(point.x,point.z).distance_to(Vector2(previous_hand.x,previous_hand.z))<.001,"palm world anchor")
        previous_hand=point;hand_locked=true
      if saw_landing and not air.landing.active and air.recovery_clock>=air.recovery_duration:break
     check(saw_landing and saw_palm,"approved Blender reception and palm contact executed")
     check(scene.motion.air.contacts==1 and scene.motion.air.falls==1,"one physical fall and landing")
     check(not scene.motion.air.landing.active,"recovery completed")
     check(scene.actor.style==style,"requested style retained")
     for tick in 24:await step()
     check(scene.body.is_on_floor(),"ground control resumes")
     print(case_name," impact ",impact," duration ",scene.motion.air.recovery_duration)
     fixture.queue_free();await physics_frame
 pose_times.sort()
 print("BLENDER INTEGRATION ",checks," checks; foot ",deepest_foot," palm ",deepest_hand," contact angle ",worst_contact," pose p95 ",pose_times[int(pose_times.size()*.95)]," ms; failures ",failures)
 scene.free();quit(0 if failures.is_empty() else 1)
