extends "res://tests/aren_air_integration.gd"
## Voluntary high jumps and immediate relaunch after the complete reception.
func run() -> void:
 Engine.physics_ticks_per_second=240
 scene=load("res://scenes/prototype_3d/aren_terrain_test.tscn").instantiate()
 root.add_child(scene);scene.automated=true;scene.set_physics_process(false)
 foot_support.configure(scene.actor.native)
 check(is_equal_approx(scene.motion.air.Jump.PREPARE,.20),"60 percent preparation reduction already applied")
 check(is_equal_approx(scene.motion.air.Jump.PUSH,.105) and is_equal_approx(scene.motion.air.Jump.LAUNCH_SPEED,3.8),"approved explosive impulse unchanged")
 for terrain in ["flat","dirt","forest"]:
  for style in ["normal","cautious","tired"]:
   for gait in ["idle","walk","run"]:
    case_name="high jump/"+terrain+"/"+style+"/"+gait
    var x:float={"flat":0.0,"dirt":-17.0,"forest":19.0}[terrain]
    var z:float=10 if terrain=="flat" else -4
    scene.box(Vector3(3,3.2,7),Vector3(x,1.6,z))
    var fixture:StaticBody3D=scene.get_child(scene.get_child_count()-1)
    await reset(Vector3(x,3.21,z+2.3),style,"idle")
    scene.test_input=Vector2.ZERO if gait=="idle" else Vector2(0,-1);scene.test_run=gait=="run"
    scene.motion.jump_requested=true
    var prepare_ticks:=0
    while scene.motion.air.launches==0 and prepare_ticks<30:await step();prepare_ticks+=1
    check(prepare_ticks/60.0>=.305 and prepare_ticks/60.0<.305+1.0/60+.0001,"no extra delay after Space")
    fixture.get_child(0).set_deferred("disabled",true)
    var saw_landing:=false;var saw_palm:=false
    for tick in 360:
     await step()
     if scene.motion.air.landing.active:
      saw_landing=true;saw_palm=saw_palm or scene.motion.air.landing.palm_planted
     if saw_landing and not scene.motion.air.landing.active:break
    check(saw_landing and saw_palm,"voluntary jump uses approved Blender reception")
    check(scene.motion.air.launches==1 and scene.motion.air.falls==0 and scene.motion.air.contacts==1,"voluntary/automatic classification retained")
    scene.motion.jump_requested=true
    var ticks:=0
    while scene.motion.air.launches<2 and ticks<30:await step();ticks+=1
    check(ticks<=20,"jump control restored after recovery")
    for tick in 120:await step()
    check(scene.body.is_on_floor(),"second jump completed")
    print("PASS ",case_name," preparation ",prepare_ticks/60.0," s")
    fixture.queue_free();await physics_frame
 # The sandbox keeps the old shortcuts and adds continuously profiled examples.
 var key:=InputEventKey.new();key.pressed=true;key.keycode=KEY_PLUS
 scene._unhandled_input(key)
 check(is_equal_approx(scene.blender_height,3.5) and is_equal_approx(scene.body.position.y,3.51),"intermediate ledge shortcut")
 key.keycode=KEY_4;key.shift_pressed=true;scene._unhandled_input(key)
 check(is_instance_valid(scene.drop_ledge) and is_equal_approx(scene.body.position.x,-17),"irregular terrain ledge shortcut")
 key.keycode=KEY_BACKSPACE;scene._unhandled_input(key)
 check(not is_instance_valid(scene.drop_ledge),"idle loss of actual support shortcut")
 print("BLENDER CONTROLS ",checks," checks; contact angle ",worst_contact," failures ",failures)
 scene.free();quit(0 if failures.is_empty() else 1)
