extends SceneTree
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:
  failures+=1
  if failures<12:push_error(message)
func _initialize():call_deferred("run")
func run():
 var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();root.add_child(actor)
 var n=actor.native
 for state in [&"walk",&"run",&"crouch_walk",&"equip_walk",&"equip_run"]:
  for family in [&"",&"axe",&"pickaxe",&"sword",&"bow"]:
   actor.family_override=family
   for x in [-1,1]:
    for z in [-1,1]:
     var direction:=Vector3(x,0,z).normalized()
     for sample in 17:
      var phase:=sample/16.0;actor.animate(state,phase,family!=&"",0,phase,direction)
      var pose:Dictionary=actor.last_pose
      var plain:=pose.duplicate(true);plain.torso_travel=Vector3.ZERO
      n.sync(actor.rig,plain)
      var base:Array[Basis]=[]
      for bone in n.spine:base.append(n.posed[bone].basis*n.inverse_rest[bone].basis)
      n.sync(actor.rig,pose)
      require(absf(n.torso_turn-x*z*deg_to_rad(20))<.0001,"Forward/back diagonals choose the correct bounded turn sign")
      for segment in 3:
       var bone:int=n.spine[segment]
       var actual:Basis=n.posed[bone].basis*n.inverse_rest[bone].basis
       var expected:=Basis(pose.pelvis.basis.y.normalized(),x*z*deg_to_rad(20)*[.25,.60,1.0][segment])*base[segment]
       require(expected.get_rotation_quaternion().angle_to(actual.get_rotation_quaternion())<.001,"Diagonal twist accumulates progressively through all three spine bones")
      require(n.hand_error<.08,"Diagonal torso turn preserves native tool/weapon contacts")
      for side in 2:
       var ids:Array=n.legs[side].ids
       require(absf(n.posed[ids[0]].origin.distance_to(n.posed[ids[1]].origin)-n.legs[side].a)<.0001,"Diagonal torso turn preserves native leg lengths")
 actor.family_override=&""
 for direction in [Vector3.BACK,Vector3.FORWARD,Vector3.LEFT,Vector3.RIGHT,Vector3.ZERO]:
  actor.animate(&"walk",.3,false,0,.3,direction)
  require(absf(n.torso_turn)<.0001,"Cardinal movement has no added diagonal twist")
 for fps in [30,60,120]:
  actor.gait_direction.reset();actor.animate(&"idle",0,false)
  var previous:=0.0
  for direction in [Vector3(1,0,1).normalized(),Vector3(1,0,-1).normalized(),Vector3(-1,0,-1).normalized(),Vector3.ZERO]:
   for frame in fps:
    actor.animate(&"walk" if not direction.is_zero_approx() else &"idle",.3,false,1.0/fps,.3,direction)
    require(absf(n.torso_turn-previous)<deg_to_rad(8),"Changing direction or stopping eases the torso without a diagonal/backward snap")
    require(absf(n.torso_turn)<=deg_to_rad(20.001),"Smoothed torso twist stays within its anatomical bound")
    previous=n.torso_turn
   var expected:float=0.0 if direction.is_zero_approx() else signf(direction.x*direction.z)*deg_to_rad(20)
   require(absf(n.torso_turn-expected)<.0002,"Continuous movement converges to the requested direction at every frame rate")
 for family in [&"axe",&"pickaxe",&"sword",&"bow"]:
  actor.family_override=family;actor.aim_contact=Vector3(0,34,20)
  actor.animate(&"run",.3,true,0,.3,Vector3(1,0,1).normalized())
  for frame in 61:
   actor.animate(&"draw" if family==&"bow" else &"action",frame/60.0,true,1.0/60,.3,Vector3(1,0,1).normalized())
   require(n.hand_error<.08,"Leaving a diagonal sprint for an aimed attack preserves both native grips while the torso eases back")
 actor.family_override=&"";actor.aim_contact=Vector3.INF
 actor.animate(&"action",.5,false,0,.3,Vector3(1,0,1).normalized())
 require(absf(n.torso_turn)<.0001,"Melee retains its aimed gesture rather than a sustained locomotion twist")
 actor.free();print("%s: %d forward/back diagonal twist, spine distribution, smoothing and contact checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
