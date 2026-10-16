extends SceneTree
var failures:=0
var checks:=0
func _initialize():call_deferred("run")
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false)
 var enemy=game.enemies.enemy;enemy.set_process(false)
 enemy.take_damage(10)
 require(enemy.health==0 and not enemy.is_in_group("damageable") and enemy.visible,"Dead enemy remains as noncombat corpse")
 require(enemy.corpse_expires-Time.get_unix_time_from_system()>181,"Timer includes two-second fall then three real minutes")
 enemy.death_elapsed=2;enemy.update_sprite();game.loot.open_window(enemy)
 require(game.loot.grid.columns==4 and game.loot.grid.get_child_count()==8 and game.is_paused(),"Two rows of four slots pause movement")
 var before:int=game.loot.occupied();game.loot.choose(0);game.loot.collect()
 require(game.loot.occupied()==before+1 and enemy.loot_slots[0].is_empty(),"Collect updates real bag occupation")
 enemy.loot_slots[0]=game.bag.make_item(&"saco_sal",1);enemy.loot_slots[0].uses=7
 game.loot.choose(0);game.loot.drop_selected();game.loot.close_window()
 require(game.loot.drops.size()==1 and game.loot.drops[0].item.uses==7,"Thrown objects preserve durability on ground")
 game.player=game.loot.drops[0].point;game.bag.active_quick_uid=-1
 require(game.loot.interact(game.player) and not game.loot.drops.is_empty(),"Hands-free E starts pickup animation")
 game.interaction_motion.advance(0.18);game.loot.advance_pickup()
 require(game.loot.drops.is_empty(),"Pickup commits during the ground bend")
 var salt=load("res://scripts/workshop.gd").usage_item(game.bag,&"saco_sal",1)
 require(salt.uses==7,"Ground collection preserves remaining uses")
 var snapshot:Dictionary=load("res://scripts/save_game.gd").capture(game)
 require(load("res://scripts/save_game.gd").valid(snapshot),"Corpse save validates")
 require(load("res://scripts/save_game.gd").restore(game,snapshot),"Corpse restores")
 enemy=game.enemies.enemy
 require(enemy.health==0 and not enemy.is_in_group("damageable"),"Restored corpse cannot be attacked")
 enemy.corpse_expires=Time.get_unix_time_from_system()-1;enemy._process(0);await process_frame
 require(not is_instance_valid(enemy),"Expired corpse disappears without waiting in test")
 print("%s: %d corpse checks, %d failures" %["PASS" if failures==0 else "FAIL",checks,failures]);game.free();quit(1 if failures else 0)
