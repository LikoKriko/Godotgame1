extends SceneTree
const Bag = preload("res://scripts/inventory.gd")
const Save = preload("res://scripts/save_game.gd")
var failures := 0
var checks := 0
func _initialize(): call_deferred("run")
func require(value: bool,message: String):
	checks += 1
	if not value: failures += 1; push_error(message)
func key(code: Key, pressed: bool):
	var event := InputEventKey.new()
	event.keycode = code; event.physical_keycode = code; event.pressed = pressed
	Input.parse_input_event(event); Input.flush_buffered_events()
func run():
	var bag = Bag.new(); bag.reset()
	var id: int = bag.slots[0].uid
	bag.move_item(&"bag",0,&"quick",0)
	require(bag.activate_quick(0) and bag.held_id() == &"sword","Quick slot activates its tool")
	bag.consume_use()
	for i in Bag.CAPACITY:
		if bag.slots[i].is_empty(): bag.slots[i] = bag.make_item(&"piedra",99)
	require(bag.activate_quick(0) and bag.held_id() == &"","Same quick key puts away the held tool with a full backpack")
	require(bag.quick_slots[0].uid == id and bag.quick_slots[0].uses == 39,"Putting away keeps the same stored instance and durability")
	require(bag.activate_quick(0) and bag.held_id() == &"sword","A third press draws it again")
	require(bag.equipment[&"hands"].is_empty() and not bag.accepts(&"gear",&"hands",bag.held_item()),"Hands equipment slot rejects weapons and remains exclusive to gloves")
	var blocked = Bag.new(); blocked.reset()
	var stored: Dictionary = blocked.slots[0].duplicate()
	for i in blocked.quick_slots.size():
		if blocked.quick_slots[i].is_empty(): blocked.quick_slots[i] = blocked.make_item(&"piedra",1)
	require(not blocked.equip(0,&"tool"),"A full quick bar requires freeing a slot before equipping from the backpack")
	require(blocked.slots[0] == stored and blocked.held_id() == &"axe","Rejected equip preserves the backpack item and the previous held tool")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game); game.set_process(false)
	var sword_uid: int = game.bag.slots[0].uid
	game.assign_quick_item(0,sword_uid)
	game.use_quick_item(0); game._process(0.02)
	require(game.equipping and game.full_avatar.state == &"equip","Idle tool selection starts its equip animation")
	require(game.use_quick_item(0),"Same key can also put away during the equip sequence")
	game._process(0.01)
	require(not game.equipping and game.bag.held_id() == &"","Putting away cancels drawing immediately")
	key(KEY_D,true)
	var start: Vector2 = game.player
	game.use_quick_item(0); game._process(0.04)
	require(game.player != start and game.full_avatar.state == &"equip_walk","Walking continues with a combined draw-and-walk whole sprite")
	var initial_frame: int = game.full_avatar.frame_index
	game._process(0.10)
	require(game.full_avatar.frame_index != initial_frame,"Moving equip sequence advances both pose clocks")
	key(KEY_SHIFT,true)
	game.use_quick_item(0); game._process(0.01)
	game.use_quick_item(0); game._process(0.03)
	require(game.running and game.full_avatar.state == &"equip_run","Drawing does not stop a run")
	key(KEY_SHIFT,false); key(KEY_D,false)
	game._process(0.6)
	game.bag.add(&"burdock_armor",1)
	var armor: int = game.bag.slots.filter(func(item): return item.get("id") == &"burdock_armor")[0].uid
	var location: Dictionary = game.bag.location(armor)
	var health: float = game.progression.max_health()
	require(game.bag.equip(location.index,&"torso"),"Leaf armor equips into torso")
	game.full_avatar.update_pose(0); game.inventory_panel.refresh()
	require(game.full_avatar.item_key() == "burdock_armor__sword" and game.inventory_panel.portrait_key == "burdock_armor__bare","World sprite and inventory portrait reflect equipped leaf armor")
	require(game.progression.max_health() == health,"First visual armor adds no protection or statistics")
	require(Save.valid(Save.capture(game)),"Tools and armor serialize with unique ownership")
	require(game.get_children().filter(func(node): return node.get_script() != null and str(node.get_script().resource_path).contains("rig")).is_empty(),"Retired live limb rigs no longer exist in gameplay")
	print("%s: %d equipment/motion checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	game.free(); quit(1 if failures else 0)
