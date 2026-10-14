extends SceneTree
var failures:=0
var checks:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func aim(game,point:Vector3) -> void:
 game.camera_rig.update(1);game.camera_rig.camera.look_at(point)
 await physics_frame
func run():
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.player.set_physics_process(false)
 for enemy in get_nodes_in_group("prototype_enemies"):enemy.set_physics_process(false)
 var rock=get_nodes_in_group("prototype_rocks")[0]
 game.player.position=rock.global_position+Vector3(0,0,0.9)
 await aim(game,rock.global_position+Vector3.UP*0.13)
 require(game.target_owner(game.camera_rig.target().collider)==rock,"Reticle ray selects tiny pickup area")
 require(not game.interact() and rock.health==1,"Tool in hand prevents E pickup")
 game.player.equipped=false;game.bag.active_quick_uid=-1
 var before:int=game.bag.count(&"piedra")
 require(game.interact() and game.bag.count(&"piedra")==before+2,"Free hands collect small rock with E")
 require(game.player.preview_state==&"pickup" and not rock.visible,"Pickup has a dedicated 6-frame bend gesture")
 require(not game.interact() and game.bag.count(&"piedra")==before+2,"Repeated interaction cannot duplicate rewards")
 game.player.preview_state=&""
 game.bag.add(&"botella",1);game.bag.select_tool(&"botella");game.player.equipped=true
 var bottle:Dictionary=game.bag.held_item();var uid:int=bottle.uid
 var water=get_nodes_in_group("prototype_water")[0]
 game.player.position=water.global_position+Vector3(0,0,1.1)
 await aim(game,water.global_position+Vector3.UP*0.04)
 require(game.camera_rig.target().collider==water,"Cursor ray hits water surface")
 require(game.interact() and bottle.water_ml==500,"E fills selected bottle from nearby water")
 game.nutrition.hydration_ml=1000
 var slot:Dictionary=game.bag.location(uid)
 require(game.consume_item(slot.index,true),"Bottle can start drinking from quick storage")
 require(bottle.water_ml==500,"Bottle content waits until drink animation completes")
 game.player.preview_state=&"";game.finish_consumption()
 require(bottle.water_ml==250 and game.nutrition.hydration_ml==1250,"Each sip restores 250ml without losing bottle")
 game.consume_item(slot.index,true);game.player.preview_state=&"";game.finish_consumption()
 require(bottle.water_ml==0 and game.bag.item_by_uid(uid)==bottle,"Second sip retains empty unstackable container")
 require(not game.consume_item(slot.index,true),"Empty bottle cannot drink")
 require(game.interact() and bottle.water_ml==500,"The same bottle can be refilled repeatedly")
 game.player.position+=Vector3(0,0,4)
 await aim(game,water.global_position+Vector3.UP*0.04)
 bottle.water_ml=0
 require(not game.interact() and bottle.water_ml==0,"Distant water cannot fill bottle")
 game.free();print("%s: %d 3D cursor, pickup and reusable bottle checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
