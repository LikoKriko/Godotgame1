extends SceneTree
## Shared native clips must not share mutable skeletons or evaluate authoring IK.
const Model=preload("res://scripts/prototype_3d/young_model.gd")
const Motion=preload("res://scripts/prototype_3d/young_rig_motion.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var actor:=Model.new();root.add_child(actor)
 var second:=Model.new();root.add_child(second)
 require(actor.animation.get_animation_library(&"")==second.animation.get_animation_library(&""),"Actors share the baked animation library")
 var still:Array=second.posed.duplicate()
 for state in Motion.STATES:
  for left in ([true,false] if state in [&"attack",&"hook"] else [true]):
   for phase in [0.0,.117,.481,.759,1.0]:
    actor.animate(state,phase,left)
    var snapshot:Array=actor.posed.duplicate()
    var expected:Vector3=actor.socket(&"left_fist" if left else &"right_fist")
    require(actor.sample_fist(state,phase,left).distance_to(expected)<.00001,"Predicted parry contact matches the native clip")
    require(actor.posed==snapshot,"Contact prediction cannot change the visible skeleton")
    require(second.posed==still,"One actor cannot mutate another skeleton")
    actor.animate(&"idle",.2);actor.animate(state,phase,left)
    require(actor.posed==snapshot,"Seeking a shared clip is deterministic")
 for state in Motion.LOOP_STATES:
  actor.animate(state,0);var first:Array=actor.posed.duplicate();actor.animate(state,1)
  for i in first.size():require(first[i].is_equal_approx(actor.posed[i]),"Loop endpoints join exactly")
 actor.free();second.free()
 print("%s: %d native clip sharing, prediction and determinism checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
