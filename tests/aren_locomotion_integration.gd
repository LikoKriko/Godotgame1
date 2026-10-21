extends SceneTree
## Exercise the real sandbox inputs: six links, rapid state changes and terrain.
var failures:Array[String]=[]
var checks:=0
var stats:={"slide_m":0.0,"twist_deg":0.0,"length_m":0.0,"hip_step_m":0.0,"torso_step_deg":0.0,"turn_deg":0.0,"pose_ms":0.0,"samples":0,"rays":0}
const STYLES=["normal","cautious","tired"]
const TERRAINS={"flat":Vector3(0,.1,40),"slope":Vector3(0,1.2,-6),"bumps":Vector3(-7,.2,-5),"stairs":Vector3(7,.3,-6),"forest":Vector3(19,1.2,-8)}
var case_label:=""
func _initialize():call_deferred("run")
func check(value:bool,message:String):
 checks+=1
 var labelled:=case_label+": "+message
 if not value and labelled not in failures:failures.append(labelled);push_error(labelled)
func style_key(scene:Node3D,index:int):
 var actor=scene.actor
 var phase:float=actor.phase;var clock:float=actor.clock
 var pose:Array[Transform3D]=actor.native.posed.duplicate()
 var event:=InputEventKey.new();event.pressed=true;event.keycode=KEY_1+index
 scene._unhandled_input(event)
 check(actor.phase==phase and actor.clock==clock,"State change restarted the gait clock")
 for bone in pose.size():check(actor.native.posed[bone].is_equal_approx(pose[bone]),"State change exposed a discontinuous pose")
func capture(scene:Node3D) -> Dictionary:
 var actor=scene.actor;var native=actor.native;var feet:Array=[];var torso:Array=[]
 for side in 2:feet.append(actor.global_transform*native.posed[native.legs[side].ids[2]])
 for bone in [native.binding.bone(&"root")]+Array(native.spine):torso.append(native.posed[bone].basis.orthonormalized().get_rotation_quaternion())
 var hip:Vector3=actor.global_transform*native.posed[native.binding.bone(&"root")].origin
 hip-=Vector3(scene.body.position.x,0,scene.body.position.z)
 return {"feet":feet,"torso":torso,"hip":hip,"heading":actor.rotation.y,"contacts":actor.terrain_contacts.duplicate(true)}
func inspect(scene:Node3D,previous:Dictionary):
 var actor=scene.actor;var native=actor.native;var after:=capture(scene)
 for bone in native.posed:check(bone.is_finite(),"Nonfinite native pose")
 check(is_finite(actor.pelvis_offset) and absf(actor.reach_velocity)<=.75001,"Invalid pelvis compensation")
 check(absf(actor.turn_bank)<=deg_to_rad(4)+.0001,"Excessive lateral bank")
 for side in 2:
  var leg:Dictionary=native.legs[side];var ids:Array=leg.ids
  var hip:Vector3=native.posed[ids[0]].origin;var knee:Vector3=native.posed[ids[1]].origin;var ankle:Vector3=native.posed[ids[2]].origin
  var length_error:float=maxf(absf(hip.distance_to(knee)-leg.a),absf(knee.distance_to(ankle)-leg.b))*actor.SCALE
  stats.length_m=maxf(stats.length_m,length_error)
  check(length_error<.00005,"Native leg length changed")
  check(hip.distance_to(ankle)>=actor.minimum_reach(side)-.0001,"Leg exceeded its anatomical flexion bound")
  var contact:Dictionary=after.contacts[side]
  if previous.contacts[side].planted and contact.planted and contact.anchor.is_equal_approx(previous.contacts[side].anchor):
   var actual:Transform3D=after.feet[side]
   var slide:=Vector2(actual.origin.x-contact.anchor.x,actual.origin.z-contact.anchor.z).length()
   var twist:float=actual.basis.orthonormalized().get_rotation_quaternion().angle_to(contact.basis.orthonormalized().get_rotation_quaternion())
   stats.slide_m=maxf(stats.slide_m,slide);stats.twist_deg=maxf(stats.twist_deg,rad_to_deg(twist))
   check(slide<.006,"Planted foot slid")
   check(twist<deg_to_rad(2),"Planted foot rotated")
 var hip_step:float=after.hip.distance_to(previous.hip);stats.hip_step_m=maxf(stats.hip_step_m,hip_step)
 check(hip_step<.04,"Visual pelvis jumped more than 4 cm in one frame")
 for index in after.torso.size():
  var angle:float=rad_to_deg(after.torso[index].angle_to(previous.torso[index]));stats.torso_step_deg=maxf(stats.torso_step_deg,angle)
  check(angle<15,"Torso pose jumped in one frame")
 var turn:float=absf(wrapf(after.heading-previous.heading,-PI,PI));stats.turn_deg=maxf(stats.turn_deg,rad_to_deg(turn))
 check(turn<=deg_to_rad(360)/60+.0001,"Body exceeded its turn speed limit")
 stats.pose_ms+=scene.pose_ms;stats.rays+=actor.ray_count;stats.samples+=1
 return after
func run():
 var scene=load("res://scenes/prototype_3d/aren_terrain_test.tscn").instantiate()
 root.add_child(scene);scene.automated=true;scene.set_physics_process(false)
 var cases:=0
 for terrain in TERRAINS:
  for style in 3:
   case_label=terrain+"/"+STYLES[style]
   scene.actor.change_style(STYLES[style]);scene.yaw=0;scene.test_input=Vector2.ZERO;scene.test_run=false
   scene.reset_at(TERRAINS[terrain])
   for tick in 90:await physics_frame;scene._physics_process(1.0/60)
   check(scene.body.is_on_floor(),"Scenario did not settle onto its surface")
   var previous:=capture(scene);var heading:float=scene.actor.rotation.y
   var direction:=Vector2(0,-1)
   var visited:Dictionary={};var state_links:Dictionary={};var recipes:Dictionary={}
   var failures_before:=failures.size()
   for tick in 1320:
    await physics_frame
    if tick<1020:
     var gait:="idle" if tick<60 or (tick>=540 and tick<690) or tick>=870 else ("run" if (tick>=210 and tick<390) or tick>=690 else "walk")
     visited[gait]=true;scene.test_run=gait=="run"
     # Stay on each test strip, turning back before leaving its useful length.
     var bounds:=Vector2(-13,-4) if terrain=="bumps" else (Vector2(-9,-4.5) if terrain=="stairs" else (Vector2(-18,-5) if terrain=="slope" else Vector2(-24,0)))
     if terrain!="flat":
      if scene.body.position.z<bounds.x:direction.y=1
      if scene.body.position.z>bounds.y:direction.y=-1
     var dx:float=clampf((TERRAINS[terrain].x-scene.body.position.x)*.8,-.5,.5)
     scene.test_input=Vector2.ZERO if gait=="idle" else Vector2(dx,direction.y).normalized()
     # Camera movement with compensating input preserves the world request.
     if style%2==1:scene.yaw+=.003;scene.test_input=scene.test_input.rotated(scene.yaw)
    elif tick<1140:
     var offset:=tick-1020
     if offset%12==0:
      var index:int=[0,1,2,0,2,1,0,2,1,0][offset/12]
      if scene.actor.style!=STYLES[index]:state_links[scene.actor.style+"/"+STYLES[index]]=true
      style_key(scene,index)
     scene.test_run=(offset/6)%2==0
     scene.test_input=Vector2(0,-1).rotated(deg_to_rad([45,90,135,180,-90][(offset/12)%5]))
    else:
     scene.test_input=Vector2.ZERO;scene.test_run=false
     if tick>=1260:scene.yaw+=.03
    scene._physics_process(1.0/60)
    previous=inspect(scene,previous)
    if tick<1020 and not scene.actor.recipe.is_empty():recipes[scene.actor.recipe]=true
    if tick in [209,389,539,689,869,1019]:check(scene.actor.recipe.is_empty(),"Complete movement transition did not finish")
    if tick in [59,689,1019,1259]:check(scene.actor.measured_speed<.03,"Idle did not settle")
    if tick>=1260:
     check(absf(wrapf(scene.actor.rotation.y-heading,-PI,PI))<.0001,"Camera-only motion rotated stationary Aren")
     check(absf(scene.actor.turn_bank)<deg_to_rad(.1),"Camera-only motion banked stationary Aren")
    else:heading=scene.actor.rotation.y
   check(visited.size()==3 and state_links.size()==6,"Incomplete movement/state coverage")
   for recipe in scene.actor.profile.recipes:check(recipes.has(recipe),"Playable input omitted "+recipe)
   cases+=1;print("PASS integrated " if failures.size()==failures_before else "FAIL integrated ",case_label)
 print("Integrated locomotion: ",cases," cases; ",checks," checks; failures ",failures.size(),"; ",JSON.stringify(stats))
 scene.free();quit(0 if failures.is_empty() else 1)
