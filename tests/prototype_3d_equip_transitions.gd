extends SceneTree
const Clips=preload("res://scripts/prototype_3d/survivor_animation.gd")
const Kin=preload("res://scripts/prototype_3d/human_kinematics.gd")
const Profiles=preload("res://scripts/prototype_3d/held_profiles.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func flexion(leg:Dictionary) -> float:return PI-(leg.root-leg.joint).angle_to(leg.end-leg.joint)
func run():
 var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();root.add_child(actor)
 for family in [&"axe",&"pickaxe",&"sword",&"bow"]:
  actor.family_override=family
  for clip in [&"equip",&"equip_walk",&"equip_run",&"equip_crouch",&"equip_crouch_walk"]:
   var previous:Array=[];var rotations:Array=[]
   for frame in 65:
    var t:=frame/64.0;actor.animate(clip,t,family==&"axe",0,.2)
    var current:Array=[]
    for bone in [4,5,6,7,8,9]:current.append(actor.rig.posed[bone].origin)
    if not previous.is_empty():
     for i in current.size():require(current[i].distance_to(previous[i])<1.8,"No arm teleport while equipping: %s %s %.3f"%[family,clip,t])
    var current_rotations:Array=[]
    for bone in [4,5,6,7,8,9]:current_rotations.append(actor.rig.posed[bone].basis.orthonormalized().get_rotation_quaternion())
    if not rotations.is_empty():
     for i in rotations.size():require(rotations[i].angle_to(current_rotations[i])<.35,"Equip rotations cannot snap between palm/elbow frames")
    rotations=current_rotations
    previous=current
   var end:Array=[actor.rig.posed[6].origin,actor.rig.posed[9].origin]
   var locomotion:=StringName(String(clip).trim_prefix("equip_")) if clip!=&"equip" else &"idle"
   actor.animate(locomotion,1.0 if locomotion==&"crouch" else (0.0 if locomotion==&"idle" else .2),family==&"axe",0,.2)
   for side in 2:require(end[side].distance_to(actor.rig.posed[6+side*3].origin)<.2,"Equip ends in held stance: %s %s side %d error %.3f"%[family,clip,side,end[side].distance_to(actor.rig.posed[6+side*3].origin)])
  actor.family_override=&"";actor.animate(&"idle",0,false)
  var start:Array=actor.rig.posed.duplicate()
  actor.begin_equipment_transition();actor.family_override=family
  actor.animate(&"equip",0,family==&"axe",.001)
  for bone in [4,5,6,7,8,9]:require(start[bone].origin.distance_to(actor.rig.posed[bone].origin)<.2,"Live equip starts at displayed arm: %s bone %d error %.3f"%[family,bone,start[bone].origin.distance_to(actor.rig.posed[bone].origin)])
  for frame in range(1,31):actor.animate(&"equip",frame/30.0,family==&"axe",.014)
  var finish:Array=actor.rig.posed.duplicate()
  actor.animate(&"idle",0,family==&"axe",.014)
  for bone in [5,6,8,9]:require(finish[bone].origin.distance_to(actor.rig.posed[bone].origin)<.4,"Live equip ends smoothly: %s bone %d error %.3f"%[family,bone,finish[bone].origin.distance_to(actor.rig.posed[bone].origin)])
  actor.animate(&"unequip",1,family==&"axe")
  var lowered:Array=actor.rig.posed.duplicate()
  actor.family_override=&"";actor.animate(&"idle",0,false)
  for bone in [5,6,8,9]:require(lowered[bone].origin.distance_to(actor.rig.posed[bone].origin)<.2,"Unequip returns to empty stance: %s bone %d error %.3f"%[family,bone,lowered[bone].origin.distance_to(actor.rig.posed[bone].origin)])
 for family in [&"axe",&"pickaxe",&"sword"]:
  var old:=Vector3(.38,.76,.53) if family!=&"sword" else Vector3(.10,.46,.88)
  var held:Transform3D=preload("res://scripts/prototype_3d/weapon_motion.gd").guard(Transform3D.IDENTITY,family)
  require(absf(rad_to_deg(old.angle_to(held.basis.y))-10)<.01,"Carry tilts ten degrees farther in the same diagonal plane")
  actor.family_override=family;actor.animate(&"idle",0,family==&"axe")
  var profile:=Profiles.profile(family)
  if profile.two_hands:
   var left:Vector3=actor.grip_socket.transform.affine_inverse()*actor.rig.posed[9].origin
   require(absf(left.y-profile.support)<.03 and Vector2(left.x,left.z).length()<.03,"Anatomical left hand holds the support anchor of the resized handle")
  for side in 2:
   if side!=actor.last_pose.active and not profile.two_hands:continue
   var start:=4+side*3
   var shoulder:Vector3=actor.rig.posed[start].origin;var hand:Vector3=actor.rig.posed[start+2].origin
   var before:=Kin.arm(shoulder,hand,actor.last_pose.body.basis,side)
   require(actor.rig.posed[start+1].origin.y<before.joint.y,"Occupied elbow is lower without changing its hand contact")
 # Switch directly between displayed armed poses, including an interrupted draw.
 actor.family_override=&"bow";actor.animate(&"draw",.7,true)
 for family in [&"axe",&"sword",&"pickaxe",&"bow"]:
  var initial:Array=actor.rig.posed.duplicate()
  actor.begin_equipment_transition();actor.family_override=family
  actor.animate(&"equip",0,family==&"axe",.001)
  for bone in [4,5,6,7,8,9]:require(initial[bone].origin.distance_to(actor.rig.posed[bone].origin)<.2,"Switching equipment begins at the currently displayed armed pose")
  var previous:Array=actor.rig.posed.duplicate()
  for frame in range(1,61):
   actor.animate(&"equip",frame/60.0,family==&"axe",.007)
   for bone in [5,6,8,9]:require(previous[bone].origin.distance_to(actor.rig.posed[bone].origin)<1.2,"Direct change %s frame %d bone %d step %.3f"%[family,frame,bone,previous[bone].origin.distance_to(actor.rig.posed[bone].origin)])
   for bone in [4,5,6,7,8,9]:
    require(previous[bone].basis.orthonormalized().get_rotation_quaternion().angle_to(actor.rig.posed[bone].basis.orthonormalized().get_rotation_quaternion())<.35,"Live equipment changes preserve continuous limb rotation")
   previous=actor.rig.posed.duplicate()
 # A 6-unit loaded stance loses exactly sixty percent of its extra knee angle.
 var pose:=Clips.sample(&"",&"idle",0)
 for side in 2:pose.hips[side].y-=6
 pose.body.origin.y-=6;pose.pelvis.origin.y-=6
 var before:=Clips.solve_legs(pose.duplicate(true))
 var neutral:=Clips.sample(&"",&"idle",0)
 Clips.reduce_attack_knees(pose,.5,0,Vector3.ZERO,0)
 Clips.solve_legs(pose)
 for side in 2:
  var base:=flexion(neutral.legs[side]);var previous:=flexion(before.legs[side]);var now:=flexion(pose.legs[side])
  require(absf((now-base)/(previous-base)-.4)<.001,"Attack knee excursion is reduced by sixty percent")
 actor.free();print("%s: %d equip continuity, support grip, carry cant, lowered elbow and knee checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
