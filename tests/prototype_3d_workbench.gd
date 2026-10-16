extends SceneTree
var failures:=0
var checks:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();game.use_test_layout=true;root.add_child(game)
 game.player.set_physics_process(false);game.set_physics_process(false)
 for enemy in get_nodes_in_group("prototype_enemies"):enemy.set_physics_process(false)
 game.workbenches.set_process(false);game.bag.add(&"basic_workbench",1);game.bag.select_tool(&"basic_workbench");game.player.equipped=true
 game.player.position=Vector3(10,0,10)
 await physics_frame
 var location:=Vector3(10,0,8.5);var uid:int=game.bag.held_item().uid
 require(game.workbenches.begin_placement(location),"Selected quick-slot workbench begins placement on clear ground")
 var original:Vector3=game.player.position
 var key:=InputEventKey.new();key.physical_keycode=KEY_W;key.keycode=KEY_W;key.pressed=true;Input.parse_input_event(key)
 game.player._physics_process(1.0/60.0)
 require(game.player.position==original and game.player.velocity.is_zero_approx(),"Placement holds the real player still while movement input is pressed")
 key=key.duplicate();key.pressed=false;Input.parse_input_event(key)
 game.workbenches.advance_placement(2.99)
 require(game.workbenches.placing() and game.bag.item_by_uid(uid).id==&"basic_workbench" and game.workbenches.tables.is_empty(),"Three-second placement keeps ownership until completion")
 game.toggle_pause()
 require(not game.workbenches.placing() and not game.paused and game.bag.item_by_uid(uid).id==&"basic_workbench","Escape cancels placement without consuming or pausing")
 require(not game.workbenches.begin_placement(game.player.position),"Cannot place a table through the player")
 require(not game.workbenches.begin_placement(location+Vector3.UP*0.3),"Cannot place unsupported floating table")
 require(game.workbenches.begin_placement(location),"Canceled table can be placed again")
 game.workbenches.advance_placement(3)
 require(game.workbenches.tables.size()==1 and game.bag.item_by_uid(uid).is_empty(),"Placement consumes exactly the selected item once")
 require(not game.player.equipped and game.bag.held_id()==&"","Placement leaves free hands")
 var table=game.workbenches.tables[0]
 await physics_frame
 require(not game.workbenches.can_place(location),"Occupied table footprint rejects a second table")
 game.camera_rig.update(1);game.camera_rig.camera.look_at(table.global_position+Vector3.UP*0.8)
 await physics_frame
 require(game.interact() and game.paused and game.workbenches.window.visible,"E on the physical table opens station crafting")
 var page=game.workbenches.window.page
 require(page.station_level==1 and page.recipe_buttons.has(&"cuero_curtido"),"Workbench exposes unlocked station recipes")
 require(page.icon_provider==preload("res://scripts/prototype_3d/item_icons.gd"),"Station uses 256px item artwork")
 game.bag.add(&"cuero_sin_refinar",1);game.bag.add(&"saco_sal",1);game.bag.add(&"knife",1)
 page.select_recipe(&"cuero_curtido");page.create_selected()
 require(page.is_crafting(),"Station reserves leather, salt and knife use costs")
 page.advance_creation(2)
 require(game.bag.count(&"cuero_curtido")==1,"Station creates cured leather after the full duration")
 var knife:Dictionary=page.Workshop.usage_item(game.bag,&"knife",1);var salt:Dictionary=page.Workshop.usage_item(game.bag,&"saco_sal",1)
 require(knife.uses==37 and salt.uses==11,"Curing consumes exactly three knife uses and one salt use")
 game.workbenches.window.hide()
 require(not game.paused and (DisplayServer.get_name()=="headless" or Input.mouse_mode==Input.MOUSE_MODE_CAPTURED),"Closing station resumes shoulder camera gameplay")
 game.free();print("%s: %d 3D placement and workbench crafting checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
