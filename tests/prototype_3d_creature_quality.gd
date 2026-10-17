extends SceneTree
const Policy=preload("res://scripts/prototype_3d/distance_quality.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 for row in [[0,100],[30,100],[50,100],[50.01,95],[74.99,95],[75,90],[99.99,90],[100,80],[124.99,80],[125,65],[149.99,65]]:
  require(Policy.distance_percent(row[0],true)==row[1],"Creature distance boundary: "+str(row))
 var state:Dictionary={}
 require(Policy.advance(state,50,true,.1,true)==100,"Nearby creatures retain full detail behind the camera")
 require(Policy.advance(state,55,true,.1,true)==65,"Rear creatures retain a recognisable geometry floor")
 for expected in [75,85,95]:require(Policy.advance(state,55,false,.1,true)==expected,"Recovery retains the ten-point steps and respects its distance cap")
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();game.use_test_layout=true;root.add_child(game);game.paused=true
 game.distance_optimization.set_process(false);game.player.set_physics_process(false)
 var enemy=get_nodes_in_group("prototype_enemies")[0];enemy.set_physics_process(false)
 enemy.model.animate(&"attack",.43);enemy.model.set_facial_time(.5)
 var pose:Array=enemy.model.posed.duplicate();var morphs:PackedFloat32Array=[]
 for i in 5:morphs.append(enemy.model.mesh_node.get_blend_shape_value(i))
 var source:Mesh=enemy.model.mesh_node.mesh
 var source_arrays:Array=source.surface_get_arrays(0)
 await process_frame
 var entry:Dictionary=game.distance_optimization.entries[enemy.model.mesh_node.get_instance_id()]
 require(entry.creature,"Real enemy meshes inherit the creature policy from their actor")
 for group in ["creatures","prototype_sprouts"]:
  var owner_node:=Node3D.new();owner_node.add_to_group(group);game.add_child(owner_node)
  var visual:=MeshInstance3D.new();visual.mesh=BoxMesh.new();owner_node.add_child(visual)
  await process_frame
  require(game.distance_optimization.entries[visual.get_instance_id()].creature,"Creature profile includes nested meshes in "+group)
 var scenery:=MeshInstance3D.new();scenery.mesh=BoxMesh.new();game.add_child(scenery);await process_frame
 require(not game.distance_optimization.entries[scenery.get_instance_id()].creature,"Scenery keeps the existing distance profile")
 var center:Vector3=enemy.model.mesh_node.to_global(source.get_aabb().get_center())
 for row in [[30,100],[50,100],[75,90],[100,80],[125,65],[149,65],[20,100]]:
  game.distance_optimization.update_quality(.1,center+Vector3(0,0,row[0]),Vector3.FORWARD)
  require(entry.quality==row[1],"Live enemy uses its conservative mesh budget")
  for i in source.get_surface_count():require(enemy.model.mesh_node.get_surface_override_material(i)==source.surface_get_material(i),"Creature textures retain the source materials at every distance")
 game.distance_optimization.meshes.finish()
 game.distance_optimization.update_quality(.1,center+Vector3(0,0,140),Vector3.FORWARD)
 require(enemy.model.posed==pose,"Distance changes cannot change animation or attack poses")
 for i in 5:require(enemy.model.mesh_node.get_blend_shape_value(i)==morphs[i],"A creature LOD preserves the current facial expression")
 require(source.surface_get_arrays(0)==source_arrays,"Creature LODs leave the original skin, UV and geometry untouched")
 game.free()
 print("%s: %d creature distance, texture, recovery and source-preservation checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
