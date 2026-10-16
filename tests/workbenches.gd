extends SceneTree
const Workshop = preload("res://scripts/workshop.gd")
const Save = preload("res://scripts/save_game.gd")
var failures := 0
var checks := 0
func _initialize(): call_deferred("run")
func require(ok: bool,message: String):
 checks += 1
 if not ok: failures += 1; push_error(message)
func run():
 var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false)
 var benches = game.workbenches; benches.set_process(false)
 require(benches.tables.is_empty(),"No unrequested preplaced testing table")
 var bag = game.bag
 bag.add(&"palo",12); bag.add(&"cuerda",5)
 require(Workshop.craft(bag,&"basic_workbench").is_empty(),"Table craft consumes exactly twelve sticks and five metres of rope")
 require(bag.count(&"palo") == 0 and bag.count(&"cuerda") == 0 and bag.count(&"basic_workbench") == 1,"No duplicated materials or table")
 var uid := -1
 for item in bag.slots:
  if item.get("id") == &"basic_workbench": uid = item.uid
 var location: Dictionary = bag.location(uid)
 require(bag.move_item(location.kind,location.index,&"quick",0) and bag.activate_quick(0),"Table can be selected from physical quick storage")
 var point := Vector2.INF
 for y in range(-80,81,8):
  for x in range(-80,81,8):
   if benches.can_place(Vector2(x,y)): point = Vector2(x,y); break
  if point.is_finite(): break
 require(point.is_finite(),"There is clear reachable placement ground")
 require(not benches.begin_placement(game.player),"Cannot place over the survivor")
 require(benches.begin_placement(point),"Clicking clear ground starts placement")
 var old_player: Vector2 = game.player
 game.move_player(Vector2.RIGHT,0.5)
 require(game.player == old_player,"Movement remains still during placement")
 benches.advance_placement(2.99)
 require(benches.tables.is_empty() and bag.count(&"basic_workbench") == 1,"No early table placement or inventory consumption")
 benches.cancel_placement(); require(bag.count(&"basic_workbench") == 1,"Cancellation preserves the exact table item")
 require(benches.begin_placement(point),"Placement can restart after cancelling")
 benches.advance_placement(3.0)
 require(benches.tables.size() == 1 and bag.count(&"basic_workbench") == 0 and bag.active_quick_uid == -1,"Three seconds creates one table and consumes its quick item")
 require(not game.world.walkable(benches.tables[0].collider.get_center(),1),"Placed table footprint blocks actors")
 var aim := Vector2.INF
 var rect: Rect2 = benches.graphic_rect(point)
 for y in range(1,31):
  for x in range(1,int(rect.size.x)):
   var candidate := rect.position+Vector2(x+0.5,y+0.5)
   if preload("res://scripts/workbench_art.gd").contains(candidate,rect): aim = candidate; break
  if aim.is_finite(): break
 require(aim.is_finite(),"The table exposes an actual wooden surface for interaction")
 require(benches.interact(aim) and benches.window.visible and game.is_paused(),"E over the nearby table opens the paused workshop")
 var page = benches.window.page; page.set_process(false)
 require(page.station_level == 1 and page.recipe_buttons.size() == 11,"Workbench has exactly the eleven requested default recipes")
 require(page.materials.position.x == 420 and page.create_button.position.x == 840 and page.animation_area.position == Vector2(420,390),"Three columns and joined lower animation area")
 page.select_recipe(&"cuero"); require(page.create_button.disabled,"Leather recipe stays explicitly disabled")
 for id in [&"sword",&"bow",&"leaf_boots",&"leaf_helmet"]:
  for material in Workshop.RECIPES[id]: bag.add(material,Workshop.RECIPES[id][material])
  page.select_recipe(id); page.create_selected(); page.advance_creation(2.0)
  require(bag.count(id) >= 1,"Specified recipe works at the table: "+str(id))
 bag.unlocked_recipes.erase(&"bow"); page.refresh()
 require(not page.recipe_buttons[&"bow"].visible,"Locked recipes do not appear")
 bag.unlock_recipe(&"bow"); page.refresh(); require(page.recipe_buttons[&"bow"].visible,"Unlocked recipe reappears without rebuilding the UI")
 benches.window.hide()
 var saved := Save.capture(game)
 require(Save.valid(saved) and Save.restore(game,saved),"Workstation data survives validated save/load")
 require(game.workbenches.tables.size() == 1 and game.workbenches.tables[0].point == point,"Placed workstation retains its position")
 require(not game.world.walkable(game.workbenches.tables[0].collider.get_center(),1),"Restored table retains its collider")
 print("%s: %d workbench checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures]); quit(1 if failures else 0)
