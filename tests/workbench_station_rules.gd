extends SceneTree
const Workshop = preload("res://scripts/workshop.gd")
const Inventory = preload("res://scripts/inventory.gd")
var checks := 0
var failures := 0
func require(ok: bool,message: String):
 checks += 1
 if not ok: failures += 1; push_error(message)
func _initialize():
 var bag := Inventory.new(); bag.reset()
 for id in [&"sword",&"bow",&"pickaxe",&"axe"]:
  require(Workshop.required_station(bag,id) == 0,"Existing basic tools remain craftable without a station")
  var advanced: Dictionary = Inventory.DEFINITIONS[id].duplicate(); advanced.erase("basic_tool")
  require(Workshop.required_station_for(advanced) == 1,"Every future nonbasic tool requires at least a basic workstation")
 require(Workshop.required_station_for({"slot":&"tool","category":&"hammer","required_station":0}) == 1,"New tool categories cannot bypass the workstation minimum")
 require(Workshop.RECIPES[&"sword"] == {&"palo":2,&"piedra":1,&"cuerda":1},"Sword recipe matches user materials")
 require(Workshop.RECIPES[&"bow"] == {&"palo":1,&"cuerda":2},"Bow recipe matches user materials")
 require(Workshop.RECIPES[&"leaf_boots"] == {&"cuerda":2,&"hoja_bardana":4},"Leaf boots recipe matches user materials")
 require(Workshop.RECIPES[&"leaf_helmet"] == {&"cuerda":1,&"hoja_bardana":2},"Leaf helmet recipe matches user materials")
 require(not Workshop.RECIPES.has(&"cuero") and not Workshop.craft(bag,&"cuero",1).is_empty(),"Leather cannot be created for free")
 bag.unlocked_recipes.erase(&"bow"); bag.add(&"palo",1); bag.add(&"cuerda",2)
 require(not Workshop.craft(bag,&"bow",1).is_empty() and bag.count(&"palo") == 1,"A locked recipe cannot consume materials")
 print("%s: %d crafting station rule checks" % ["PASS" if failures == 0 else "FAIL",checks]);quit(1 if failures else 0)
