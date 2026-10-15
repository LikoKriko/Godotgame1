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
 var armor_data:Array=actor.leaf_armor.shell.mesh.surface_get_arrays(0)
 var armor_vertices:PackedVector3Array=armor_data[Mesh.ARRAY_VERTEX]
 for family in [&"",&"axe",&"pickaxe",&"sword",&"bow"]:
  actor.family_override=family
  for state in [&"idle",&"walk",&"run",&"action"]:
   var clearance:=100.0
   for i in 33:
    actor.aim_contact=Vector3(0,36,32);actor.animate(state,i/32.0,true)
    for side in 2:
     var a:Vector3=actor.rig.posed[4+side*3].origin;var b:Vector3=actor.rig.posed[5+side*3].origin
     for v in armor_vertices:
      if v.y<37:continue
      var point:Vector3=actor.last_pose.body*v
      var closest:=Geometry3D.get_closest_point_to_segment(point,a,b)
      if closest.distance_to(a)<2:continue
      clearance=minf(clearance,point.distance_to(closest))
   require(clearance>=1.3,"Upper garment clears arm volume in "+String(family)+" / "+String(state))
 actor.free();print("%s: %d sculpt, high/low contact and armor clearance checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
