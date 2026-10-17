extends SceneTree
const Motion=preload("res://scripts/prototype_3d/young_rig_motion.gd")
class Enemy:
 extends "res://scripts/prototype_3d/young_enemy.gd"
 var visible_player:=true
 func sees_player() -> bool:return visible_player
 func obstacle(_direction:Vector3) -> bool:return false
class Game:
 extends Node3D
 var paused:=false
 var player_health:=100.0
 var player:=Node3D.new()
 var bag=preload("res://scripts/inventory.gd").new()
 var parry={"time":0.0}
 var hits:Array=[]
 func enemy_contact(_enemy,damage:float,_parry_time:float):hits.append(damage)
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:
  failures+=1
  if failures<12:push_error(message)
func _initialize():call_deferred("run")
func tick(enemy,delta:float):
 enemy.position=Vector3.ZERO;enemy.velocity=Vector3.ZERO
 enemy._physics_process(delta)
func seed_for(enemy,success:bool):
 var rng:=RandomNumberGenerator.new()
 for i in 100:
  rng.seed=i
  if (rng.randf()<.5)==success:enemy.brain.rng.seed=i;return
func check_stone_clearance(actor):
 var arrays=actor.mesh_node.mesh.surface_get_arrays(0)
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var skull:=PackedVector3Array();var fists:Array[int]=[]
 var fist_counts:=[0,0]
 var stride:=maxi(1,vertices.size()/70000)
 for i in vertices.size():
  for slot in 4:
   if weights[i*4+slot]>.5:
    var bone:int=bones[i*4+slot]
    if bone in [4,5]:skull.append(vertices[i])
    if bone in [9,13] and i%stride==0:
     fists.append(i);fist_counts[0 if bone==9 else 1]+=1
 var hull:=ConvexPolygonShape3D.new();hull.points=skull
 var faces:=hull.get_debug_mesh().get_faces();var center:=Vector3.ZERO
 for v in skull:center+=v
 center/=skull.size()
 var planes:Array[Plane]=[]
 for i in range(0,faces.size(),3):
  var plane:=Plane(faces[i],faces[i+1],faces[i+2])
  if plane.distance_to(center)>0:plane=Plane(-plane.normal,-plane.d)
  planes.append(plane)
 var count:=0
 for state in [&"boxing_guard",&"hook",&"boxing_rise",&"boxing_lower",&"boxing_walk"]:
  for left in [true,false]:
   for frame in 33:
    actor.animate(state,frame/32.0,left)
    var head_inverse:Transform3D=actor.rest[actor.head_bone]*actor.posed[actor.head_bone].affine_inverse()
    for index in fists:
     var point:=Vector3.ZERO
     for slot in 4:
      var bone:int=bones[index*4+slot];point+=(actor.posed[bone]*(actor.rest[bone].affine_inverse()*vertices[index]))*weights[index*4+slot]
     point=head_inverse*point
     var margin:float=-INF
     for plane in planes:margin=maxf(margin,plane.distance_to(point))
     count+=1
     require(margin>.02,"Stone-fist skin remains outside the entire head convex hull")
 require(fist_counts[0]>0 and fist_counts[1]>0 and count==fists.size()*5*2*33,"Collision regression covers both actual skinned fists at every phase, regardless of source vertex density")
func run():
 var model=load("res://scripts/prototype_3d/young_model.gd").new();root.add_child(model)
 check_stone_clearance(model);model.free()
 var game:=Game.new();root.add_child(game);game.add_child(game.player);game.player.position.z=.5
 var enemy:=Enemy.new();game.add_child(enemy);enemy.configure(game);enemy.set_physics_process(false)
 require(Motion.seconds(&"hook")==Motion.seconds(&"attack")+.2,"Crochet lasts exactly 0.2 seconds longer")
 var actor=enemy.model
 actor.animate(&"boxing_guard",0)
 for chain in [[7,8,9],[11,12,13]]:
  var angle:=rad_to_deg((actor.posed[chain[0]].origin-actor.posed[chain[1]].origin).angle_to(actor.posed[chain[2]].origin-actor.posed[chain[1]].origin))
  require(absf(angle-110)<.01,"Native boxing elbows hold 110 degrees")
  require((actor.posed[chain[2]].origin-actor.posed[chain[1]].origin).normalized().y>.8,"Native boxing forearms point upward")
 actor.animate(&"boxing_guard",0)
 var guard:Array=actor.posed.duplicate()
 for left in [true,false]:
  var rotation:=0.0
  for frame in 33:
   actor.animate(&"hook",frame/32.0,left)
   for bone in range(17,25):require(actor.posed[bone].origin.distance_to(guard[bone].origin)<.001,"Native hook keeps hips, knees and feet stable")
   rotation=maxf(rotation,guard[2].basis.get_rotation_quaternion().angle_to(actor.posed[2].basis.get_rotation_quaternion()))
  require(rotation>.15,"Native torso follows the circular hook")
 enemy.advance_boxing(100)
 require(not enemy.boxing_unlocked and enemy.boxing_remaining==0,"Undamaged enemies never roll for boxing")
 seed_for(enemy,false);enemy.take_damage(1)
 require(enemy.boxing_unlocked and enemy.boxing_remaining==0,"First hit unlocks schedule and may fail its 50 percent roll")
 require(enemy.boxing_check_remaining==10,"First hit starts ten-second schedule")
 enemy.advance_boxing(9.9);seed_for(enemy,true);enemy.take_damage(1)
 require(enemy.boxing_remaining==0 and enemy.boxing_check_remaining<.11,"Repeated damage never grants extra rolls or resets timer")
 enemy.advance_boxing(.11)
 require(enemy.boxing_remaining==20,"Successful ten-second roll starts twenty-second boxing mode")
 enemy.advance_boxing(10)
 require(is_equal_approx(enemy.boxing_remaining,10),"Checks during boxing cannot extend its duration")
 seed_for(enemy,false);enemy.advance_boxing(10)
 require(enemy.boxing_remaining==0 and enemy.lower_from_boxing,"Mode ends after twenty seconds and lowers from boxing guard")
 enemy.boxing_remaining=20;enemy.boxing_check_remaining=10;enemy.rise_elapsed=-1;enemy.lower_elapsed=-1;enemy.standing=true;enemy.start_attack()
 var first_left:bool=enemy.punch_left
 tick(enemy,.59)
 require(game.hits.is_empty(),"Crochet cannot damage before its 0.6 second contact")
 tick(enemy,.02)
 require(game.hits==[4.0],"Crochet applies exactly four damage at contact")
 tick(enemy,.58)
 require(game.hits==[4.0],"One crochet never duplicates its damage")
 tick(enemy,.02)
 require(enemy.punch_left!=first_left and enemy.attack_elapsed>=0,"Crochets alternate arms while target remains in range")
 tick(enemy,.6)
 require(game.hits==[4.0,4.0],"Second arm applies its own four damage")
 enemy.visible_player=false;tick(enemy,.6)
 require(enemy.attack_elapsed<0 and enemy.model.last_pose.state==&"boxing_guard","Lost target returns to raised guard without a phantom hit")
 enemy.boxing_remaining=.1;enemy.boxing_check_remaining=5;enemy.attack_elapsed=.55;enemy.impact_done=false
 game.hits.clear();tick(enemy,.11)
 require(game.hits.is_empty() and enemy.attack_elapsed<0,"Expiry before contact cancels the hook without late damage")
 enemy.boxing_remaining=10
 game.paused=true;var remaining:float=enemy.boxing_remaining;tick(enemy,2)
 require(enemy.boxing_remaining==remaining,"Pause freezes boxing schedule")
 game.paused=false;enemy.stun(1.5)
 require(enemy.attack_elapsed<0,"Stun cancels the active attack")
 enemy.effects.active.clear();enemy.boxing_remaining=0;enemy.attack_elapsed=-1;enemy.standing=true;enemy.start_attack();enemy.visible_player=true
 game.hits.clear();tick(enemy,.5)
 require(game.hits==[2.0],"Normal punches retain their one-second timing and two damage")
 # Exercise the probability itself across independent deterministic RNG states.
 var successes:=0
 for i in 1000:
  enemy.boxing_remaining=0;enemy.brain.rng.seed=i;enemy.roll_boxing()
  if enemy.boxing_remaining>0:successes+=1
 require(successes>440 and successes<560,"Seeded rolls retain a 50 percent distribution")
 enemy.health=1;enemy.take_damage(1)
 require(enemy.health==0 and enemy.boxing_remaining==0,"Death clears boxing and cannot trigger another mode")
 game.free();print("%s: %d enemy boxing timing, damage, probability and pose checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
