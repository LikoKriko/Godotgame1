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
 var data:Array=actor.mesh_node.mesh.surface_get_arrays(0)
 var vertices:PackedVector3Array=data[Mesh.ARRAY_VERTEX];var colors:PackedColorArray=data[Mesh.ARRAY_COLOR];var tags:PackedVector2Array=data[Mesh.ARRAY_TEX_UV]
 var skin_top:=-100.0;var hair_top:=-100.0
 for i in vertices.size():
  if int(tags[i].x)!=3:continue
  if colors[i].r>0.7:skin_top=maxf(skin_top,vertices[i].y)
  elif colors[i].r<0.38 and colors[i].g<0.27:hair_top=maxf(hair_top,vertices[i].y)
 require(hair_top>skin_top and hair_top-skin_top<2.2,"Reference hair forms a close layered scalp without spherical curls")
 var blade=actor.held_props[&"sword"].find_child("BeveledStoneBlade",true,false)
 require(blade!=null and blade.mesh.get_aabb().size.x<6.5 and blade.mesh.get_aabb().size.z<1.2,"Sword has a slender stone blade with real bevel thickness")
 actor.family_override=&"axe";actor.aim_contact=Vector3.INF;actor.animate(&"idle",0,true)
 require(actor.tool_frame.x.dot(actor.last_pose.body.basis*Vector3.BACK)>0.5,"Resting axe cutting edge faces forward")
 var max_drop:=0.0
 for family in [&"axe",&"pickaxe",&"sword"]:
  for point in [Vector3(0,8,32),Vector3(0,20,32),Vector3(0,42,32)]:
   for i in 16:
    var pose:Dictionary=Clips.sample(family,&"action",i/15.0,0,Vector3.ZERO,point)
    max_drop=maxf(max_drop,26.9-(pose.body*Vector3(0,26.9,0)).y)
 require(max_drop<3.8,"All melee phases keep crouching below six percent of character height")
 var armor_data:Array=actor.leaf_armor.shell.mesh.surface_get_arrays(0)
 var armor_vertices:PackedVector3Array=armor_data[Mesh.ARRAY_VERTEX]
 for family in [&"",&"axe",&"pickaxe",&"sword",&"bow"]:
  actor.family_override=family
  for state in [&"idle",&"walk",&"run",&"action"]:
   var clearance:=100.0
   for i in 8:
    actor.aim_contact=Vector3(0,36,32);actor.animate(state,i/7.0,true)
    for side in 2:
     var a:Vector3=actor.rig.posed[4+side*3].origin;var b:Vector3=actor.rig.posed[5+side*3].origin
     for v in armor_vertices:
      if v.y<37:continue
      var point:Vector3=actor.last_pose.body*v
      var closest:=Geometry3D.get_closest_point_to_segment(point,a,b)
      if closest.distance_to(a)<2:continue
      clearance=minf(clearance,point.distance_to(closest))
   require(clearance>=1.3,"Upper garment clears arm volume in "+String(family)+" / "+String(state))
 actor.free();print("%s: %d sculpt, reduced bend and armor clearance checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
