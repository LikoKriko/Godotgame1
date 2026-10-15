extends SceneTree
const Clips=preload("res://scripts/prototype_3d/survivor_animation.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();root.add_child(actor)
 var blade=actor.held_props[&"sword"].find_child("BeveledStoneBlade",true,false)
 require(blade!=null and blade.mesh.get_aabb().size.x<6.5 and blade.mesh.get_aabb().size.z<1.2,"Sword has a slender stone blade with real bevel thickness")
 actor.family_override=&"axe";actor.aim_contact=Vector3.INF;actor.animate(&"idle",0,true)
 require(actor.tool_frame.x.dot(actor.last_pose.body.basis*Vector3.BACK)>0.5,"Resting axe cutting edge faces forward")
 var max_drop:=0.0
 for family in [&"axe",&"pickaxe",&"sword"]:
  for point in [Vector3(0,8,32),Vector3(0,20,32),Vector3(0,42,32)]:
   for i in 16:
    var pose:Dictionary=Clips.sample(family,&"action",i/15.0,0,Vector3.ZERO,point)
    # The directed low-contact hinge intentionally lowers the pelvis. Keep
    # the standing-height limit for high contacts, where no bend is needed.
    if point.y>=35:max_drop=maxf(max_drop,31.0-(pose.body*Vector3(0,31,0)).y)
 require(max_drop<3.8,"High melee contacts keep crouching below six percent of character height")
 for family in [&"axe",&"pickaxe",&"sword"]:
  actor.family_override=family
  for point in [Vector3(0,14,28),Vector3(0,20,32)]:
   actor.aim_contact=point;actor.animate(&"action",0.5,true)
   require(actor.last_pose.contact_reachable and actor.tip_socket.position.distance_to(point)<0.03,"Low melee hinge preserves the physical impact for "+String(family))
   for leg in actor.last_pose.legs:
    require(leg.end.y>=1 and leg.joint.y>=0.5,"Low melee hinge keeps feet and knees above the floor")
 # The delivered garment has shoulder caps and a skirt, so it follows the
 # actual skeleton rather than a single rigid torso transform.
 var armor=actor.leaf_armor
 var arrays:Array=armor.shell.mesh.surface_get_arrays(0)
 var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var normalized:=true
 for i in weights.size()/4:
  var total:=0.0
  for j in 4:total+=weights[i*4+j]
  normalized=normalized and absf(total-1)<.001
 require(normalized,"Imported garment has normalized skin weights")
 for family in [&"",&"axe",&"pickaxe",&"sword",&"bow"]:
  actor.family_override=family
  for state in [&"idle",&"walk",&"run",&"action"]:
   var matching:=true
   for i in 33:
    actor.aim_contact=Vector3(0,36,32);actor.animate(state,i/32.0,true)
    armor.skeleton.force_update_all_bone_transforms()
    for bone in actor.rig.posed.size():
     var frame:Transform3D=armor.transform*armor.skeleton.get_bone_global_pose(bone)
     matching=matching and frame.origin.distance_to(actor.rig.posed[bone].origin)<.001 and frame.basis.is_equal_approx(actor.rig.posed[bone].basis)
   require(matching,"Garment follows every actual joint in "+String(family)+" / "+String(state))
 actor.free();print("%s: %d sculpt, high/low contact and garment skin checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
