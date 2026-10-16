extends SceneTree
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();game.use_test_layout=true;root.add_child(game)
 game.paused=true;game.player.set_physics_process(false);game.camera_rig.set_process(false);game.camera_rig.set_physics_process(false)
 for enemy in get_nodes_in_group("prototype_enemies"):enemy.set_physics_process(false)
 var plant=preload("res://scripts/prototype_3d/gatherable.gd").new();game.add_child(plant);plant.configure({"kind":5,"variant":2,"hits":1,"yield":3});plant.position=Vector3(10,0,10)
 game.player.position=Vector3(10,0,10.9);game.camera_rig.update(1);game.camera_rig.camera.look_at(plant.position+Vector3.UP*0.23)
 await physics_frame
 require(not game.interact() and plant.health==1,"Burdock requires free hands")
 game.player.equipped=false;game.bag.active_quick_uid=-1
 var leaves:int=game.bag.count(&"hoja_bardana")
 require(game.interact(),"E begins the directed plant pickup")
 for frame in 60:game.player.update_facing(game.player.pickup_point,1.0/60)
 game.player.advance_preview(game.player.Clips.duration(&"pickup")*.5)
 require(game.bag.count(&"hoja_bardana")==leaves+3,"Contact collects exact variant yield")
 require(plant.health==0 and not plant.visible and plant.collision_layer==0,"Collected plant stops receiving hits")
 game.player.preview_state=&""
 var sapling=preload("res://scripts/prototype_3d/gatherable.gd").new();game.add_child(sapling);sapling.configure({"kind":4,"variant":3,"hits":2,"yield":3});sapling.position=plant.position
 game.player.position=plant.position+Vector3(0,0,0.6)
 await physics_frame
 var fibre:int=game.bag.count(&"fibra");var sticks:int=game.bag.count(&"palo")
 var contact:Dictionary={"collider":sapling,"position":sapling.position+Vector3(0,1,0.3)}
 require(game.resolve_hit(contact) and sapling.health==1,"First unarmed hit shakes sapling without rewards")
 require(game.bag.count(&"fibra")==fibre,"Partial gathering cannot duplicate resources")
 require(game.resolve_hit(contact) and sapling.health==0,"Second unarmed hit breaks sapling")
 require(game.bag.count(&"fibra")==fibre+3 and game.bag.count(&"palo")==sticks+2,"Sapling awards fibre and sticks together")
 var platform=preload("res://scripts/prototype_3d/raised_ground.gd").new();game.add_child(platform)
 platform.configure({"rect":Rect2(Vector2(320,320),Vector2(100,80)),"variant":1})
 await physics_frame
 var center:Vector3=platform.position
 var query:=PhysicsRayQueryParameters3D.create(center+Vector3.UP,center+Vector3.DOWN,1)
 var hit:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(query)
 require(not hit.is_empty() and hit.collider==platform and hit.normal.y>0.99,"Elevation has an upward physical top matching the sprite")
 game.player.position=center+Vector3.UP*0.7
 for i in 50:
  game.player.velocity=Vector3.DOWN*2;game.player.move_and_slide();await physics_frame
 require(absf(game.player.position.y-platform.height)<0.03,"Player lands and stays on the elevated top")
 # Approach the sloping skirt from the original floor and climb without jumping.
 game.player.position=center+Vector3(0,0,1.7)
 for i in 90:
  game.player.velocity=Vector3(0,0 if game.player.is_on_floor() else -2,-1);game.player.move_and_slide();await physics_frame
 require(game.player.position.y>platform.height-0.05,"Player can walk up the elevation's soil skirt")
 var obstacle:=StaticBody3D.new();game.add_child(obstacle);obstacle.position=Vector3(15,0,15);obstacle.set_meta("physical_height",0.8)
 var volume:=BoxShape3D.new();volume.size=Vector3(0.5,0.8,0.5)
 var collision:=CollisionShape3D.new();collision.shape=volume;collision.position.y=0.4;obstacle.add_child(collision)
 await physics_frame
 require(not game.can_cross_jump(Vector3(15,0,16),Vector3(0,0,-1),game.player.get_rid()),"Jump cannot bypass an obstacle taller than 30 percent of the hero")
 volume.size.y=0.4;collision.position.y=0.2;obstacle.set_meta("physical_height",0.4)
 await physics_frame
 require(game.can_cross_jump(Vector3(15,0,16),Vector3(0,0,-1),game.player.get_rid()),"Small physical objects remain jumpable")
 game.free();print("%s: %d resource pickup, punch and physical elevation checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
