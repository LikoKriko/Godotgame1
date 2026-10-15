extends SceneTree
const Save=preload("res://scripts/prototype_3d/save_game.gd")
var checks:=0
var failures:=0
var path:="/tmp/day-zero-save-integration-"+str(OS.get_process_id())+".save"
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func wait_loaded(app) -> bool:
 var deadline:=Time.get_ticks_msec()+30000
 while app.loading_busy and Time.get_ticks_msec()<deadline:await process_frame
 require(not app.loading_busy and is_instance_valid(app.game),"Session completes generation/load")
 return is_instance_valid(app.game) and not app.loading_busy
func run():
 var app=load("res://scenes/prototype_3d/day_zero.tscn").instantiate();app.save_path=path;app.session_ready.connect(func(world):world.paused=true);root.add_child(app)
 require(app.menu.visible and not app.menu.can_continue and app.game==null,"F5 title creates no world and Continue is disabled without a save")
 require(not app.menu.confirmation is Window,"New-game confirmation is an integrated Control")
 app.menu.settings_button.pressed.emit()
 require(is_instance_valid(app.menu.settings_panel),"Title configuration uses 3D settings")
 app.menu.close_settings()
 await app.new_game()
 if not await wait_loaded(app):app.free();quit(1);return
 var game=app.game;game.paused=true;game.player.equip_elapsed=-1
 require(not FileAccess.file_exists(path),"Creating a world never auto-saves")
 var resources:Array=game.environment_content.resource_nodes.values()
 var partial=resources.filter(func(node):return node.health>1)[0];var partial_id:String=partial.get_meta("resource_id");partial.health=1
 var depleted=resources.filter(func(node):return node!=partial)[0];depleted.health=1;depleted.hit()
 game.bag.add(&"flecha",9);game.bag.add(&"botella",1)
 for item in game.bag.slots:
  if item.get("id")==&"botella":item.water_ml=250
 var table_item:Dictionary=game.bag.make_item(&"basic_workbench",1);game.workbenches.add_table(Vector3(8,0,8),table_item.uid)
 var drop_item:Dictionary=game.bag.make_item(&"botella",1);drop_item.water_ml=250;game.corpse_loot.spawn_drop(drop_item,Vector3(2,0,2))
 var corpse=get_nodes_in_group("prototype_enemies")[0];corpse.take_damage(10);corpse.death_elapsed=43;corpse.ensure_corpse_area()
 var live=load("res://scripts/prototype_3d/young_enemy.gd").new();game.add_child(live);live.configure(game);live.position=Vector3(-4,0,3);live.health=7
 live.brain.remembers_player=true;live.brain.mode=&"investigate";live.brain.last_seen=Vector3(-2,0,1);live.brain.goal=live.brain.last_seen;live.stun(1.5);live.effects.advance(0.4)
 game.level=4;game.skill_points=2;game.experience=17;game.progression.skills[&"speed"]=1;game.progression.perks[&"life"]=1;game.player_health=19
 game.progression.active[&"speed"]=3.0;game.progression.cooldowns[&"speed"]=12.0
 game.nutrition.hydration_ml=725;game.nutrition.calories_today=1750;game.nutrition.water_today_ml=500;game.day_cycle.day=3;game.day_cycle.hour=18.5
 game.camera_rig.yaw=0.8;game.camera_rig.pitch=-0.4
 var building=get_nodes_in_group("prototype_buildings")[0];game.player.position=building.position+Vector3(0,0.15,0)
 require(Save.save_block_reason(game).is_empty(),"Settled paused game can be saved")
 require(game.save_current_game()==OK,"Manual pause save writes a real file")
 var result:=Save.read_result(path);require(result.ok,"New disk save validates")
 if not result.ok:app.free();quit(1);return
 var saved:Dictionary=result.state;var bytes:=FileAccess.get_file_as_bytes(path)
 var wrong:=saved.duplicate(true);wrong.bag.quick[0].uid=wrong.bag.equipment.legs.uid
 require(not Save.valid(wrong),"Duplicate item UID is rejected")
 wrong=saved.duplicate(true);wrong.player.position=[NAN,0,0];require(not Save.valid(wrong),"Non-finite positions are rejected")
 wrong=saved.duplicate(true);wrong.version=999;require(not Save.valid(wrong),"Unknown save version is rejected")
 game.player.action_elapsed=0
 require(game.save_current_game()==ERR_BUSY and bytes==FileAccess.get_file_as_bytes(path),"Saving mid-action cannot lose wear/ammo or replace last good save")
 game.player.action_elapsed=-1
 app.show_title();await process_frame
 require(app.menu.can_continue and app.game==null,"Return to title releases the session and enables Continue")
 app.menu.request_new_game();require(app.menu.confirmation.visible,"Starting over with a save asks in the integrated panel")
 app.menu.confirmation.cancel_button.pressed.emit();require(not app.menu.confirmation.visible and FileAccess.get_file_as_bytes(path)==bytes,"Cancelling a new game preserves the save")
 await app.continue_game()
 if not await wait_loaded(app):app.free();quit(1);return
 game=app.game;game.paused=true
 require(game.player.position.distance_to(Save.point(saved.player.position))<0.001,"Continue restores player position inside the building")
 var occupied=get_nodes_in_group("prototype_buildings").filter(func(node):return node.stream.interior_bounds.has_point(node.to_local(game.player.position)))
 require(not occupied.is_empty() and occupied[0].stream.interior_ready,"Saved interior is fully loaded before play resumes")
 require(game.bag.slots==saved.bag.slots and game.bag.quick_slots==saved.bag.quick and game.bag.equipment==saved.bag.equipment,"Physical backpack, quick bar and armor restore exactly")
 require(game.bag.active_quick_uid==saved.bag.active and game.bag.next_uid==saved.bag.next_uid,"Selection and UID allocator survive reload")
 require(game.level==4 and game.experience==17 and game.skill_points==2 and game.player_health==19,"Level, health and shared improvement points restore")
 require(game.progression.skills[&"speed"]==1 and game.progression.perks[&"life"]==1 and game.progression.active[&"speed"]==3,"Skills, perks and remaining effect time restore")
 require(game.nutrition.hydration_ml==725 and game.nutrition.calories_today==1750 and game.day_cycle.day==3 and game.day_cycle.hour==18.5,"Daily clock and nutrition do not reset or advance during load")
 require(game.camera_rig.yaw==saved.player.camera[0] and game.camera_rig.pitch==saved.player.camera[1],"Camera direction survives reload")
 for id in saved.resources:require(game.environment_content.resource_nodes[id].health==saved.resources[id],"Resource depletion and partial damage persist")
 require(game.workbenches.tables.size()==1 and game.workbenches.tables[0].uid==table_item.uid,"Placed table and UID persist")
 var drops=get_nodes_in_group("prototype_drops");require(drops.size()==1 and drops[0].item.water_ml==250 and drops[0].item.uid==drop_item.uid,"Ground item retains water and identity")
 var actors=get_nodes_in_group("prototype_enemies");require(actors.size()==2,"Loading replaces initial enemy instead of duplicating it")
 require(actors[0].health==0 and actors[0].death_elapsed==43 and actors[0].corpse_area!=null and not actors[0].loot_slots[0].is_empty(),"Corpse timer, loot and aim volume restore")
 require(actors[1].health==7 and actors[1].brain.remembers_player and actors[1].brain.last_seen==Vector3(-2,0,1) and absf(actors[1].effects.remaining(&"stun")-1.1)<0.001,"Living creature retains memory and stun")
 var user_path:="user://test_day_zero_3d_"+str(OS.get_process_id())+".save"
 require(Save.write(game,user_path)==OK and Save.write(game,user_path)==OK and not Save.read_state(user_path).is_empty(),"user:// paths support replacement and backup outside the project")
 for suffix in ["",".bak",".tmp"]:
  if FileAccess.file_exists(user_path+suffix):DirAccess.remove_absolute(user_path+suffix)
 require(game.save_current_game()==OK and FileAccess.file_exists(path+".bak"),"Second manual save keeps a last-good backup")
 var broken:=FileAccess.open(path,FileAccess.WRITE);broken.store_string("truncated");broken.close()
 var recovered:=Save.read_result(path);require(recovered.ok and recovered.recovered,"Interrupted/corrupt primary recovers the valid backup")
 var bad:=FileAccess.open(path+".bak",FileAccess.WRITE);bad.store_string("{}");bad.close()
 app.show_title();await process_frame
 require(not app.menu.can_continue and not app.menu.message.text.is_empty(),"Corrupt saves show an error and cannot start an empty replacement world")
 await app.new_game()
 if await wait_loaded(app):require(FileAccess.get_file_as_string(path)=="truncated","New game leaves existing save untouched until manually saved")
 var mismatch:=saved.duplicate(true);mismatch.resources[partial_id]=12
 # Scalar validation cannot know a seeded tree's original health; loading must
 # reject this after generating the seed, without silently creating a fresh game.
 await app.build_game(mismatch)
 var deadline:=Time.get_ticks_msec()+30000
 while app.loading_busy and Time.get_ticks_msec()<deadline:await process_frame
 require(not app.loading_busy and app.game==null and app.menu.visible and app.menu.message.text.begins_with("No se pudo restaurar"),"Seed-dependent invalid state returns to title with an error")
 app.free();await process_frame
 for suffix in ["",".bak",".tmp"]:
  if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
 print("%s: %d 3D save/session persistence checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
