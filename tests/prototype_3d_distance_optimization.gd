extends SceneTree
const Policy=preload("res://scripts/prototype_3d/distance_quality.gd")
class EmptyContent extends Node3D:
 var resource_nodes:Dictionary={}
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 for row in [[0.0,100],[29.999,100],[30.0,95],[40.0,90],[50.0,80],[65.0,65],[75.0,45],[90.0,35],[150.0,35]]:
  require(Policy.distance_percent(row[0])==row[1],"Exact distance threshold "+str(row))
 var state:Dictionary={}
 for row in [[95.0,35],[80.0,45],[70.0,65],[55.0,80],[45.0,90],[35.0,95],[20.0,100],[95.0,35]]:
  require(Policy.advance(state,row[0],false,.1)==row[1],"Crossing thresholds in either direction is reversible")
 state={}
 require(Policy.advance(state,50,true,0)==50,"Rear hemisphere is capped at fifty percent")
 require(Policy.advance(state,50,false,.09)==50,"Looking back cannot restore quality before a tenth of a second")
 require(Policy.advance(state,50,false,.01)==60,"First recovery step adds ten percentage points")
 require(Policy.advance(state,50,false,.1)==70,"Second recovery step")
 require(Policy.advance(state,50,false,.1)==80,"Recovery respects the distance cap")
 require(Policy.advance(state,80,true,.1)==45,"Rear view cannot increase a lower distance budget")
 require(Policy.advance(state,80,false,.5)==45,"Visible objects at eighty metres retain forty-five percent")
 require(Policy.behind(Vector3(0,0,50),Vector3.ZERO,Vector3.FORWARD),"Rear direction uses the actual camera look vector")
 require(not Policy.behind(Vector3(0,0,49.99),Vector3.ZERO,Vector3.FORWARD),"Rear reduction starts at fifty metres")
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();game.use_test_layout=true;root.add_child(game)
 game.set_physics_process(false);game.player.set_physics_process(false);game.distance_optimization.set_process(false)
 var enemy=get_nodes_in_group("prototype_enemies")[0];enemy.set_physics_process(false)
 enemy.attack_elapsed=.23;enemy.attack_boxing=false;enemy.model.animate(&"attack",.23)
 enemy.model.set_facial_time(.47)
 var phase:float=enemy.phase;var pose:Dictionary=enemy.model.last_pose.duplicate(true)
 var facial:float=enemy.model.facial_elapsed
 var point:Vector3=game.player.position+Vector3(150,0,0);enemy.position=point
 game.distance_optimization.update_enemies()
 require(enemy.distance_suspended and enemy.model.get_child_count()==0,"At 150 metres the visual model is actually freed")
 require(enemy.collision_layer==0 and enemy.hurt_area.collision_layer==0,"Unloaded enemies leave no ghost collision or hurtbox")
 enemy._physics_process(3.0)
 require(enemy.position==point and enemy.attack_elapsed==.23 and enemy.phase==phase,"Suspended movement, action and phase remain frozen")
 var content:=EmptyContent.new();game.add_child(content);game.environment_content=content
 var save=preload("res://scripts/prototype_3d/save_game.gd")
 var saved:Dictionary=save.capture(game)
 require(save.valid(saved),"A save accepts finite suspended-enemy coordinates beyond 150 metres")
 var frozen:Array=saved.enemies.filter(func(value):return value.position[0]>100)
 require(frozen.size()==1 and frozen[0].attack_elapsed==.23,"Saving includes the distant position and unfinished action")
 enemy.position=game.player.position+Vector3(149.9,0,0);game.distance_optimization.update_enemies()
 require(not enemy.distance_suspended and enemy.model.mesh_node!=null,"Crossing back inside 150 metres recreates the visual model")
 require(enemy.model.last_pose==pose and enemy.model.facial_elapsed==facial,"Reload restores pose and facial action without advancing time")
 require(enemy.attack_elapsed==.23 and enemy.collision_layer==8 and enemy.hurt_area.collision_layer==16,"Reload preserves the attack and restores its original collision layers")
 require(not enemy.is_physics_processing(),"An independently disabled actor remains disabled after streaming")
 require(save.restore(game,saved),"A saved suspended enemy can be restored through the real game loader")
 enemy=get_nodes_in_group("prototype_enemies")[0]
 require(enemy.distance_suspended and enemy.position==point and enemy.attack_elapsed==.23,"Disk-state restoration immediately suspends the far actor with its original unfinished action")
 var viewport:=SubViewport.new();game.add_child(viewport)
 var portrait:=MeshInstance3D.new();portrait.mesh=SphereMesh.new();viewport.add_child(portrait)
 var visual:=MeshInstance3D.new();visual.mesh=SphereMesh.new();game.add_child(visual);visual.position=game.player.position+Vector3(0,0,-70)
 await process_frame
 game.camera_rig.camera.global_basis=Basis.IDENTITY
 game.distance_optimization.update_quality(.1)
 var entry:Dictionary=game.distance_optimization.entries[visual.get_instance_id()]
 require(entry.quality==65,"The scene applies the real world-space distance to geometry")
 require(not game.distance_optimization.entries.has(portrait.get_instance_id()),"Inventory portraits and other viewports are not distance-graded")
 var source:Mesh=entry.mesh
 visual.position=game.player.position+Vector3(0,0,-10);game.distance_optimization.update_quality(.1)
 require(visual.mesh==source and entry.quality==100,"Moving close restores the exact original mesh")
 var batch:=MultiMeshInstance3D.new();var instances:=MultiMesh.new();instances.transform_format=MultiMesh.TRANSFORM_3D;instances.mesh=SphereMesh.new();instances.instance_count=2
 instances.set_instance_transform(0,Transform3D(Basis.IDENTITY,game.player.position+Vector3(0,0,-10)))
 instances.set_instance_transform(1,Transform3D(Basis.IDENTITY,game.player.position+Vector3(0,0,-80)))
 batch.multimesh=instances;game.add_child(batch);await process_frame
 game.distance_optimization.update_quality(.1)
 var batches:Dictionary=game.distance_optimization.entries[batch.get_instance_id()].buckets
 if DisplayServer.get_name()!="headless":require(batches.has(100) and batches.has(45),"Scattered MultiMesh instances receive their own distance budgets")
 require(instances.instance_count==2 and instances.visible_instance_count==-1,"Batching cannot mutate shared source instance buffers")
 if DisplayServer.get_name()!="headless":require(batches.has(45) and batches[45].multimesh.get_instance_transform(0)==instances.get_instance_transform(1),"Quality buckets preserve the exact original placement")
 else:print("SKIP: dummy renderer does not retain MultiMesh instance buffers; run with X11 to verify batching")
 game.free()
 print("%s: %d distance, recovery and suspended-enemy checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
