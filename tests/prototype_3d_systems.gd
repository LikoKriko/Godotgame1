extends SceneTree
var failures:=0
var checks:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var world=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();root.add_child(world)
 world.player.set_physics_process(false)
 for enemy in get_nodes_in_group("prototype_enemies"):enemy.set_physics_process(false)
 world.toggle_inventory(0)
 require(world.paused and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Inventory pauses world and releases pointer")
 require(world.inventory_panel.backpack_buttons.size()==32,"Backpack preserves 32 slots")
 require(world.inventory_panel.gear_buttons.size()==5,"Equipment preserves five distinct armor slots")
 require(world.inventory_panel.portrait.texture is ViewportTexture,"Portrait uses actual 3D survivor")
 world.bag.add(&"piedra",10);world.bag.add(&"palo",10);world.bag.add(&"cuerda",10)
 var stone:Dictionary={}
 for item in world.bag.slots:
  if item.get("id")==&"piedra":stone=item
 var from:Dictionary=world.bag.location(stone.uid)
 require(world.bag.shift_transfer(from.kind,from.index),"Shift transfers materials into real quick storage")
 require(world.bag.location(stone.uid).kind==&"quick","Quick storage frees backpack slots")
 var count_before:int=world.bag.count(&"piedra")
 world.inventory_panel.open_section(1)
 var page=world.inventory_panel.creation_page
 page.select_recipe(&"pickaxe");page.create_selected()
 require(page.is_crafting() and world.bag.count(&"piedra")==count_before-2,"Craft reserves materials from both storage containers")
 page.advance_creation(1.99)
 require(page.is_crafting(),"Craft does not complete before 2 seconds")
 page.cancel_creation()
 require(world.bag.count(&"piedra")==count_before,"Cancel restores original reserved materials")
 var pickaxes_before:int=world.bag.count(&"pickaxe")
 page.create_selected();page.advance_creation(2)
 require(world.bag.count(&"pickaxe")==pickaxes_before+1,"Completed craft delivers exactly one unstackable tool")
 world.skill_points=2
 require(world.buy_improvement(&"life",false),"First perk costs two shared points")
 require(world.skill_points==0 and not world.buy_improvement(&"speed",true),"Spent points cannot be reused for abilities")
 require(world.player_health==22,"Vitality increases current and maximum health")
 world.skill_points=1;require(world.buy_improvement(&"speed",true),"One point unlocks first skill")
 require(world.activate_skill(&"speed") and world.progression.speed_multiplier()==1.25,"Unlocked speed skill applies its real movement multiplier")
 require(not world.gain_experience(100,&"harvest"),"Harvesting cannot award retired XP")
 require(world.gain_experience(20,&"craft") and world.level==2 and world.skill_points==1,"Registered XP source awards one shared point per level")
 world.inventory_panel.hide();world.bag.add(&"apple",1)
 var apple_index:=-1
 for i in world.bag.slots.size():
  if world.bag.slots[i].get("id")==&"apple":apple_index=i;break
 require(world.consume_item(apple_index),"Food starts its dedicated animation")
 require(world.bag.count(&"apple")==1 and world.nutrition.calories_today==0,"Food is retained until eating completes")
 world.player.preview_state=&"";world.finish_consumption()
 require(world.bag.count(&"apple")==0 and world.nutrition.calories_today==95,"Animation completion consumes selected food and applies calories once")
 world.toggle_catalog();world.item_catalog.select_item(&"botella");world.item_catalog.quantity.value=2
 require(world.item_catalog.add_selected(),"Catalogue adds registered objects")
 require(world.bag.slots.filter(func(item):return item.get("id")==&"botella").size()==2,"Bottles occupy separate slots")
 world.item_catalog.hide()
 world.player_health=0;world.respawn()
 require(world.level==1 and world.skill_points==0 and world.progression.skills[&"speed"]==1 and world.progression.perks[&"life"]==0,"Respawn retains unlocked skill only and resets levels/perks")
 require(world.bag.count(&"axe")==0 and world.bag.held_id()==&"","Respawn loses carried objects")
 print("%s: %d migrated inventory, crafting, progression and consumption checks"%["PASS" if failures==0 else "FAIL",checks])
 world.free();quit(1 if failures else 0)
