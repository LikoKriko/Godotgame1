extends Node3D
signal progress_changed(value:float)
signal completed
const UNIT:=1.75/64.0
const Layout=preload("res://scripts/prototype_3d/stream_layout.gd")
var game
var stream_layout=Layout.new()
var layout
var resource_nodes:Dictionary={}
var resource_changes:Dictionary={}
var active:Dictionary={}
var pending:Array[Vector2i]=[]
var retiring:Array[Vector2i]=[]
var wanted:Dictionary={}
var job:Dictionary={}
var radius:=200
var initial_loading:=true
var last_cell:=Vector2i(999999,999999)
var total:=0
var built:=0
var generation_count:=0
func configure(owner_game,seed_value:int) -> void:
 game=owner_game;stream_layout.configure(seed_value,game.terrain.sampler);layout=stream_layout.base
 game.terrain.sampler.existing_paths=true
 for influence in layout.source.terrain_influences:game.terrain.sampler.add_influence(influence.id,&"dirt",influence.rect,0.65)
 game.terrain.refresh_influences()
 radius=int(game.settings.values.world_generation)
 update_observer(game.player.global_position,true)
func update_observer(point:Vector3,force:bool=false) -> void:
 var cell:=Layout.coordinate(Vector2(point.x,point.z))
 if not force and cell==last_cell:return
 last_cell=cell;wanted.clear()
 # Center on a cell, adding half its size to cover the full configured distance
 # even just before the player crosses the next cell boundary.
 var center:Vector2=Layout.rect(cell).get_center()
 var area:=Rect2(center-Vector2.ONE*(radius+Layout.CHUNK_SIZE*.5),Vector2.ONE*(radius*2+Layout.CHUNK_SIZE))
 var first:=Layout.coordinate(area.position);var last:=Layout.coordinate(area.end-Vector2.ONE*.001)
 for y in range(first.y,last.y+1):
  for x in range(first.x,last.x+1):
   var key:=Vector2i(x,y)
   if Layout.rect(key).intersects(Layout.BOUNDS):wanted[key]=true
 retiring.clear()
 for key in active.keys():
  # One extra chunk of retention avoids churn when pacing at a boundary.
  if not Layout.rect(key).intersects(area.grow(Layout.CHUNK_SIZE)):retiring.append(key)
 if not job.is_empty() and not wanted.has(job.key):unload_chunk(job.key);job.clear()
 pending.clear()
 for key in wanted:
  if not active.has(key):pending.append(key)
 pending.sort_custom(func(a,b):return Layout.rect(a).get_center().distance_squared_to(Vector2(point.x,point.z))<Layout.rect(b).get_center().distance_squared_to(Vector2(point.x,point.z)))
 if initial_loading:total=active.size()+pending.size()
func set_radius(value:int) -> void:
 radius=value if value in [100,200,400] else 200
 update_observer(game.player.global_position,true)
func _process(_delta:float) -> void:
 if game==null or (game.paused and not initial_loading):return
 update_observer(game.player.global_position)
 var deadline:=Time.get_ticks_usec()+4000
 while Time.get_ticks_usec()<deadline:
  if not retiring.is_empty():unload_chunk(retiring.pop_front());continue
  if job.is_empty():
   if pending.is_empty():break
   begin_chunk(pending.pop_front())
  if job.next<job.resources.size():
   spawn_resource(job.resources[job.next],active[job.key].node);job.next+=1
  else:finish_chunk();job.clear();built+=1
 if initial_loading:
  progress_changed.emit(.1+.85*float(built)/maxi(1,total))
  if pending.is_empty() and job.is_empty() and game.terrain.pending.is_empty():
   initial_loading=false;progress_changed.emit(1);completed.emit()
func begin_chunk(key:Vector2i) -> void:
 var holder:=Node3D.new();holder.name="WorldChunk_%d_%d"%[key.x,key.y];add_child(holder)
 var data:Dictionary=stream_layout.chunk(key)
 active[key]={"node":holder,"resources":data.resources}
 job={"key":key,"resources":data.resources,"grass":data.grass,"next":0};generation_count+=1
func in_chunk(point:Vector2,key:Vector2i) -> bool:return Layout.coordinate(point)==key
func finish_chunk() -> void:
 var holder:Node3D=active[job.key].node
 var grass:Array=job.grass
 if not grass.is_empty():
  var cover:=preload("res://scripts/prototype_3d/ground_cover.gd").new();holder.add_child(cover);cover.configure(grass)
 for record in layout.source.camp_buildings:
  if in_chunk(record.base*UNIT,job.key):
   var building:=preload("res://scripts/prototype_3d/camp_building.gd").new();holder.add_child(building);building.configure(game,record)
 for record in layout.source.puddles:
  if in_chunk(record.position*UNIT,job.key):
   var water:=preload("res://scripts/prototype_3d/water_source.gd").new();water.radius=record.width*UNIT*.5;holder.add_child(water);water.position=Vector3(record.position.x*UNIT,0,record.position.y*UNIT)
 for record in layout.source.platforms:
  if in_chunk(record.rect.get_center()*UNIT,job.key):
   var platform:=preload("res://scripts/prototype_3d/raised_ground.gd").new();holder.add_child(platform);platform.configure(record)
func remember(node:Node3D) -> void:
 var id:String=node.get_meta("resource_id")
 if node.health!=node.get_meta("initial_health"):resource_changes[id]=node.health
 else:resource_changes.erase(id)
func snapshot_resources() -> Dictionary:
 for node in resource_nodes.values():remember(node)
 return resource_changes.duplicate()
func matches_resources(values:Dictionary) -> bool:
 var checked_chunks:Dictionary={}
 for id in values:
  var record:Dictionary=stream_layout.lookup_record(id,checked_chunks)
  if record.is_empty() or values[id]>record.hits:return false
 return true
func restore_resources(values:Dictionary) -> void:
 resource_changes=values.duplicate()
 for id in resource_nodes:
  var node:Node3D=resource_nodes[id]
  apply_health(node,int(values.get(id,node.get_meta("initial_health"))))
func apply_health(node:Node3D,value:int) -> void:
 if value==0:
  if node.health>0:node.health=1;node.hit()
 else:node.health=value
func unload_chunk(key:Vector2i) -> void:
 if not active.has(key):return
 for record in active[key].resources:
  if resource_nodes.has(record.id):remember(resource_nodes[record.id]);resource_nodes.erase(record.id)
 var node:Node3D=active[key].node;active.erase(key);node.free()
func spawn_resource(record:Dictionary,parent:Node3D=null) -> void:
 if parent==null:parent=self
 var node:Node3D
 if record.kind==2:
  var tree:=preload("res://scripts/prototype_3d/tree_model.gd").new();tree.variant_id=record.variant;tree.design_id=record.get("design",0);parent.add_child(tree)
  tree.scale=Vector3.ONE*(record.height/tree.visual_height());node=tree
 elif record.kind==1:
  var rock:=preload("res://scripts/prototype_3d/rock.gd").new();parent.add_child(rock);rock.configure()
  rock.health=record.hits;rock.required_hits=record.hits;rock.yield_count=record.yield;node=rock
 else:
  var plant:=preload("res://scripts/prototype_3d/gatherable.gd").new();parent.add_child(plant);plant.configure(record);node=plant
 node.position=record.position;node.set_meta("resource_id",record.id)
 node.set_meta("initial_health",record.hits)
 node.set_meta("physical_height",record.get("height",0.0));resource_nodes[record.id]=node
 if resource_changes.has(record.id):apply_health(node,int(resource_changes[record.id]))
func surface_height(point:Vector3) -> float:
 var height:=0.0
 for platform in get_tree().get_nodes_in_group("prototype_platforms"):height=maxf(height,platform.surface_at(point))
 return height
