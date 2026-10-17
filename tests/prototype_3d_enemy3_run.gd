extends SceneTree
const Actor=preload("res://scripts/prototype_3d/sprout_model.gd")
const Cycle=preload("res://scripts/prototype_3d/sprout_run_cycle.gd")
const Enemy=preload("res://scripts/prototype_3d/sprout_enemy.gd")
const Save=preload("res://scripts/prototype_3d/save_game.gd")
class PreviewGame:
 extends Node3D
 var paused:=false
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:
  failures+=1
  if failures<15:push_error(message)
func _initialize():call_deferred("run")
func run():
 for fps in [30,60,120]:
  var cycle:=Cycle.new();var run_seconds:=0.0;var walk_seconds:=0.0
  for frame in 90*fps:
   var timing:Dictionary=cycle.advance(1.0/fps);run_seconds+=timing.run_seconds;walk_seconds+=timing.walk_seconds
  require(absf(run_seconds-62)<.00001 and absf(walk_seconds-5)<.00001,"Preview timings are frame-rate independent: 10+20+32 running, 5 initial walking, 23 rest seconds")
  require(cycle.stage==&"run" and cycle.kind==0 and absf(cycle.elapsed)<.00001,"Preview repeats only after the five-second final rest")
 var cycle:=Cycle.new();var total:Dictionary=cycle.advance(90)
 require(absf(total.run_seconds-62)<.00001 and absf(total.walk_seconds-5)<.00001,"Large delta crosses every run/rest boundary correctly")
 for elapsed in [0.,7.9,8.,9.99,10.,18.,19.,20.,28.,29.,30.,38.,39.]:
  var state={"stage":"run","kind":2,"elapsed":elapsed};cycle.restore(state)
  require(cycle.running()==(fposmod(elapsed,10)<8),"Flee preview stops for two seconds after each eight running seconds")
  require(Cycle.valid(state),"Partial flee timers validate")
  var restored:=Cycle.new();restored.restore(JSON.parse_string(JSON.stringify(cycle.snapshot())))
  require(restored.snapshot()==cycle.snapshot(),"Cycle round trips through JSON")
 require(not Cycle.valid({"stage":"run","kind":3,"elapsed":0}),"Unknown preview type is rejected")
 require(not Cycle.valid({"stage":"rest","kind":0,"elapsed":6}),"Rest cannot exceed five seconds")
 require(absf(Enemy.RUN_SPEED/Enemy.SPEED-10)<.000001,"Physical run speed is exactly ten times the existing walk speed")
 var actor:=Actor.new();root.add_child(actor)
 var scene=load("res://scenes/prototype_3d/enemy3.tscn").instantiate();root.add_child(scene)
 var player:AnimationPlayer=scene.get_node("AnimationPlayer");var rig:Skeleton3D=scene.find_children("*","Skeleton3D",true,false)[0]
 require(player.has_animation("run") and player.get_animation("run").loop_mode==Animation.LOOP_LINEAR,"Reusable scene exposes a looped run clip")
 var mesh=actor.mesh_node.mesh;var arrays:Array=mesh.surface_get_arrays(0)
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var previous:Array[Transform3D]=[];var lowest:=INF
 var skin=actor.mesh_node.skin
 for frame in 481:
  var phase:=frame/480.0;actor.animate_run(phase)
  player.play("run");player.seek(phase*Actor.RUN_CYCLE_SECONDS,true);player.pause()
  for i in 35:
   var local:Transform3D=actor.posed[actor.parents[i]].affine_inverse()*actor.posed[i] if actor.parents[i]>=0 else actor.posed[i]
   require(actor.parents[i]<0 or absf(local.origin.length()-actor.local_bind[i].origin.length())<.00002,"Run never stretches original bones")
   require(local.basis.get_scale().distance_to(actor.local_bind[i].basis.get_scale())<.00002,"Run never scales bones")
   require(rig.get_bone_global_pose(i).origin.distance_to(actor.posed[i].origin)<.0008,"Baked run matches authored IK: %s phase %.6f error %.6f"%[rig.get_bone_name(i),phase,rig.get_bone_global_pose(i).origin.distance_to(actor.posed[i].origin)])
   if not previous.is_empty():require(previous[i].origin.distance_to(actor.posed[i].origin)<.04,"Run remains continuous through support and swing")
  for label in ["Hueso.001","Hueso.005"]:
   var i:int=actor.bone(label)
   var delta_basis:Basis=actor.posed[i].basis*actor.bind[i].basis.inverse()
   require(absf(delta_basis.get_rotation_quaternion().angle_to(Quaternion(Vector3.RIGHT,PI/3)))<.0007,"Torso and head incline sixty degrees together")
  for contact in actor.contacts:
   require(actor.posed[contact.foot].origin.distance_to(contact.target)<.00002,"Running IK retains the intended toe contact")
   require(not contact.stance or absf(contact.target.y-actor.bind[contact.foot].origin.y)<.00002,"Stance foot stays level")
  if frame%40==0:
   var matrices:Array[Transform3D]=[]
   for i in skin.get_bind_count():matrices.append(actor.skeleton.global_transform*actor.posed[skin.get_bind_bone(i)]*skin.get_bind_pose(i))
   for v in vertices.size():
    var p:=Vector3.ZERO
    for j in 8:p+=(matrices[bones[v*8+j]]*vertices[v])*weights[v*8+j]
    lowest=minf(lowest,p.y)
    require(p.is_finite(),"Imported skin stays finite while running")
  previous.assign(actor.posed)
 actor.animate_run(0);var initial:Array[Transform3D]=actor.posed.duplicate();actor.animate_run(1)
 for i in 35:require(initial[i].is_equal_approx(actor.posed[i]),"Run loop closes")
 require(lowest>=-.012,"Visible running skin remains above the floor")
 require(actor.mesh_node.mesh==mesh,"Original geometry, rig and weights are shared")
 # On a clear route, test real CharacterBody movement and the timed stops.
 var holder:=PreviewGame.new();root.add_child(holder)
 var floor_node:=StaticBody3D.new();var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(60,.2,60);collider.shape=box;floor_node.add_child(collider);floor_node.position.y=-.1;root.add_child(floor_node)
 var enemy:=Enemy.new();holder.add_child(enemy);enemy.configure(holder,Vector3.BACK);enemy.set_physics_process(false)
 await physics_frame
 for frame in 12:enemy._physics_process(1.0/60);await physics_frame
 enemy.run_cycle.restore({"stage":"run","kind":0,"elapsed":0.0});enemy.global_position=Vector3(0,.001,0);enemy.patrol.configure(enemy.global_position,Vector3.BACK)
 var distance:=0.0
 for frame in 60:
  var before:Vector3=enemy.global_position;enemy._physics_process(1.0/60);await physics_frame
  distance+=Vector2(enemy.global_position.x-before.x,enemy.global_position.z-before.z).length()
 require(absf(distance-Enemy.RUN_SPEED)<.0002,"Live movement covers ten walking distances per running second")
 enemy.run_cycle.restore({"stage":"run","kind":2,"elapsed":8.0});var before:Vector3=enemy.global_position
 for frame in 60:enemy._physics_process(1.0/60);await physics_frame
 require(Vector2(enemy.global_position.x-before.x,enemy.global_position.z-before.z).length()<.00001,"Live flee rest does not move horizontally")
 var saved:Dictionary=enemy.snapshot();require(Save.valid_sprout(saved),"Live run/rest state validates")
 var copy:=Enemy.new();holder.add_child(copy);copy.configure(holder);copy.set_physics_process(false);copy.restore(saved)
 require(copy.snapshot()==saved,"Live phase and partial rest restore exactly")
 var legacy:=saved.duplicate(true)
 for key in ["run_cycle","run_preview_enabled","run_phase"]:legacy.erase(key)
 require(Save.valid_sprout(legacy),"Existing enemy3 saves remain accepted")
 holder.paused=true;var clock:Dictionary=enemy.run_cycle.snapshot();enemy._physics_process(1)
 require(enemy.run_cycle.snapshot()==clock,"Game pause stops run and rest timers")
 holder.free();floor_node.free();actor.free();scene.free();await process_frame
 print("%s: %d enemy3 run, sixty-degree pose, skin, timing, speed and persistence checks; lowest skin %f"%["PASS" if failures==0 else "FAIL",checks,lowest]);quit(1 if failures else 0)
