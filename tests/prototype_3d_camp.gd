extends SceneTree
var failures:=0
var checks:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();root.add_child(game)
 var start:=Time.get_ticks_msec()
 while game.loading_state and Time.get_ticks_msec()-start<30000:await process_frame
 require(not game.loading_state,"Camp finishes loading progressively")
 game.paused=true;game.player.set_physics_process(false)
 var buildings=get_nodes_in_group("prototype_buildings")
 require(buildings.size()==6,"All six original camp buildings have 3D exteriors")
 for building in buildings:
  var footprint:=Rect2(Vector2(building.position.x-building.width*0.5,building.position.z-building.depth*0.5),Vector2(building.width,building.depth))
  var clear:=true
  for record in game.environment_content.layout.records:
   if footprint.grow(0.2).has_point(Vector2(record.position.x,record.position.z)):clear=false
  require(clear,"Camp footprint remains clear of generated resource centers")
 for a in buildings.size():
  for b in range(a+1,buildings.size()):
   var delta:Vector3=buildings[a].position-buildings[b].position
   var horizontal:float=absf(delta.x)-(buildings[a].width+buildings[b].width)*0.5
   var vertical:float=absf(delta.z)-(buildings[a].depth+buildings[b].depth)*0.5
   require(maxf(horizontal,vertical)>=maxf(buildings[a].width,buildings[b].width),"Buildings retain at least a building-width gap")
 var home=buildings[0];var stream=home.stream
 game.player.global_position=home.global_position+stream.door_offset+Vector3(0,0,2)
 start=Time.get_ticks_msec()
 while not stream.interior_ready and Time.get_ticks_msec()-start<5000:await process_frame
 require(stream.interior_ready and stream.content.get_child_count()==1,"Approach streams the empty room in the exterior world")
 require(stream.content.scale==Vector3((home.width-0.18)/4,1,(home.depth-0.18)/4),"Room floor matches the real building footprint")
 for i in 3:await physics_frame
 require(stream.guard_shape.disabled,"Entrance unlocks only after interior is ready")
 var before:Vector3=home.global_position+stream.door_offset+Vector3(0,1,-0.3)
 var after:Vector3=before+Vector3(0,0,0.6)
 var query:=PhysicsRayQueryParameters3D.create(before,after,32)
 require(not game.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"Door retains a wildlife-only safety barrier")
 game.player.global_position=home.global_position+Vector3.UP*0.02
 for i in 2:await process_frame
 require(not home.curtain.visible,"Inside observers have a clear view of their room")
 require(stream.interior_bounds.has_point(home.to_local(game.player.global_position)),"Door crossing changes position in the same world without teleport")
 game.player.global_position=home.global_position+Vector3(35,0,35)
 for i in 4:await process_frame
 require(not stream.active and stream.content==null,"Distant unoccupied interior releases its nodes")
 game.free();print("%s: %d 3D camp, same-world interior and unloading checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
