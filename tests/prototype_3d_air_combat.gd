extends SceneTree
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func key(code:int,pressed:bool) -> void:
 var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;Input.parse_input_event(event)
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();game.use_test_layout=true;root.add_child(game)
 game.set_physics_process(false);game.player.set_physics_process(false);game.settings.values.auto_run=false
 for enemy in get_nodes_in_group("prototype_enemies"):enemy.set_physics_process(false)
 var player=game.player
 for family in [&"",&"axe",&"pickaxe",&"sword"]:
  player.cancel_action();player.reset_motion_state();player.position=Vector3(12,.01,12);player.equip_elapsed=-1
  if family!=&"":game.bag.select_tool(family)
  player.equipped=family!=&""
  for frame in 12:
   player._physics_process(1.0/60);await physics_frame
  require(player.is_on_floor(),"Combat fixture stands on the real floor")
  require(player.strike(),"Grounded melee is available: "+String(family))
  var uses:int=game.bag.held_item().uses
  var next_side:int=player.next_punch_side
  key(KEY_SPACE,true);await physics_frame;await process_frame
  player._physics_process(1.0/60);await physics_frame
  require(player.velocity.y>0 and player.locomotion.airborne(),"Jump actually leaves the floor")
  require(player.action_elapsed<0 and not player.contact_done,"Taking off cancels melee before its impact")
  require(player.model.last_pose.clip_state==&"jump","Jump pose replaces the cancelled attack immediately")
  for frame in 5:
   require(not player.strike() and player.action_elapsed<0,"Airborne clicks cannot start melee: "+String(family))
   player._physics_process(1.0/60);await physics_frame
  require(player.next_punch_side==next_side and game.bag.held_item().uses==uses,"Rejected attacks consume neither punch alternation nor durability")
  # Defensive impact gate also covers restored/injected windups in the air.
  player.action_family=family;player.action_elapsed=0;player.contact_done=false
  player.advance_action(player.Clips.duration(&"action",family))
  require(player.action_elapsed<0 and not player.contact_done,"Airborne melee never reaches damage resolution")
  key(KEY_SPACE,false);await physics_frame;await process_frame
  for frame in 65:
   player._physics_process(1.0/60);await physics_frame
  require(player.is_on_floor() and not player.locomotion.airborne(),"Landing restores actual ground contact")
  require(player.strike(),"Melee becomes available again on landing")
 player.cancel_action();player.reset_motion_state();player.position=Vector3(12,4,12)
 player.velocity=Vector3.DOWN;player.move_and_slide()
 require(not player.is_on_floor() and not player.locomotion.airborne(),"Falling fixture is airborne without a timed jump")
 require(not player.strike(),"Stepping off a ledge also blocks melee")
 game.bag.select_tool(&"bow");game.bag.add(&"flecha",3);player.equipped=true
 require(player.strike(),"Bow can begin drawing while falling")
 var count:int=get_nodes_in_group("player_arrows_3d").size()
 var ammunition:int=game.bag.count(&"flecha")
 player.advance_action(.5)
 require(get_nodes_in_group("player_arrows_3d").size()==count+1 and game.bag.count(&"flecha")==ammunition-1,"Airborne bow draw releases exactly one arrow")
 player.cancel_action();player.reset_motion_state();player.position=Vector3(12,.01,12)
 for frame in 12:
  player._physics_process(1.0/60);await physics_frame
 require(player.strike(),"Grounded bow draw begins")
 key(KEY_SPACE,true);await physics_frame;await process_frame
 player._physics_process(1.0/60);await physics_frame
 require(player.locomotion.airborne() and player.action_elapsed>=0 and player.model.last_pose.clip_state==&"draw","Jumping preserves the bow draw")
 count=get_nodes_in_group("player_arrows_3d").size();player.advance_action(.5)
 require(get_nodes_in_group("player_arrows_3d").size()==count+1,"A draw started before jumping can finish in the air")
 key(KEY_SPACE,false);player.cancel_action();game.free()
 print("%s: %d grounded melee, takeoff cancellation, landing and airborne bow checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
