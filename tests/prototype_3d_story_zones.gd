extends SceneTree
const Catalogue=preload("res://scripts/prototype_3d/story_zone_catalog.gd")
const Layout=preload("res://scripts/prototype_3d/stream_layout.gd")
const Stream=preload("res://scripts/prototype_3d/story_zone_stream.gd")
const Save=preload("res://scripts/prototype_3d/save_game.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func finish(stream) -> void:
 var steps:=0
 while stream.busy() and steps<1000:stream.advance();steps+=1
 require(not stream.busy(),"Story-zone build queue terminates")
func signature(holder:Node3D) -> Dictionary:
 var result:Dictionary={}
 for child in holder.get_children():
  var visual:MeshInstance3D=child.get_child(0)
  result[str(child.name)]={"transform":child.global_transform,"size":visual.mesh.size,"color":visual.material_override.albedo_color,"solid":child.get_child_count()==2}
 return result
func run():
 var catalogue:=Catalogue.new();var definitions:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Catalogue.PATH))
 require(catalogue.records.size()==1 and Catalogue.BOUNDS==Layout.BOUNDS,"The fixed catalogue is valid and fits the playable map")
 var zone:Dictionary=catalogue.records[0]
 require(zone.position==Vector3(192,0,-128) and zone.rect.size==Vector2(32,24) and zone.buffer==8,"The example has exact authored coordinates, size and clearance")
 for change in ["duplicate","outside","box","overlap","floor","nan"]:
  var invalid:Array=definitions.zones.duplicate(true)
  if change=="duplicate":invalid.append(invalid[0].duplicate(true))
  elif change=="outside":invalid[0].position=[3200,0,3200]
  elif change=="box":invalid[0].boxes[0].offset=[1000,0,0]
  elif change=="floor":invalid[0].boxes[0].id="floor"
  elif change=="overlap":var other:Dictionary=invalid[0].duplicate(true);other.id="other_zone";invalid.append(other)
  else:invalid[0].position[0]=NAN
  require(not catalogue.configure(invalid) and catalogue.records[0].position==zone.position,"Invalid catalogues are rejected atomically: "+change)
 require(not catalogue.allows(zone.reserved.end+Vector2(.25,-1),.5),"Footprint clearance catches a centre outside the reservation")
 require(catalogue.allows(zone.reserved.end+Vector2(2,-1),.5),"Items beyond their full footprint can still be generated")
 var rock:Mesh=preload("res://assets/models/meshy/rock1/model.res")
 var rock_box:=rock.get_aabb()
 require(maxf(maxf(absf(rock_box.position.x),absf(rock_box.end.x)),maxf(absf(rock_box.position.z),absf(rock_box.end.z)))<=Catalogue.resource_radius({"kind":1}),"Reservation footprint encloses the actual imported rock")
 for design in 9:
  for variant in 4:
   var tree:Mesh=preload("res://scripts/prototype_3d/tree_geometry.gd").new().build(design,variant)
   var bounds:=tree.get_aabb()
   var extent:=maxf(maxf(absf(bounds.position.x),absf(bounds.end.x)),maxf(absf(bounds.position.z),absf(bounds.end.z)))
   require(extent<=Catalogue.resource_radius({"kind":2,"height":bounds.end.y}),"Every tree silhouette fits its conservative reservation footprint")
 for variant in 15:
  var grass:Mesh=preload("res://scripts/prototype_3d/ground_cover.gd").mesh_for(variant)
  for point:Vector3 in grass.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:require(Vector2(point.x,point.z).length()<=.4,"Grass footprint remains safe under arbitrary tuft rotation")
 var removed:=0;var grass_removed:=0;var outside_variations:Dictionary={};var legacy:Dictionary={}
 for seed in [73129,1,42,917,2741,99173]:
  var sampler=preload("res://scripts/terrain_sampler.gd").new();sampler.configure(seed,preload("res://scripts/terrain_profile.gd").new())
  var layout:=Layout.new();layout.configure(seed,sampler)
  require(layout.reservations.by_id[zone.id].position==zone.position,"Story coordinates do not change with seed "+str(seed))
  var first:=Layout.coordinate(zone.reserved.position-Vector2.ONE*8);var last:=Layout.coordinate(zone.reserved.end+Vector2.ONE*8)
  for y in range(first.y,last.y+1):
   for x in range(first.x,last.x+1):
    var key:=Vector2i(x,y);var raw:Dictionary=layout.chunk(key,true,true);var protected:Dictionary=layout.chunk(key)
    var ids:Dictionary={}
    for record in protected.resources:
     ids[record.id]=record;require(catalogue.allows_resource(record),"Every visible resource footprint avoids the reserve")
    for record in raw.resources:
     if catalogue.allows_resource(record):require(ids.get(record.id,{})==record,"Reservations preserve outside IDs, positions, types and rewards")
     else:
      removed+=1;require(not ids.has(record.id),"Protected footprints remove overlapping resources")
      require(layout.record_for(record.id)==record,"Legacy saved IDs remain valid inside a newly reserved zone")
      if seed==73129:legacy[record.id]=0
    grass_removed+=raw.grass.size()-protected.grass.size()
    for tuft in protected.grass:require(catalogue.allows_grass(tuft),"No grass tuft overlaps the fixed area or its margin")
  var distant:Dictionary=layout.chunk(Vector2i(24,-17));layout.chunk(Vector2i(-50,90))
  require(var_to_str(distant)==var_to_str(layout.chunk(Vector2i(24,-17))),"Exploration order remains deterministic")
  outside_variations[var_to_str(distant)]=true
  if seed==73129:
   var builder=preload("res://scripts/prototype_3d/chunk_builder.gd").new();builder.configure(layout);builder.request(first)
   var ready:Dictionary={};var deadline:=Time.get_ticks_msec()+5000
   while ready.is_empty() and Time.get_ticks_msec()<deadline:ready=builder.collect();await process_frame
   require(not ready.is_empty(),"The background worker finishes a reserved chunk")
   if not ready.is_empty():require(ready.data.resources==layout.chunk(first).resources and ready.data.grass==layout.chunk(first).grass,"The worker receives the same reservations as synchronous generation")
   builder.finish()
 require(removed>0 and grass_removed>0 and outside_variations.size()>1,"Several seeds remain different outside the fixed zone and remove actual overlaps")
 var stream:=Stream.new();stream.configure(catalogue);root.add_child(stream)
 var edge:=Rect2(zone.reserved.position-Vector2.ONE,Vector2.ONE*2)
 stream.update_window(edge);finish(stream)
 require(stream.active.size()==1 and stream.active[zone.id].node.position==zone.position,"A zone loads when its edge is nearby, even if its centre is in another chunk")
 var original:=signature(stream.active[zone.id].node)
 require(original.size()==zone.boxes.size()+1,"One ground pad and each placeholder appear once")
 stream.update_window(edge);finish(stream)
 require(stream.active.size()==1 and signature(stream.active[zone.id].node)==original,"Repeated chunk windows never duplicate a story zone")
 stream.update_window(Rect2(Vector2(2000,2000),Vector2.ONE*100));finish(stream)
 require(stream.active.is_empty(),"Far story nodes and collisions are freed")
 stream.update_window(edge);finish(stream)
 require(signature(stream.active[zone.id].node)==original,"Revisiting reproduces every transform, dimension and colour")
 stream.free()
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();game.world_ready.connect(func():game.paused=true);root.add_child(game)
 var timeout:=Time.get_ticks_msec()+90000
 while game.loading_state and Time.get_ticks_msec()<timeout:await process_frame
 require(not game.loading_state,"The actual initial world waits for its story boxes")
 if game.loading_state:game.free();quit(1);return
 game.set_physics_process(false);game.player.set_physics_process(false)
 var content=game.environment_content
 require(content.story_zones.active.has(zone.id) and content.story_zones.active[zone.id].complete,"The streamed game contains its complete fixed zone")
 require(content.matches_resources(legacy),"Previous saved resource changes remain compatible with the new reserve")
 content.restore_resources(legacy)
 for id in legacy:require(not content.resource_nodes.has(id),"Legacy changes cannot respawn scenery inside the reservation")
 game.player.position=zone.position+Vector3(0,.2,0)
 var saved:Dictionary=Save.capture(game)
 require(Save.valid(saved) and Save.matches_world(game,saved),"Saving inside the zone accepts both its position and legacy resource state")
 var path:="/tmp/story-zones-"+str(OS.get_process_id())+".save"
 require(Save.write(game,path)==OK,"A real checked save stores the fixed-zone visit")
 var loaded:Dictionary=Save.read_result(path)
 require(loaded.ok,"The saved zone visit can be read back")
 game.free();await process_frame
 if loaded.ok:
  var resumed=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();resumed.initial_state=loaded.state;resumed.world_ready.connect(func():resumed.paused=true);root.add_child(resumed)
  timeout=Time.get_ticks_msec()+90000
  while resumed.loading_state and Time.get_ticks_msec()<timeout:await process_frame
  require(not resumed.loading_state and resumed.player.position==Save.point(saved.player.position),"Continue restores the saved position inside the fixed zone")
  require(resumed.environment_content.story_zones.active.has(zone.id) and signature(resumed.environment_content.story_zones.active[zone.id].node)==original,"Continue reconstructs the same authored boxes, not a seed-dependent replacement")
  require(resumed.environment_content.resource_changes==legacy,"Continue retains legacy resource state without restoring interfering scenery")
  resumed.free()
 for suffix in ["",".bak",".tmp"]:
  if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
 print("%s: %d fixed-zone, reservation, seed, streaming and save checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
