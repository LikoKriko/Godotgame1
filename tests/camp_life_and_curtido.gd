extends SceneTree
var failures:=0
var checks:=0
func require(value:bool,message:String):
 checks+=1
 if not value: failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var world=load("res://scripts/test_world.gd").new();world.generate(73129)
 require(world.camp_buildings.size()==6,"Camp includes all six buildings")
 for group in world.tree_groups: require(group.size()>=3 and group.size()<=15,"Trees form 3–15 groups")
 require(world.tree_groups.size()>0,"Groups exist")
 var art=load("res://scripts/large_tree_art.gd")
 require(is_equal_approx(art.dimensions(5).y,67.2),"Sixth tree establishes 105% height")
 for i in 9:require(art.dimensions(i).y>=67.199,"Other trees are at least reference height")
 var inventory=load("res://scripts/inventory.gd").new();inventory.reset()
 var workshop=load("res://scripts/workshop.gd")
 inventory.add(&"cuero_sin_refinar",1);inventory.add(&"saco_sal",1);inventory.add(&"knife",1)
 require(workshop.craft(inventory,&"cuero_curtido",0)!="","Workbench required")
 require(workshop.craft(inventory,&"cuero_curtido",1)=="","Valid curtido completes")
 require(inventory.count(&"cuero_sin_refinar")==0 and inventory.count(&"cuero_curtido")==1,"Only raw hide is consumed")
 require(workshop.usage_item(inventory,&"saco_sal",1).uses==11,"One salt use spent")
 require(workshop.usage_item(inventory,&"knife",1).uses==37,"Three knife uses spent")
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false)
 require(game.hut.buildings.size()==6,"Six exteriors instantiated")
 for building in game.hut.buildings:
  require(game.world.walkable(building.door,15),"Each door has a clear approach")
  for cell in game.world.props:require(not game.world_view.presentation(cell).rect.intersects(building.rect),"Camp avoids prop silhouettes")
  game.player=building.door; require(game.hut.interact(),"E enters every door")
  require(game.hut.inside and game.hut.room!=null,"Each door loads the shared separate room")
  game.player=game.hut.ROOM_DOOR;require(game.hut.interact(),"E exits each room")
 var knife_uid: int =workshop.usage_item(inventory,&"knife",1).uid
 var page=load("res://scripts/creation_page.gd").new();root.add_child(page);page.configure(inventory,1)
 inventory.add(&"cuero_sin_refinar",1);page.selected=&"cuero_curtido";page.create_selected()
 require(inventory.item_by_uid(knife_uid).uses==34,"Craft reservation spends tool uses")
 page.cancel_creation();require(inventory.item_by_uid(knife_uid).uses==37 and inventory.count(&"cuero_sin_refinar")==1,"Cancel restores uses and materials")
 game.progression.skills[&"speed"]=1;game.progression.perks[&"life"]=2;game.level=5;game.skill_points=3
 game.take_damage(100);require(game.life.dying(),"Lethal damage starts death sequence")
 game.life.advance(2.99);require(not game.life.panel.visible,"Death window waits for 3s")
 game.life.advance(0.01);require(game.life.panel.visible,"Death window appears at 3s")
 game.life.respawn();require(game.level==1 and game.skill_points==0 and game.progression.skills.speed==1 and game.progression.perks.life==0,"Respawn retains only unlocked abilities")
 require(game.loot.occupied()==0 and game.bag.held_id()==&"","Respawn loses equipment and storage")
 print("%s: %d camp/life/crafting checks, %d failures" %["PASS" if failures==0 else "FAIL",checks,failures]);game.free();page.free();quit(1 if failures else 0)
