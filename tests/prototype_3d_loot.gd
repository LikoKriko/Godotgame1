extends SceneTree
var failures:=0
var checks:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();game.use_test_layout=true;root.add_child(game)
 game.set_physics_process(false);game.player.set_physics_process(false)
 var enemy=get_nodes_in_group("prototype_enemies")[0];enemy.set_physics_process(false)
 enemy.position=Vector3(10,0,10);game.player.position=Vector3(10,0,11.2)
 enemy.take_damage(10)
 require(not game.corpse_loot.open_window(enemy),"Dying creature cannot be looted before two-second fall")
 enemy._physics_process(2)
 require(enemy.corpse_area!=null and enemy.loot_slots[0].id==&"cuero_sin_refinar","Completed fall exposes selectable eight-slot remains")
 game.camera_rig.update(1);game.camera_rig.camera.look_at(enemy.position+Vector3.UP*0.15)
 for i in 2:await physics_frame
 require(game.interact() and game.corpse_loot.window.visible and game.paused,"E on the corpse opens its integrated loot window")
 require(game.corpse_loot.grid.get_child_count()==8 and game.corpse_loot.grid.columns==4,"Corpse has exactly two rows of four slots")
 var before:int=game.corpse_loot.occupied()
 game.corpse_loot.choose(0);game.corpse_loot.collect()
 require(enemy.loot_slots[0].is_empty() and game.bag.count(&"cuero_sin_refinar")==1,"Collect transfers one item into backpack")
 require(game.corpse_loot.count_label.text.contains(str(before+1)+" / 32"),"Loot counter updates real occupied bag slots")
 var bottle:Dictionary=game.bag.make_item(&"botella",1);bottle.water_ml=250;enemy.loot_slots[1]=bottle
 game.corpse_loot.choose(1);game.corpse_loot.drop_selected()
 var drops=get_nodes_in_group("prototype_drops")
 require(drops.size()==1 and enemy.loot_slots[1].is_empty(),"Tirar moves complete item into world without duplicating it")
 require(drops[0].item.water_ml==250,"Dropped bottle preserves its content")
 game.corpse_loot.close_window();game.player.position=drops[0].global_position+Vector3(0,0,0.8)
 game.camera_rig.update(1);game.camera_rig.camera.look_at(drops[0].global_position+Vector3.UP*0.15)
 for i in 2:await physics_frame
 require(not game.interact() and not drops[0].item.is_empty(),"Ground pickup requires free hands")
 game.player.equipped=false;game.bag.active_quick_uid=-1
 require(game.interact() and not drops[0].item.is_empty(),"E starts the reach while preserving the ground item until contact")
 for frame in 60:game.player.update_facing(game.player.pickup_point,1.0/60)
 game.player.advance_preview(game.player.Clips.duration(&"pickup")*0.5)
 require(drops[0].item.is_empty(),"Hand contact retrieves the ground item exactly once")
 var recovered:Dictionary={}
 for item in game.bag.slots:
  if item.get("id")==&"botella":recovered=item
 require(not recovered.is_empty() and recovered.water_ml==250,"Pickup keeps per-item state and allocates valid inventory identity")
 require(game.player.preview_state==&"pickup","Ground item pickup uses the dedicated body gesture")
 game.player.preview_state=&""
 var knife:Dictionary=game.bag.make_item(&"knife",1);knife.uses=17;enemy.loot_slots[2]=knife
 for i in game.bag.CAPACITY:
  if game.bag.slots[i].is_empty():game.bag.slots[i]=game.bag.make_item(&"sword",1)
 game.corpse_loot.open_window(enemy);game.corpse_loot.choose(2);game.corpse_loot.collect()
 require(enemy.loot_slots[2].uses==17,"Full bag never loses the corpse item")
 game.corpse_loot.close_window();enemy._physics_process(179.9)
 require(not enemy.is_queued_for_deletion(),"Corpse stays available during its three-minute lifetime")
 enemy._physics_process(0.1)
 require(enemy.is_queued_for_deletion(),"Corpse expires after two-second fall plus 180 seconds")
 game.free();print("%s: %d corpse, loot transfer and ground pickup checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
