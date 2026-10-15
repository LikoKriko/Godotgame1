extends Node3D
signal progress_changed(value:float)
signal completed
const UNIT:=1.75/64.0
var game
var layout=preload("res://scripts/prototype_3d/world_layout.gd").new()
var resource_nodes:Dictionary={}
var built:=0
var total:=0
var buildings_built:=0
func configure(owner_game,seed_value:int) -> void:
 game=owner_game;layout.generate(seed_value);total=layout.records.size()
 game.terrain.sampler.existing_paths=true
 for influence in layout.source.terrain_influences:game.terrain.sampler.add_influence(influence.id,&"dirt",influence.rect,0.65)
 set_process(true)
func _process(_delta:float) -> void:
 if game==null:return
 var deadline:=Time.get_ticks_usec()+4000
 while built<total and Time.get_ticks_usec()<deadline:
  spawn_resource(layout.records[built]);built+=1
 if buildings_built==0:progress_changed.emit(0.12+float(built)/maxi(1,total)*0.75)
 if built<total:return
 if buildings_built<layout.source.camp_buildings.size():
  var building:=preload("res://scripts/prototype_3d/camp_building.gd").new();add_child(building);building.configure(game,layout.source.camp_buildings[buildings_built]);buildings_built+=1
  progress_changed.emit(0.87+float(buildings_built)/layout.source.camp_buildings.size()*0.08);return
 for record in layout.source.puddles:
  var water:=preload("res://scripts/prototype_3d/water_source.gd").new();water.radius=record.width*UNIT*0.5;add_child(water);water.position=Vector3(record.position.x*UNIT,0,record.position.y*UNIT)
 for record in layout.source.platforms:
  var platform:=preload("res://scripts/prototype_3d/raised_ground.gd").new();add_child(platform);platform.configure(record)
 var cover:=preload("res://scripts/prototype_3d/ground_cover.gd").new();add_child(cover);cover.configure(layout.source.grass_tufts)
 game.terrain.refresh_influences();progress_changed.emit(1.0);set_process(false);completed.emit()
func spawn_resource(record:Dictionary) -> void:
 var node:Node3D
 if record.kind==2:
  var tree:=preload("res://scripts/prototype_3d/tree_model.gd").new();tree.variant_id=record.variant;tree.design_id=record.get("design",0);add_child(tree)
  tree.scale=Vector3.ONE*(record.height/tree.visual_height());node=tree
 elif record.kind==1:
  var rock:=preload("res://scripts/prototype_3d/rock.gd").new();add_child(rock);rock.configure(0 if record.hand_collectable else 2)
  rock.scale=Vector3.ONE*(record.height/rock.height);rock.height=record.height;rock.health=record.hits;rock.required_hits=record.hits;rock.yield_count=record.yield;node=rock
 else:
  var plant:=preload("res://scripts/prototype_3d/gatherable.gd").new();add_child(plant);plant.configure(record);node=plant
 node.position=record.position;node.set_meta("resource_id",record.id)
 node.set_meta("physical_height",record.get("height",0.0));resource_nodes[record.id]=node
func surface_height(point:Vector3) -> float:
 var height:=0.0
 for platform in get_tree().get_nodes_in_group("prototype_platforms"):height=maxf(height,platform.surface_at(point))
 return height
