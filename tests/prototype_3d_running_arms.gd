extends SceneTree
var failures:=0
var checks:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();root.add_child(actor)
 for family in [&"",&"sword",&"bottle"]:
  actor.family_override=family
  for frame in 24:
   actor.animate(&"run",frame/24.0,family!=&"",0,frame/24.0,Vector3.BACK)
   for side in 2:
    if family!=&"" and side==actor.last_pose.active:continue
    var a:Vector3=actor.rig.posed[4+side*3].origin;var b:Vector3=actor.rig.posed[5+side*3].origin;var c:Vector3=actor.rig.posed[6+side*3].origin
    var angle:=rad_to_deg((a-b).angle_to(c-b))
    require(absf(angle-75)<0.05,"Free running elbow keeps 75 degree interior angle")
    var upper:Vector3=actor.last_pose.body.basis.inverse()*(b-a).normalized()
    require(absf(rad_to_deg(atan2(upper.z,-upper.y)))<=18.1,"Upper-arm swing remains limited and follows the torso")
    require(absf(a.distance_to(b)-10.0)<0.001 and absf(b.distance_to(c)-9.0)<0.001,"Running bends real joints without stretching bones")
 for family in [&"axe",&"pickaxe",&"bow"]:
  actor.family_override=family
  for frame in 12:
   actor.aim_contact=Vector3(0,42,100);actor.animate(&"run",frame/12.0,true,0,frame/12.0)
   require(actor.grip_error<0.045,"Two-handed equipment preserves hand attachments while running")
 actor.family_override=&"";actor.animate(&"idle",0,false)
 actor.animate(&"run",0.2,false,0.016,0.2)
 require(actor.rig.run_arm_blend[0]>0 and actor.rig.run_arm_blend[0]<1,"Starting run blends into the elbow pose")
 for i in 15:actor.animate(&"run",0.2,false,0.016,0.2)
 for i in 16:actor.animate(&"idle",0,false,0.016)
 require(actor.rig.run_arm_blend[0]==0,"Stopping returns arms smoothly to resting pose")
 actor.free();print("%s: %d running elbow, swing, transition and grip checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
