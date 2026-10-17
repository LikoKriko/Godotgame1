extends SceneTree
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();game.use_test_layout=true;root.add_child(game)
 game.paused=true;game.player.set_physics_process(false)
 var player=game.player
 player.position=Vector3(12,0,12)
 for armed in [false,true]:
  player.equipped=armed
  for direction in 16:
   var offset:=Vector3(sin(direction*TAU/16),0,cos(direction*TAU/16))
   require(player.can_reach_contact(player.position+offset*0.999+Vector3.UP),"Hit inside one metre works at every yaw, armed or unarmed")
   require(not player.can_reach_contact(player.position+offset*1.01+Vector3.UP),"Hits beyond one metre are rejected")
 require(not player.can_reach_contact(player.position+Vector3.UP*10),"Horizontal reach cannot hit distant overhead targets")
 var rock=preload("res://scripts/prototype_3d/rock.gd").new();game.add_child(rock);rock.configure();rock.position=Vector3(12,0,8)
 await physics_frame
 var physical:CollisionShape3D=rock.get_child(0)
 var from:Vector3=rock.position+Vector3(physical.shape.size.x*.5+.1,physical.position.y,2)
 var query:=PhysicsRayQueryParameters3D.create(from,from+Vector3.FORWARD*4,25);query.collide_with_areas=true
 var result:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(query)
 require(not result.is_empty() and game.target_owner(result.collider)==rock,"Aiming beside the imported rock collider now selects the enlarged hitbox")
 query.collision_mask=1;query.collide_with_areas=false
 require(game.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"Expanded rock hitbox does not block walking")
 rock.hit();rock.hit();rock.hit();rock.hit()
 await physics_frame
 query.collision_mask=25;query.collide_with_areas=true
 require(game.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"Depleted rock removes its expanded hitbox")
 for tree in get_nodes_in_group("prototype_trees"):
  var area:Area3D=null
  for child in tree.get_children():
   if child is Area3D and child.get_meta("resource",null)==tree:area=child
  require(area!=null and area.get_child_count()>0,"Every tree has expanded impact capsules")
 for enemy in get_nodes_in_group("prototype_enemies"):
  enemy.set_physics_process(false)
  require(is_equal_approx(enemy.hurt_shapes[0].shape.radius,.37),"Enemy animated hitboxes include fifteen centimetres of tolerance")
 game.free();print("%s: %d hitbox checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
