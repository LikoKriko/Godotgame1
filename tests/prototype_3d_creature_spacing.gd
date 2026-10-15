extends SceneTree
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();game.use_test_layout=true;root.add_child(game)
 game.paused=true;game.player.set_physics_process(false)
 for enemy in get_nodes_in_group("prototype_enemies"):enemy.set_physics_process(false)
 var actors:Array=[]
 for i in 3:
  var enemy=load("res://scripts/prototype_3d/young_enemy.gd").new();game.add_child(enemy);enemy.configure(game);enemy.set_physics_process(false);actors.append(enemy)
  require(enemy.collision_mask&8!=0 and enemy.collision_mask&35==35,"Creatures block one another and retain environment/player/building collisions")
  var bounds:AABB=enemy.model.mesh_node.mesh.get_aabb()
  var radius:float=maxf(maxf(absf(bounds.position.x),absf(bounds.end.x)),maxf(absf(bounds.position.z),absf(bounds.end.z)))*enemy.model.scale.x
  require(is_equal_approx(enemy.body_radius,radius*1.02),"Body footprint includes two percent of model radius")
 var a=actors[0];var b=actors[1];var c=actors[2]
 a.position=Vector3(10,0,10);b.position=Vector3(10,0,12);c.position=Vector3(12,0,10)
 await physics_frame
 require(a.obstacle(Vector3.BACK)==false,"Distant creature does not trigger avoidance")
 b.position=Vector3(10,0,10+a.body_radius+b.body_radius+.05)
 await physics_frame
 require(a.obstacle(Vector3.BACK),"Nearby creature is detected for steering")
 # Godot allows millimetric contact penetration; this stays below the 2%
 # model clearance (about 2 cm between these two bodies).
 for frame in 150:
  a.velocity=Vector3(0,-1,1.7);a.move_and_slide()
  b.velocity=Vector3(0,-1,-1.7);b.move_and_slide()
  c.velocity=c.position.direction_to(a.position)*1.7;c.velocity.y=-1;c.move_and_slide()
  await physics_frame
  for pair in [[a,b],[a,c],[b,c]]:
   var delta:Vector3=pair[0].position-pair[1].position
   require(Vector2(delta.x,delta.z).length()>=pair[0].body_radius+pair[1].body_radius-.01,"Converging creatures never overlap their physical footprints: gap %f y %f"%[Vector2(delta.x,delta.z).length()-pair[0].body_radius-pair[1].body_radius,delta.y])
 # A stopped/stunned creature remains solid to moving ones.
 b.position=Vector3(10,0,10);a.position=Vector3(10,0,12);c.position=Vector3(14,0,14)
 await physics_frame
 for frame in 90:
  a.velocity=Vector3(0,-1,-1.7);a.move_and_slide();await physics_frame
 require(a.position.z-b.position.z>=a.body_radius+b.body_radius-.01,"Stationary creature cannot be walked through")
 # The larger footprint must not strand the enemy outside its attack trigger.
 game.paused=false;game.player.position=Vector3(10,0,10)
 a.position=Vector3(10,0,10+a.body_radius+.205);b.position=Vector3(14,0,10)
 a._physics_process(1.0/60)
 require(a.rise_elapsed>=0 or a.attack_elapsed>=0,"Enemy can initiate attacks from its new physical stopping distance")
 # Exercise the production chase/steering/attack loop with three pursuers.
 var spacing:float=a.body_radius*2+.2
 a.position=Vector3(10-spacing,0,13);b.position=Vector3(10,0,13);c.position=Vector3(10+spacing,0,13)
 for actor in actors:actor.attack_elapsed=-1;actor.rise_elapsed=-1
 for frame in 180:
  for actor in actors:actor._physics_process(1.0/60)
  await physics_frame
  for pair in [[a,b],[a,c],[b,c]]:
   var offset:Vector3=pair[0].position-pair[1].position
   require(Vector2(offset.x,offset.z).length()>=pair[0].body_radius+pair[1].body_radius-.01,"Production pursuit preserves creature spacing")
 game.free();print("%s: %d creature spacing checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
