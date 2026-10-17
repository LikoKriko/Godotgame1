extends SceneTree
const Brain=preload("res://scripts/prototype_3d/creature_brain.gd")
const Motion=preload("res://scripts/prototype_3d/young_rig_motion.gd")
class Game:
 extends Node3D
 var paused:=false
 var player_health:=100.0
 var player:=Node3D.new()
 var bag=preload("res://scripts/inventory.gd").new()
 var parry={"time":0.0}
 var day_cycle=preload("res://scripts/day_cycle.gd").new()
 func enemy_contact(_enemy,_damage,_time):pass
class HabitatTree extends StaticBody3D:
 var health:=3
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 for hour in [23.0,0.0,5.999]:require(Brain.night(hour),"Sleep window includes 23:00 through 05:59")
 for hour in [6.0,12.0,22.999]:require(not Brain.night(hour),"Sleep window ends at exactly 06:00")
 var brain:=Brain.new();brain.configure(31)
 require(brain.advance(.01,Vector3.ZERO,Vector3(30,0,0),false,[],23)==&"sleep_down","Calm enemy settles for night")
 require(brain.advance(.71,Vector3.ZERO,Vector3(30,0,0),false,[],23)==&"sleep","Enemy stays asleep after settling")
 require(brain.advance(.01,Vector3.ZERO,Vector3(19,0,0),true,[],0)==&"wake_up","Detection wakes the sleeping enemy through a transition")
 require(brain.advance(.7,Vector3.ZERO,Vector3(19,0,0),true,[],0)==&"chase","Awake enemy responds to detected player")
 brain.advance(.1,Vector3.ZERO,Vector3(40,0,0),false,[],0)
 require(brain.mode==&"investigate" and brain.goal==Vector3(19,0,0),"Night does not erase last-seen player memory")
 brain.remembers_player=false;brain.set_mode(&"sleep")
 require(brain.advance(.01,Vector3.ZERO,Vector3(40,0,0),false,[],6)==&"wake_up","Dawn starts awakening")
 brain.advance(.7,Vector3.ZERO,Vector3(40,0,0),false,[],6)
 require(not brain.sleeping(),"Dawn returns to daytime activities")
 brain.set_mode(&"sit_down",.28);brain.advance(.29,Vector3.ZERO,Vector3(40,0,0),false,[],12)
 require(brain.mode==&"sit" and brain.remaining>=4,"Sit-down holds the existing seated animation")
 brain.advance(9,Vector3.ZERO,Vector3(40,0,0),false,[],12)
 require(brain.mode==&"sit_up","Rest ends through the existing rise animation")
 var game:=Game.new();root.add_child(game);game.add_child(game.player);game.player.position=Vector3(30,0,0)
 var ground:=StaticBody3D.new();game.add_child(ground);ground.collision_layer=1
 var floor_shape:=CollisionShape3D.new();floor_shape.shape=BoxShape3D.new();floor_shape.shape.size=Vector3(100,.2,100);floor_shape.position.y=-.1;ground.add_child(floor_shape)
 var tree:=HabitatTree.new();game.add_child(tree);tree.add_to_group("prototype_trees");tree.position=Vector3(0,0,4)
 var trunk:=CollisionShape3D.new();trunk.shape=CapsuleShape3D.new();trunk.shape.radius=.25;trunk.shape.height=2;trunk.position.y=1;tree.add_child(trunk);tree.collision_layer=1
 var enemy=load("res://scripts/prototype_3d/young_enemy.gd").new();game.add_child(enemy);enemy.configure(game);enemy.set_physics_process(false)
 enemy.brain.set_mode(&"idle");game.day_cycle.hour=12
 # Direct callers and stale attack flags must not bypass the damaging-hit gate.
 for i in 100:
  enemy.brain.rng.seed=i;enemy.roll_boxing()
 require(enemy.boxing_remaining==0 and not enemy.boxing_unlocked,"Calling the boxing roll directly cannot unlock an undamaged enemy")
 enemy.boxing_unlocked=true;enemy.boxing_remaining=20;enemy.attack_boxing=true;enemy.attack_elapsed=.4
 require(enemy.attack_clip()==&"attack","Stale secondary-attack flags cannot select the crochet")
 enemy.advance_boxing(.1)
 require(enemy.boxing_remaining==0 and not enemy.attack_boxing and enemy.attack_elapsed<0,"Undamaged stale mode is cleared before combat")
 enemy.take_damage(0);require(not enemy.boxing_unlocked,"Zero damage does not unlock the secondary attack")
 game.day_cycle.hour=23;enemy.position=Vector3(0,0,0);game.player.position=Vector3(19.9,0,0)
 await physics_frame
 require(enemy.sees_player(),"Night-time detection reaches twenty metres")
 var wall:=StaticBody3D.new();game.add_child(wall);wall.collision_layer=1
 var wall_shape:=CollisionShape3D.new();wall_shape.shape=BoxShape3D.new();wall_shape.shape.size=Vector3(.2,3,3);wall_shape.position=Vector3(10,1.5,0);wall.add_child(wall_shape)
 await physics_frame
 require(not enemy.sees_player(),"Walls still block the twenty-metre wake perception")
 wall.free();await physics_frame
 game.player.position=Vector3(20.1,0,0);require(not enemy.sees_player(),"Detection does not extend beyond twenty metres")
 game.day_cycle.hour=12;require(not enemy.sees_player(),"Daytime detection preserves the original radius")
 enemy.brain.set_mode(&"sleep");game.player.position=Vector3(30,0,0)
 enemy.take_damage(1)
 require(enemy.health==9 and enemy.boxing_unlocked and enemy.brain.mode==&"wake_up","Actual damage unlocks boxing and interrupts sleep")
 enemy.boxing_unlocked=false;enemy.boxing_remaining=0;enemy.attack_elapsed=-1;enemy.rise_elapsed=-1;enemy.lower_elapsed=-1;enemy.standing=false
 enemy.brain.remembers_player=false;enemy.brain.configure(9);enemy.brain.set_mode(&"sit",4);enemy.restore_presentation()
 require(enemy.model.last_pose.state==&"sit","Loading restores an existing seated pose")
 enemy.brain.tree=tree;enemy.brain.set_mode(&"feed",4);enemy.restore_presentation()
 require(enemy.model.last_pose.state==&"feed","Loading restores feeding rather than idle")
 enemy.brain.set_mode(&"sleep");enemy.restore_presentation()
 require(enemy.model.last_pose.state==&"sleep","Loading restores sleeping posture")
 enemy.position=Vector3(0,.01,0);enemy.brain.set_mode(&"walk",12);enemy.brain.tree=tree;enemy.brain.goal=tree.position-Vector3(0,0,enemy.brain.trunk_standoff(tree))
 game.player.position=Vector3(30,0,0);game.day_cycle.hour=12
 var fed:=false
 for frame in 420:
  enemy._physics_process(1.0/60);await physics_frame
  if enemy.model.last_pose.state==&"feed":fed=true;break
 require(fed,"An unalert enemy physically reaches the trunk and plays its existing feeding animation")
 require(enemy.brain.feeding_cooldown>enemy.brain.remaining,"Feeding has a pause before it can happen again")
 tree.health=0;enemy.brain.advance(.1,enemy.position,game.player.position,false,[tree],12)
 require(enemy.brain.mode!=&"feed","Destroyed trees cannot keep an enemy eating")
 var first:=HabitatTree.new();var second:=HabitatTree.new();var isolated:=HabitatTree.new()
 for node in [first,second,isolated]:game.add_child(node)
 first.position=Vector3(5,0,0);second.position=Vector3(6,0,0);isolated.position=Vector3(-5,0,0)
 var cluster:=0;var walks:=0
 for seed_value in 50:
  var choice:=Brain.new();choice.configure(seed_value);choice.choose_activity(Vector3.ZERO,[first,second,isolated])
  if choice.mode==&"walk":
   walks+=1
   if choice.tree!=isolated:cluster+=1
 require(walks>20 and cluster==walks,"Unalert habitat selection favours groups of trees")
 var actor=enemy.model
 for state in [&"sleep_down",&"sleep",&"wake_up"]:
  var previous:Array=[]
  for frame in 65:
   actor.animate(state,frame/64.0,true)
   for bone in actor.parents.size():
    if actor.parents[bone]<0:continue
    var parent:int=actor.parents[bone]
    require(absf(actor.posed[parent].origin.distance_to(actor.posed[bone].origin)-actor.rest[parent].origin.distance_to(actor.rest[bone].origin))<.00003,"Native sleep preserves original bone lengths")
   if not previous.is_empty():
    for bone in actor.posed.size():require(actor.posed[bone].basis.get_rotation_quaternion().angle_to(previous[bone].basis.get_rotation_quaternion())<.65,"Sleep and wake are continuous")
   previous=actor.posed.duplicate()
 game.free();print("%s: %d damage gate, sleep clock, wake perception, rest, habitat, feeding and anatomy checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
