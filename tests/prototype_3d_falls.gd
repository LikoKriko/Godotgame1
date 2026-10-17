extends SceneTree
const Human=preload("res://scripts/prototype_3d/survivor_animation.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func skin_minimum(actor,human:bool,arrays:Array) -> float:
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var ids:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var posed:Array=actor.rig.posed if human else actor.posed
 var rest:Array=actor.rig.rest if human else actor.rest
 var minimum:=INF
 for i in range(0,vertices.size(),997 if human else maxi(1,vertices.size()/2000)):
  var point:=Vector3.ZERO
  for slot in 4:
   var bone:int=ids[4*i+slot];point+=(posed[bone]*rest[bone].affine_inverse()*vertices[i])*weights[4*i+slot]
  minimum=minf(minimum,point.y)
 return minimum
func run():
 var fur=load("res://scripts/prototype_3d/young_model.gd").new();root.add_child(fur)
 var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();root.add_child(actor)
 var a=fur.mesh_node.mesh.surface_get_arrays(0)
 var human_arrays=actor.mesh_node.mesh.surface_get_arrays(0)
 var knee=Human.sample(&"",&"death",.38)
 require(knee.body.basis.y.dot(Vector3.UP)>.97,"Knees support the body before it reclines")
 for leg in knee.legs:require(leg.joint.y>1 and leg.joint.y<3.0,"Both knees reach their visible support phase")
 var final=Human.sample(&"",&"death",1)
 require(final.body.basis.z.dot(Vector3.UP)>.99,"Final body lies on its back")
 for side in 2:
  var hand:Vector3=final.hands[side]
  var hip:Vector3=final.hips[side]
  require(absf(hand.x)>21,"Both arms finish open to the sides")
  require(absf(final.legs[side].end.x)>absf(hip.x)+6,"Both legs finish open to the sides")
 # Runtime interruption must preserve the displayed pose rather than restarting
 # from standing, particularly when already sliding or holding a raised weapon.
 for row in [[&"",&"run"],[&"",&"crouch"],[&"sword",&"action"],[&"bow",&"draw"],[&"",&"slide"]]:
  actor.family_override=row[0];actor.animate(row[1],.45,false)
  var start:Array=actor.rig.posed.duplicate()
  actor.family_override=&"";actor.animate(&"death",0,false,.016)
  for bone in range(16):require(start[bone].origin.distance_to(actor.rig.posed[bone].origin)<.03,"Human death begins from the displayed pose")
  var previous:Array=actor.rig.posed.duplicate()
  for frame in range(1,121):
   actor.animate(&"death",frame/120.0,false,.025)
   require(skin_minimum(actor,true,human_arrays)>-.15,"Interrupted human fall keeps visible skin above the floor: %s %d"%[row[1],frame])
   for bone in range(16):
    var before:Quaternion=previous[bone].basis.orthonormalized().get_rotation_quaternion()
    var after:Quaternion=actor.rig.posed[bone].basis.orthonormalized().get_rotation_quaternion()
    require(before.angle_to(after)<.6,"Human collapse rotations stay continuous")
   previous=actor.rig.posed.duplicate()
  var settled:Array=actor.rig.posed.duplicate();actor.animate(&"death",1,false,.025)
  for bone in range(24):require(settled[bone].is_equal_approx(actor.rig.posed[bone]),"Final human body remains still")
 for clip in [&"run",&"attack",&"hook",&"sit"]:
  fur.animate(clip,.4);var start:Array=fur.posed.duplicate()
  fur.animate(&"death",0,true,.016)
  for bone in fur.posed.size():require(start[bone].origin.distance_to(fur.posed[bone].origin)<.03,"Enemy collapse begins from the displayed pose")
  var previous:Array=fur.posed.duplicate()
  for frame in range(1,121):
   fur.animate(&"death",frame/120.0,true,1.0/60)
   require(skin_minimum(fur,false,a)>-.15,"Interrupted enemy fall keeps skin above the floor: %s %d"%[clip,frame])
   for bone in fur.posed.size():
    var before:Quaternion=previous[bone].basis.get_rotation_quaternion();var after:Quaternion=fur.posed[bone].basis.get_rotation_quaternion()
    require(before.angle_to(after)<.6,"Enemy collapse rotations stay continuous")
   previous=fur.posed.duplicate()
  var settled:Array=fur.posed.duplicate();fur.animate(&"corpse",0,true,.016)
  for bone in fur.posed.size():require(settled[bone].is_equal_approx(fur.posed[bone]),"Corpse joins the final death pose without drifting")
 actor.free();fur.free();print("%s: %d pursuit, knee support, spread, interruption and settled-corpse checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
