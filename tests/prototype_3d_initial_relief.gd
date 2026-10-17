extends SceneTree
const Relief=preload("res://scripts/prototype_3d/initial_relief.gd")
var failures:=0
var checks:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 require(Relief.height(Vector2(0,2))==0.0,"Spawn remains flat")
 require(Relief.height(Vector2(23,-66))>7.9,"A small eight metre mountain is present")
 require(Relief.height(Vector2(192,-128))==0.0,"Fixed story zone keeps its original elevation")
 for x in range(-56,57,4):
  require(absf(Relief.height(Vector2(x,-112)))<.00001 and absf(Relief.height(Vector2(x,28)))<.00001,"North and south borders join the flat floor")
 for z in range(-112,29,4):
  require(absf(Relief.height(Vector2(-56,z)))<.00001 and absf(Relief.height(Vector2(56,z)))<.00001,"East and west borders join the flat floor")
 var grade:float=rad_to_deg(atan((Relief.height(Vector2(0,-35))-Relief.height(Vector2(0,-20)))/15.0))
 require(absf(grade-5.0)<.6,"Path contains a five degree average slope")
 var support_records:Array=[{"kind":1,"position":Vector3(24,0,-58)},{"kind":2,"height":3.0,"position":Vector3(25.5,0,-58)}]
 var supports:=Relief.prepare_supports(support_records)
 for bucket:Array in supports.values():
  for pad in bucket:
   require(absf(pad.core-pad.radius-pad.radius*2*.05)<.00001,"Support extends five percent of the diameter in every horizontal direction")
   for direction in 16:
    var point:Vector2=pad.point+Vector2.from_angle(direction*TAU/16)*pad.core*.99
    require(absf(Relief.height(point,supports)-pad.altitude)<.001,"The entire expanded support is flat")
 require(absf(Relief.height(Vector2(24,-58),supports)-Relief.height(Vector2(25.5,-58),supports))<.0001,"Overlapping bases share one stable elevation")
 var world:=Node3D.new();root.add_child(world)
 var ground:=StaticBody3D.new();world.add_child(ground);Relief.install_collision(ground,Rect2(-3200,-3200,6400,6400))
 await physics_frame;await physics_frame
 var space:=world.get_world_3d().direct_space_state
 for z in range(-110,27,3):
  for x in range(-54,55,3):
   var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,15,z),Vector3(x,-2,z)))
   require(not hit.is_empty(),"Terrain collision contains no holes")
   if not hit.is_empty():require(absf(hit.position.y-Relief.height(Vector2(x,z)))<.035,"Rendered and physical terrain agree at grid vertices")
 for point:Vector2 in [Vector2(-60,0),Vector2(60,0),Vector2(0,30),Vector2(0,-120),Vector2(192,-128)]:
  var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(point.x,15,point.y),Vector3(point.x,-2,point.y)))
  require(not hit.is_empty() and absf(hit.position.y)<.001,"Original flat floor remains intact outside the test")
 world.free()
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate()
 game.world_ready.connect(func():game.paused=true)
 root.add_child(game)
 var deadline:=Time.get_ticks_msec()+60000
 while game.loading_state and Time.get_ticks_msec()<deadline:await process_frame
 require(not game.loading_state,"Real world finishes loading with relief")
 if not game.loading_state:
  game.set_physics_process(false);game.player.set_physics_process(false)
  require(get_nodes_in_group("prototype_buildings").is_empty(),"Original spawn houses are absent")
  var content=game.environment_content
  for record in content.resource_nodes.values():
   var point:=Vector2(record.position.x,record.position.z)
   require(absf(record.position.y-Relief.height(point,content.stream_layout.relief_supports))<.001,"Resources follow terrain height")
  await physics_frame
  for bucket:Array in content.stream_layout.relief_supports.values():
   for pad in bucket:
    var hit:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(pad.point.x,20,pad.point.y),Vector3(pad.point.x,-2,pad.point.y)))
    require(not hit.is_empty() and hit.position.y>=pad.altitude-.05,"Support pads have physical ground at their defined elevation")
  var key:=Vector2i(0,-2);var expected:Dictionary=content.stream_layout.chunk(key)
  var builder=preload("res://scripts/prototype_3d/chunk_builder.gd").new();builder.configure(content.stream_layout);builder.request(key)
  var ready:Dictionary={}
  while ready.is_empty():ready=builder.collect();await process_frame
  require(ready.data.resources==expected.resources and ready.data.grass==expected.grass,"Worker and main thread agree on relief placement")
  for tuft in expected.grass:
   require(absf(tuft.ground_y-Relief.height(tuft.position*content.UNIT,content.stream_layout.relief_supports))<.001,"Grass follows relief height")
  builder.finish()
  # Walk a real capsule through the ramp and bumpy path, under gravity.
  var walker:=CharacterBody3D.new();var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.25;capsule.height=1.75;shape.shape=capsule;shape.position.y=.875;walker.add_child(shape);game.add_child(walker)
  walker.floor_snap_length=.3;walker.position=Vector3(Relief.path_x(-12),.3,-12)
  for step in 480:
   await physics_frame
   walker.velocity=Vector3(0,walker.velocity.y-18.0/60.0,-4)
   walker.move_and_slide()
  require(walker.position.z< -40 and walker.position.y>1.0,"A character capsule can traverse the bumpy five degree slope")
  require(walker.position.y>=Relief.height(Vector2(walker.position.x,walker.position.z))-.15,"Walking does not sink through the relief")
  walker.free()
  var save_api=preload("res://scripts/prototype_3d/save_game.gd")
  var legacy:Dictionary=save_api.capture(game)
  legacy.player.position=[23,.1,-66];legacy.enemies[0].position=[20,.1,-60];legacy.enemies[0].phase=.37
  require(save_api.restore(game,legacy),"A flat-world save restores through the supported save path")
  game.ensure_terrain_clearance()
  require(game.player.position.x==23 and game.player.position.z== -66 and game.player.position.y>game.surface_height(game.player.position),"Legacy player position rises out of the hill without horizontal displacement")
  var actor=get_nodes_in_group("prototype_enemies")[0]
  require(actor.position.y>game.surface_height(actor.position) and absf(actor.phase-.37)<.0001,"Legacy creatures rise to the ground without losing action phase")
 game.free();await process_frame
 print("%s: %d initial relief checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
