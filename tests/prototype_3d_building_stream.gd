extends SceneTree
var failures:=0
func require(value:bool,message:String) -> void:
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func pump(stream,point:Vector3) -> void:
 for frame in 120:
  stream.update_stream(point)
  if stream.interior_ready:return
  await process_frame
func run():
 var building=preload("res://scripts/prototype_3d/building_stream.gd").new()
 building.fragments.assign(["res://tests/fixtures/prototype_stream_interior.tscn"])
 root.add_child(building);building.position=Vector3(30,0,-10)
 building.update_stream(Vector3(-100,0,0))
 require(not building.active and building.content==null,"Distant interiors are not instantiated")
 await pump(building,building.global_position+Vector3(0,0,15))
 require(building.interior_ready and building.progress()==1,"Approach prepares the interior progressively")
 require(building.content.get_child_count()==1,"Interior fragments instantiate only once")
 require(building.content.get_world_3d()==building.get_world_3d(),"Interior shares exterior world without changing scenes")
 building.update_stream(building.global_position+Vector3(0,0,22))
 require(building.interior_ready,"Unload hysteresis prevents repeated loading near the boundary")
 building.update_stream(building.global_position+Vector3(0,0,30))
 require(not building.interior_ready and building.content==null,"Leaving unload distance releases interior nodes")
 await process_frame
 await pump(building,building.global_position+Vector3(0,0,2))
 require(building.can_enter(),"Returning reloads and opens entry only when complete")
 building.update_stream(building.to_global(Vector3(0,0,-2)))
 require(building.interior_ready,"Occupied interior stays loaded")
 building.free();print("%s: same-world interior streaming and hysteresis"%["PASS" if failures==0 else "FAIL"]);quit(1 if failures else 0)
