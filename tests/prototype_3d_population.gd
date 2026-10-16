extends SceneTree
var failures:=0
var checks:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();root.add_child(game)
 var started:=Time.get_ticks_msec()
 while game.loading_state and Time.get_ticks_msec()-started<30000:await process_frame
 require(not game.loading_state,"World finishes progressive loading")
 if game.loading_state:game.free();quit(1);return
 game.paused=true
 var content=game.environment_content;var layout=content.layout
 require(game.world_bounds==layout.bounds,"3D finite bounds retain original 2D world dimensions")
 require(content.resource_nodes.size()==layout.records.size(),"Every seeded resource receives one 3D representation")
 require(get_nodes_in_group("prototype_burdock").size()==24,"All 24 original individual plants migrate")
 require(get_nodes_in_group("prototype_platforms").size()==4,"All four elevations migrate")
 var variants:Dictionary={}
 for platform in get_nodes_in_group("prototype_platforms"):
  require(absf(platform.height-1.75*0.15)<0.001,"Elevations remain 15 percent of character height")
  require(platform.polygon.size()>4,"Elevation top follows uploaded sprite contour")
 for group in layout.source.tree_groups:require(group.size()>=3 and group.size()<=15,"Source tree groups retain approved sizes")
 var trees=get_nodes_in_group("prototype_trees")
 require(trees.size()>15,"Full forest replaces four demo trees")
 var draw_surfaces:=0
 for tree in trees:
  var children:Array=tree.crown.get_children()
  for node in children:
   if node is MeshInstance3D and not node.is_queued_for_deletion():draw_surfaces+=node.mesh.get_surface_count()
 require(draw_surfaces==trees.size(),"Each tree draws a merged surface instead of dozens of mesh parts")
 var grass_count:=0
 for node in content.get_children():
  if node.get_script()==preload("res://scripts/prototype_3d/ground_cover.gd"):
   for batch in node.get_children():grass_count+=batch.multimesh.instance_count
 require(grass_count==layout.source.grass_tufts.size() and grass_count>100,"Seeded grass is batched without losing its distribution")
 var data=preload("res://scripts/prototype_3d/world_layout.gd").new();data.generate(73129)
 require(var_to_str(data.records)==var_to_str(layout.records),"Returning to the seed reproduces all resource placements")
 print("%s: %d 3D population checks; %d trees, %d grass tufts, loading %d ms"%["PASS" if failures==0 else "FAIL",checks,trees.size(),grass_count,Time.get_ticks_msec()-started])
 game.free();quit(1 if failures else 0)
