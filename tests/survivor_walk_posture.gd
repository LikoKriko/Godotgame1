extends SceneTree
const Solver=preload("res://scripts/continuous_body_pose.gd")
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
 var native=actor.native
 var directions:Array[Vector3]=[Vector3.BACK,Vector3.FORWARD,Vector3.LEFT,Vector3.RIGHT,Vector3(1,0,1).normalized(),Vector3(-1,0,-1).normalized()]
 var exact:=0
 for family in [&"",&"axe",&"pickaxe",&"sword",&"bow"]:
  actor.family_override=family
  for direction in directions:
   for sample in 33:
    var phase:=sample/32.0
    actor.animate(&"walk",phase,family!=&"",0,phase,direction)
    var pose:Dictionary=actor.last_pose;var pelvis:Transform3D=pose.pelvis
    var chest:Basis=pose.body.basis
    var angles:=chest.get_euler();angles.y=pelvis.basis.get_euler().y+actor.Clips.Controls.sample(&"walk",phase).spine.y
    chest=Basis.from_euler(angles)
    var bones:Array=native.spine.duplicate();bones.append_array([native.neck,native.head])
    var head_follow:Basis=Basis(Vector3.UP,actor.Clips.Controls.sample(&"walk",phase).chest.y*actor.Clips.Gait.HEAD_TWIST_SHARE)*actor.rig.posed[3].basis.orthonormalized()
    for i in bones.size():
     var bone:int=bones[i]
     var base:Basis=pelvis.basis.slerp(chest,[.25,.60,1.0][i]) if i<3 else (chest.slerp(head_follow,.35) if i==3 else head_follow)
     var share:float=[.4,.6,.8,1.0,1.0][i]
     var expected:=Basis(pelvis.basis.x.normalized(),deg_to_rad(3)*share)*base
     var diagonal:float=signf(direction.x*direction.z)*deg_to_rad(20) if absf(direction.x)>.1 and absf(direction.z)>.1 else 0.0
     expected=Basis(pelvis.basis.y.normalized(),diagonal*([.25,.60,1.0,.65,0.0][i]))*expected
     var actual:Basis=native.posed[bone].basis*native.rest[bone].basis.inverse()
     require(expected.get_rotation_quaternion().angle_to(actual.get_rotation_quaternion())<.001,"Walking adds 1.2/0.6/0.6/0.6 degrees along the spine and neck; head follows the neck")
    var original:Array[float]=[];var widened:Array[float]=[]
    for side in 2:
     var ids:Array=native.legs[side].ids
     var hip:Vector3=native.posed[ids[0]].origin;var foot:Vector3=native.posed[ids[2]].origin
     var pole:Vector3=actor.rig.posed[11+side*3].origin-actor.rig.posed[10+side*3].origin
     var base:=Solver.joint(hip,foot,native.legs[side].a,native.legs[side].b,pole)
     original.append(base.joint.dot(pelvis.basis.x));widened.append(native.posed[ids[1]].origin.dot(pelvis.basis.x))
     require(absf(native.posed[ids[1]].origin.distance_to(hip)-native.legs[side].a)<.0001 and absf(native.posed[ids[1]].origin.distance_to(foot)-native.legs[side].b)<.0001,"Knee separation preserves thigh/shin lengths and the foot support")
    if absf((widened[1]-widened[0])/(original[1]-original[0])-1.1)<.002:exact+=1
    require(absf(widened[1]-widened[0])>=absf(original[1]-original[0])-.001,"Walking knees open outward rather than collapsing inward")
    require(native.hand_error<.08,"Walking lean preserves native tool grips")
 require(exact>800,"Ten-percent knee widening is attained throughout the walking cycle and directions")
 # Running adds 0.8 degrees to every local walking contribution.
 actor.family_override=&""
 for sample in 33:
  var phase:=sample/32.0;actor.animate(&"run",phase,false,0,phase,Vector3.BACK)
  var pose:Dictionary=actor.last_pose;var pelvis:Transform3D=pose.pelvis
  var angles:Vector3=pose.body.basis.get_euler();angles.y=pelvis.basis.get_euler().y+actor.Clips.Controls.sample(&"run",phase).spine.y
  var chest:=Basis.from_euler(angles)
  var bones:Array=native.spine.duplicate();bones.append_array([native.neck,native.head])
  var head_follow:Basis=Basis(Vector3.UP,actor.Clips.Controls.sample(&"run",phase).chest.y*actor.Clips.Gait.HEAD_TWIST_SHARE)*actor.rig.posed[3].basis.orthonormalized()
  for i in bones.size():
   var base:Basis=pelvis.basis.slerp(chest,[.25,.60,1.0][i]) if i<3 else (chest.slerp(head_follow,.35) if i==3 else head_follow)
   var expected:=Basis(pelvis.basis.x.normalized(),deg_to_rad([2.0,3.4,4.8,6.2,6.2][i]))*base
   var actual:Basis=native.posed[bones[i]].basis*native.rest[bones[i]].basis.inverse()
   require(expected.get_rotation_quaternion().angle_to(actual.get_rotation_quaternion())<.001,"Running adds 0.8 degrees at each spine/neck joint and the head follows the accumulated 6.2 degrees")
  for side in 2:
   var ids:Array=native.legs[side].ids
   var pole:Vector3=actor.rig.posed[11+side*3].origin-actor.rig.posed[10+side*3].origin
   var base:=Solver.joint(native.posed[ids[0]].origin,native.posed[ids[2]].origin,native.legs[side].a,native.legs[side].b,pole)
   var centre:float=(pelvis*Vector3(0,31,0)).dot(pelvis.basis.x)
   var expected:float=centre+1.1*(base.joint.dot(pelvis.basis.x)-centre)
   require(absf(native.posed[ids[1]].origin.dot(pelvis.basis.x)-expected)<.01,"Running applies the same ten-percent knee separation")
 actor.family_override=&""
 for state in [&"run",&"idle",&"crouch_walk",&"action",&"jump"]:
  actor.animate(state,.3,false,0,.3,Vector3.BACK)
  require(is_zero_approx(native.walk_posture),"Walking posture stays scoped to walking")
 actor.animate(&"walk",.3,false,0,.3,Vector3.BACK)
 var before:float=native.walk_posture
 actor.animate(&"idle",0,false,1.0/60)
 require(native.walk_posture>0 and native.walk_posture<before,"Walking posture eases out instead of snapping on state changes")
 actor.free();print("%s: %d walking spine, neck/head, knee separation and contact checks; exact knee samples %d"%["PASS" if failures==0 else "FAIL",checks,exact]);quit(1 if failures else 0)
