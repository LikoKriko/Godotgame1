extends SceneTree
## Rendered native endpoints, knee hinges and crouching neck continuity.
const Model=preload("res://scripts/prototype_3d/survivor_model.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:
  failures+=1
  if failures<12:push_error(message)
func _initialize():call_deferred("run")
func run():
 var actor=Model.new();root.add_child(actor);actor.family_override=&""
 var n=actor.native
 var hips:int=n.parents[n.spine[0]]
 var bones:Array=[hips]+n.spine+[n.neck,n.head]
 for state in [&"walk",&"run"]:
  for x in [-1,1]:
   for z in [-1,1]:
    var direction:=Vector3(x*sin(Model.Clips.Gait.DIAGONAL_ANGLE),0,z*cos(Model.Clips.Gait.DIAGONAL_ANGLE))
    for frame in 65:
     var phase:=frame/64.0
     actor.animate(state,phase,false,0,phase,direction)
     var pose:Dictionary=actor.last_pose
     var neutral:=pose.duplicate();neutral.torso_travel=Vector3.ZERO
     n.sync(actor.rig,neutral)
     var reference:Array[Transform3D]=n.posed.duplicate()
     n.sync(actor.rig,pose)
     for i in bones.size():
      var bone:int=bones[i]
      var expected:=Basis(pose.pelvis.basis.y.normalized(),deg_to_rad([33.0,31.5,30.5,30.0,29.0,28.0][i])*x*z)*reference[bone].basis
      for axis in 3:require(expected[axis].distance_to(n.posed[bone].basis[axis])<.0001,"Diagonal yaw follows the requested pelvis-to-head counter-turn")
     if z>0:
      var side:int=0 if x<0 else 1
      var ids:Array=n.legs[side].ids
      var root_position:Vector3=n.posed[ids[0]].origin
      var knee:Vector3=n.posed[ids[1]].origin
      var foot:Vector3=n.posed[ids[2]].origin
      var axis:Vector3=root_position.direction_to(foot)
      var radial:Vector3=knee-root_position-axis*(knee-root_position).dot(axis)
      var forward:Vector3=pose.leg_frame.z
      var hip_frame:Transform3D=n.posed[hips]*n.inverse_rest[hips]
      var lateral:Vector3=hip_frame.basis.x.normalized()
      lateral=(lateral-axis*lateral.dot(axis)).normalized()
      require(radial.dot(forward)>0,"Leading diagonal knee bends forward rather than behind the leg")
      require(absf(radial.normalized().dot(lateral))<=sin(deg_to_rad(25.0))+.0001,"Near-straight knee retains a forward hinge instead of consuming the entire circle sideways")
      require(absf(root_position.distance_to(knee)-n.legs[side].a)<.0001 and absf(knee.distance_to(foot)-n.legs[side].b)<.0001,"Diagonal knee correction preserves native leg lengths")
 # Compare the crouching spine with the same body pose without added curvature.
 for frame in 17:
  var phase:=frame/16.0;actor.animate(&"crouch",phase,false)
  var pose:Dictionary=actor.last_pose
  var neutral:=pose.duplicate();neutral.clip_state=&"idle"
  n.sync(actor.rig,neutral)
  var reference:Array[Transform3D]=n.posed.duplicate()
  n.sync(actor.rig,pose)
  var upper:Array=n.spine+[n.neck,n.head]
  for i in upper.size():
   var bone:int=upper[i]
   var expected:=Basis(pose.pelvis.basis.x.normalized(),deg_to_rad([1.5,3.0,5.0,5.0,5.0][i])*phase)*reference[bone].basis
   for axis in 3:require(expected[axis].distance_to(n.posed[bone].basis[axis])<.0001,"Crouching adds five degrees, with two degrees at the scapular bone")
 for state in [&"crouch",&"crouch_walk"]:
  for frame in 33:
   var phase:=frame/32.0;actor.animate(state,1.0 if state==&"crouch" else phase,false,0,phase,Vector3(.574,0,.819))
   for bone in n.spine+[n.neck,n.head]:
    var parent:int=n.parents[bone]
    require(absf(n.posed[bone].origin.distance_to(n.posed[parent].origin)-n.rest[bone].origin.distance_to(n.rest[parent].origin))<.0001,"Crouching cannot stretch the spine, neck or head away from its parent")
    require(n.posed[bone].basis.get_scale().distance_to(n.rest[bone].basis.get_scale())<.0001,"Head and neck preserve their native scale")
 actor.action_crouch=1.0;actor.animate(&"action",.5,false)
 require(is_equal_approx(n.crouch_posture,1.0),"A crouched gesture keeps the added back curvature while Ctrl is held")
 actor.action_crouch=0.0
 for fps in [30,60,120]:
  actor.displayed_pose.clear();actor.gait_direction.reset()
  actor.animate(&"walk",.3,false,0,.3,Vector3(.574,0,.819))
  var previous:Array[Transform3D]=n.posed.duplicate()
  for frame in fps*3:
   var time:float=frame/float(fps)
   var state:StringName=&"walk" if time<.5 or time>2.5 else (&"crouch" if time<1.0 else &"crouch_walk")
   var phase:float=clampf((time-.5)/.25,0,1) if state==&"crouch" else fposmod(time,1)
   actor.animate(state,phase,false,1.0/fps,fposmod(time,1),Vector3(.574,0,.819))
   for bone in n.spine+[n.neck,n.head]:
    require(n.posed[bone].origin.distance_to(previous[bone].origin)<2.0*60/fps,"Crouching and standing keep the neck/head position continuous")
    var angle:float=n.posed[bone].basis.orthonormalized().get_rotation_quaternion().angle_to(previous[bone].basis.orthonormalized().get_rotation_quaternion())
    require(angle<.6*60/fps,"Crouch curvature eases in and out without a head or spine flip")
   previous=n.posed.duplicate()
 actor.free();print("%s: %d diagonal counter-turn, native knee hinge and crouching spine/head checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
