extends SceneTree
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();root.add_child(actor);actor.family_override=&"sword"
 for armor in [false,true]:
  actor.wear({"id":&"burdock_armor"} if armor else {})
  for contact:Vector3 in [Vector3(0,14,28),Vector3(0,30,32),Vector3(0,42,31)]:
   actor.aim_contact=contact
   var previous:=Vector3.INF
   for frame in 65:
    var t:=frame/64.0;actor.animate(&"action",t,true)
    var shoulder:Vector3=actor.rig.posed[4].origin
    var elbow:Vector3=actor.rig.posed[5].origin
    var hand:Vector3=actor.rig.posed[6].origin
    require(absf(shoulder.distance_to(elbow)-10)<.001 and absf(elbow.distance_to(hand)-9)<.001,"Counterweight retains the same arm bones")
    if frame in range(18,40):
     require(rad_to_deg((shoulder-elbow).angle_to(hand-elbow))>145,"Empty arm extends with a soft elbow during the effort")
     var local:Vector3=actor.last_pose.body.basis.inverse()*(hand-shoulder)
     require(local.x< -14 and local.z< -4,"Empty hand opens outside and behind the torso as a counterweight")
    if previous.is_finite():require(hand.distance_to(previous)<2.5,"Empty arm enters and recovers without position jumps")
    previous=hand
    require(actor.grip_error<.045,"Sword hand remains attached to its grip")
    if frame==32:require(actor.tip_socket.position.distance_to(contact)<.03,"Sword contact still finishes on the aimed point")
   actor.animate(&"action",1,true)
   var end:Vector3=actor.rig.posed[6].origin
   actor.animate(&"idle",0,true)
   require(end.distance_to(actor.rig.posed[6].origin)<.01,"Counterweight returns to the ordinary empty-arm resting pose")
 actor.free();print("%s: %d sword counterweight, continuity, anatomy and contact checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
