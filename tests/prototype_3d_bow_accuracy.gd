extends SceneTree
var failures:=0
var checks:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();game.use_test_layout=true;root.add_child(game)
 game.set_physics_process(false);game.player.set_physics_process(false)
 for enemy in get_nodes_in_group("prototype_enemies"):enemy.set_physics_process(false)
 var actor=game.player.model;actor.family_override=&"bow";actor.nock_visible=true
 var bow=actor.held_props[&"bow"]
 for point:Vector3 in [Vector3(0,0,45),Vector3(-8,12,70),Vector3(8,42,100),Vector3(0,55,800),Vector3(30,32,1600)]:
  actor.aim_contact=point
  for frame in 6:
   actor.animate(&"draw",frame/5.0,true)
   var nock:Vector3=actor.to_local(bow.nocked.global_position)
   var forward:Vector3=(actor.global_basis.inverse()*bow.nocked.global_basis.z).normalized()
   require(forward.dot(nock.direction_to(point))>0.99999,"Visible nocked arrow tracks target at near/far distances throughout draw")
   require(actor.grip_error<0.045,"Both bow hands remain anatomically reachable")
 actor.aim_contact=Vector3(0,0,45);actor.animate(&"draw",1,true)
 var near_pitch:float=bow.global_basis.z.normalized().y
 actor.aim_contact=Vector3(0,46,1600);actor.animate(&"draw",1,true)
 require(near_pitch<bow.global_basis.z.normalized().y-0.25,"Close ground aim tilts the bow downward")
 game.player.position=Vector3(12,0,12);game.player.model.rotation.y=PI
 game.bag.select_tool(&"bow");game.player.equipped=true;game.player.equip_elapsed=-1;game.bag.add(&"flecha",2)
 var target:=StaticBody3D.new();game.add_child(target);target.position=Vector3(12,1.1,-60)
 var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(0.8,0.8,0.1);collision.shape=box;target.add_child(collision)
 game.camera_rig.update(1);game.camera_rig.camera.look_at(target.position)
 for i in 2:await physics_frame
 require(game.player.strike(),"Bow starts its half-second draw")
 var old_target:Vector3=game.player.action_point
 target.position.x+=2
 game.camera_rig.camera.look_at(target.position)
 for i in 2:await physics_frame
 var reticle:Dictionary=game.camera_rig.target()
 require(not reticle.is_empty() and reticle.collider==target,"Reticle selects actual target beyond old 30m range")
 game.player.advance_action(0.5)
 require(game.player.action_point.distance_to(old_target)>1,"Draw follows a moved reticle until release")
 var arrows=get_nodes_in_group("player_arrows_3d")
 require(arrows.size()==1,"One completed draw releases exactly one arrow")
 require(game.player.bow_follow_elapsed==0,"The shot starts its visual follow-through at release")
 var ammunition:int=game.bag.count(&"flecha");var bow_uses:int=game.bag.held_item().uses
 game.player._physics_process(.02)
 require(game.player.model.last_pose.clip_state==&"bow_release","The live player displays the release after the draw")
 require(game.bag.count(&"flecha")==ammunition and game.bag.held_item().uses==bow_uses,"Visual follow-through spends no extra arrow or durability")
 require(game.player.strike(),"Visual follow-through cannot add a cooldown to the next draw")
 game.player.cancel_action()
 if arrows.size()==1:
  var arrow=arrows[0];arrow.set_physics_process(false)
  var toward:Vector3=reticle.position-arrow.global_position
  require(toward.normalized().dot(arrow.direction)>0.999999,"Projectile line passes exactly through the visible reticle contact")
  var sample:Vector3=arrow.global_position+arrow.direction*25
  arrow.travel(25)
  require(arrow.global_position.distance_to(sample)<0.0001,"Arrow stays straight with no gravity")
  arrow.travel(75)
  require(arrow.is_queued_for_deletion(),"Swept projectile reaches the distant solid target")
 var arrow=preload("res://scripts/prototype_3d/arrow.gd").new();game.add_child(arrow);arrow.set_physics_process(false)
 arrow.configure(game,Vector3(0,30,0),Vector3(100,30,0));arrow.travel(200)
 require(arrow.is_queued_for_deletion() and absf(arrow.global_position.x-100)<0.001,"Unobstructed projectile disappears at exactly 100m without overshooting")
 game.free();print("%s: %d bow alignment, live reticle and straight-flight checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
