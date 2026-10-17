extends SceneTree
const Layout=preload("res://scripts/prototype_3d/stream_layout.gd")
const Save=preload("res://scripts/prototype_3d/save_game.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func settle(game) -> void:
 var deadline:=Time.get_ticks_msec()+60000
 var content=game.environment_content
 while (not content.pending.is_empty() or not content.job.is_empty() or not content.retiring.is_empty() or not game.terrain.pending.is_empty()) and Time.get_ticks_msec()<deadline:
  game.paused=false;content._process(0);game.terrain.advance_generation();game.paused=true
  await process_frame
 require(content.pending.is_empty() and content.job.is_empty(),"Progressive resource queue finishes")
 require(game.terrain.pending.is_empty(),"Terrain queue finishes")
func travel(game,point:Vector3) -> void:
 game.player.position=point;game.environment_content.update_observer(point,true)
 game.terrain.update_observer(point,Vector2.ONE*game.generation_radius()*2)
 await settle(game)
func run():
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate()
 game.world_ready.connect(func():game.paused=true)
 root.add_child(game)
 var deadline:=Time.get_ticks_msec()+60000
 while game.loading_state and Time.get_ticks_msec()<deadline:await process_frame
 require(not game.loading_state,"First local world finishes without generating all forty square kilometres")
 if game.loading_state:game.free();quit(1);return
 game.set_physics_process(false);game.player.set_physics_process(false);game.distance_optimization.set_process(false)
 for enemy in get_nodes_in_group("prototype_enemies"):enemy.set_physics_process(false)
 var content=game.environment_content;content.set_process(false)
 var story_id:String=content.stream_layout.reservations.records[0].id
 require(content.story_zones.active.has(story_id),"The initial local window contains its nearby authored zone")
 require(game.world_bounds==Layout.BOUNDS and game.world_bounds.get_area()>=40000000,"Playable world covers at least forty square kilometres")
 require(content.radius==200 and game.settings.values.world_generation==200,"Two hundred metres is the default generation radius")
 require(content.active.size()<400,"Initial generation remains local and bounded")
 for direction:Vector2 in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2(1,1).normalized()]:
  require(content.active.has(Layout.coordinate(Vector2(game.player.position.x,game.player.position.z)+direction*200)),"All directions are generated through the selected distance")
 for record in content.layout.records:
  require(content.resource_nodes.has(record.id),"Original starting resources remain available")
 var origin_chunk:Dictionary=content.stream_layout.chunk(Vector2i(24,-17))
 content.stream_layout.chunk(Vector2i(-90,81))
 require(var_to_str(origin_chunk)==var_to_str(content.stream_layout.chunk(Vector2i(24,-17))),"Exploration order does not change generated resources or grass")
 require(not origin_chunk.resources.is_empty(),"Distant chunks contain interactive resources")
 for record in origin_chunk.resources:
  require(content.stream_layout.record_for(record.id)==record,"Persistent ID reproduces its exact seeded record")
 require(content.stream_layout.record_for("w2:99999:99999:1").is_empty(),"Unknown or out-of-world resource IDs are rejected")
 var nearby:Array=content.resource_nodes.values().filter(func(node):return node.health>1)
 var partial=nearby[0];var depleted=nearby[1]
 var partial_id:String=partial.get_meta("resource_id");var depleted_id:String=depleted.get_meta("resource_id")
 partial.health=1;depleted.health=1;depleted.hit()
 print("Initial window: %d chunks, %d resources"%[content.active.size(),content.resource_nodes.size()])
 var central_count:int=content.active.size()
 await travel(game,Vector3(1800,.2,-1600))
 require(content.story_zones.active.is_empty(),"Normal world streaming frees distant authored zones and their collisions")
 require(not content.resource_nodes.has(partial_id) and not content.active.has(Vector2i.ZERO),"Distant starting chunks and their nodes are actually unloaded")
 require(content.active.size()<=central_count+32,"Traversing kilometres does not retain every visited chunk")
 require(content.resource_changes[partial_id]==1 and content.resource_changes[depleted_id]==0,"Unloading preserves partial damage and depletion")
 require(content.snapshot_resources().size()==2,"Only changed resources are persisted, not the unvisited world")
 game.distance_optimization.update_enemies()
 require(get_nodes_in_group("prototype_enemies")[0].distance_suspended,"The existing 150-metre enemy suspension applies to the enlarged world")
 await process_frame;game.distance_optimization.update_quality(.1)
 var sample=content.resource_nodes.values()[0]
 var graded:=false
 for entry in game.distance_optimization.entries.values():
  var node=entry.node.get_ref()
  if is_instance_valid(node) and sample.is_ancestor_of(node):graded=graded or entry.quality>0
 require(graded,"Streamed-in world meshes enter the existing distance-quality controller")
 var saved:Dictionary=Save.capture(game)
 require(Save.valid(saved) and Save.matches_world(game,saved),"Saving away from the starting map accepts remote player and unloaded-resource state")
 var path:="/tmp/day-zero-world-stream-"+str(OS.get_process_id())+".save"
 require(Save.write(game,path)==OK and Save.read_result(path).ok,"Remote world state survives the checked disk save round trip")
 var legacy:Dictionary=saved.duplicate(true);legacy.resources={}
 for record in content.layout.records:legacy.resources[record.id]=record.hits
 require(Save.valid(legacy) and Save.matches_world(game,legacy),"Existing saves containing the full original resource table remain compatible")
 require(Save.in_world([3100,0,-3100]) and not Save.in_world([3201,0,0]),"Save validation uses the enlarged playable boundaries")
 var malformed:Dictionary=saved.duplicate(true);malformed.resources["w2:99999:0:0"]=0
 require(not Save.matches_world(game,malformed),"Seed validation rejects invented resource records")
 var option:OptionButton=game.settings_panel.find_child("WorldGeneration",true,false)
 require(option!=null and option.item_count==3,"Graphics settings expose all three generation distances")
 var counts:Dictionary={}
 for radius in [100,400,200]:
  game.settings.values.world_generation=radius;game.settings.changed.emit()
  await settle(game)
  counts[radius]=content.active.size()
  print("Radius %d: %d active chunks, %d resources"%[radius,content.active.size(),content.resource_nodes.size()])
  require(content.radius==radius,"Generation radius updates live to "+str(radius))
 require(counts[100]<counts[200] and counts[200]<counts[400],"The setting changes the generated window rather than only changing a label")
 await travel(game,Vector3(0,.2,2))
 require(content.story_zones.active.size()==1 and content.story_zones.active[story_id].complete,"Returning regenerates one complete authored zone without duplicating its root")
 require(content.resource_nodes[partial_id].health==1,"Partial damage survives unload and regeneration")
 require(content.resource_nodes[depleted_id].health==0 and not content.resource_nodes[depleted_id].visible,"Harvested resources do not respawn when revisiting")
 var original_changes:Dictionary=content.snapshot_resources()
 require(Save.restore(game,saved),"Full save restoration accepts unloaded changes outside the currently loaded window")
 require(content.snapshot_resources()==original_changes,"Restoration retains sparse changes without losing unvisited resources")
 var count_before:int=content.generation_count
 game.free();await process_frame
 var resumed=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();resumed.initial_state=saved.duplicate(true)
 resumed.world_ready.connect(func():resumed.paused=true);root.add_child(resumed)
 deadline=Time.get_ticks_msec()+60000
 while resumed.loading_state and Time.get_ticks_msec()<deadline:await process_frame
 require(not resumed.loading_state and resumed.player.position==Save.point(saved.player.position),"Continue generates the saved remote surroundings before releasing the player")
 require(resumed.environment_content.resource_changes==saved.resources,"Remote reload preserves changes to unloaded starting chunks")
 require(resumed.environment_content.story_zones.active.is_empty(),"Remote continuation does not load an unrelated distant story zone")
 require(not resumed.environment_content.active.has(Vector2i.ZERO),"Remote reload does not instantiate the starting settlement across the world")
 require(resumed.environment_content.generation_count<count_before,"Continue generates only the saved window, not every explored zone")
 resumed.free()
 for suffix in ["",".bak",".tmp"]:
  if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
 print("%s: %d procedural world, bounded streaming, graphics and remote-save checks"%["PASS" if failures==0 else "FAIL",checks])
 quit(1 if failures else 0)
