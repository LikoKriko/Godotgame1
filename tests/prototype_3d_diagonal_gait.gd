extends SceneTree
const Clips=preload("res://scripts/prototype_3d/survivor_animation.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();root.add_child(actor)
 for family in Clips.FAMILIES:
  actor.family_override=family
  for state in [&"walk",&"run",&"crouch_walk"]:
   for direction:Vector3 in [Vector3(1,0,1).normalized(),Vector3(-1,0,1).normalized(),Vector3(1,0,-1).normalized(),Vector3(-1,0,-1).normalized()]:
    var previous:Array=[]
    for frame in 49:
     var phase:=frame/48.0;actor.animate(state,phase,family!=&"",0,phase,direction)
     for side in 2:
      var leg:Dictionary=actor.last_pose.legs[side]
      require(absf(leg.root.distance_to(leg.joint)-preload("res://scripts/prototype_3d/survivor_anatomy.gd").THIGH)<.001 and absf(leg.joint.distance_to(leg.end)-preload("res://scripts/prototype_3d/survivor_anatomy.gd").THIGH)<.001,"Diagonal steps retain anatomical bone lengths")
      if not previous.is_empty():
       var delta:Vector3=leg.end-previous[side];delta.y=0
       if delta.length()>.02:require(absf(delta.normalized().dot(direction))>.995,"Foot travel follows the intended diagonal throughout stance and swing")
      var foot:Basis=actor.rig.posed[12+side*3].basis
      var forward:Vector3=foot.z;forward.y=0
      require(absf(forward.normalized().dot(direction))>.995,"Rendered feet point along the diagonal, including backward stepping")
     require(actor.grip_error<.045,"Directional gait preserves equipment grips")
     previous=[actor.last_pose.legs[0].end,actor.last_pose.legs[1].end]
 actor.free();print("%s: %d diagonal trajectory, foot orientation, bone and grip checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
