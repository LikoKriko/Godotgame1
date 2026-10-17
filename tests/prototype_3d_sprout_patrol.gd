extends SceneTree
const Enemy=preload("res://scripts/prototype_3d/sprout_enemy.gd")
const Save=preload("res://scripts/prototype_3d/save_game.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run() -> void:
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();game.use_test_layout=true;root.add_child(game);game.paused=true
 await physics_frame
 require(game.item_catalog.sprout_button.text=="Añadir enemigo3","K catalogue exposes the new enemy")
 game.item_catalog.sprout_button.pressed.emit()
 var actors:=get_nodes_in_group("prototype_sprouts")
 require(actors.size()==1,"Real menu button spawns one enemy3")
 if actors.is_empty():game.free();quit(1);return
 var blocker:=StaticBody3D.new();var blocked_shape:=CollisionShape3D.new();var blocked_box:=BoxShape3D.new();blocked_box.size=Vector3(48,2,48)
 blocked_shape.shape=blocked_box;blocker.add_child(blocked_shape);blocker.position.y=1;game.add_child(blocker);await physics_frame
 require(not game.spawn_sprout_near_player() and get_nodes_in_group("prototype_sprouts").size()==1,"Blocked routes do not spawn enemies inside obstacles")
 blocker.free();await physics_frame
 var enemy=actors[0];enemy.set_physics_process(false);enemy.run_preview_enabled=false
 var visual:MeshInstance3D=enemy.model.find_children("*","MeshInstance3D",true,false)[0]
 require(absf(visual.mesh.get_aabb().size.y*enemy.model.scale.y-.9)<.000001,"Actual mesh height scales uniformly to 0.9 m")
 require(absf(enemy.patrol.target().distance_to(enemy.patrol.origin)-20)<.000001,"Route endpoints are twenty metres apart")
 var floor_node:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(50,.2,50);shape.shape=box;floor_node.add_child(shape);floor_node.position=Vector3(100,-.1,100);root.add_child(floor_node)
 enemy.global_position=Vector3(100,.025,100);enemy.patrol.configure(enemy.global_position,Vector3(0,0,1))
 await physics_frame
 var start:Vector3=enemy.global_position;var before:Vector3=enemy.global_position
 enemy._physics_process(1.0/60)
 require(enemy.global_position==before,"K/pause freezes movement")
 game.paused=false
 var legs:=0;var was_turning:=false;var distance:=0.0;var frame:=0
 while legs<3 and frame<40000:
  var old:Vector3=enemy.global_position
  enemy._physics_process(1.0/60)
  var travelled:=Vector2(enemy.global_position.x-old.x,enemy.global_position.z-old.z).length();distance+=travelled
  require(travelled<=Enemy.SPEED/60+.00002,"No speed spike or teleport")
  if enemy.patrol.turning and not was_turning:
   require(absf(distance-20)<.003,"Each completed leg is exactly twenty metres")
   require(absf(enemy.global_position.x-start.x)<.0001,"Straight route preserves its axis")
   distance=0;legs+=1
  was_turning=enemy.patrol.turning;frame+=1
 require(legs==3,"Walk twenty metres, turn, return twenty, repeat")
 var state:Dictionary=enemy.snapshot();require(Save.valid_sprout(state),"Live patrol state validates")
 var copy:=Enemy.new();game.add_child(copy);copy.configure(game);copy.set_physics_process(false);copy.restore(state)
 require(copy.snapshot()==state,"Save state restores position, animation and turn progress")
 var invalid:=state.duplicate(true);invalid.patrol.axis=[0,0,0];require(not Save.valid_sprout(invalid),"Invalid patrol axis is rejected")
 invalid=state.duplicate(true);invalid.patrol.turn_elapsed=20;require(not Save.valid_sprout(invalid),"Invalid turn timer is rejected")
 enemy.free();copy.free();floor_node.free();game.free();await process_frame
 print("%s: %d enemy3 menu, size, patrol, physics, pause and persistence checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
