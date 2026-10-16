extends SceneTree
const Bag = preload("res://scripts/inventory.gd")
const Save = preload("res://scripts/save_game.gd")
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func require(value: bool, message: String):
	checks += 1
	if not value: failures += 1; push_error(message)
func run():
	var bag = Bag.new(); bag.reset()
	var sword: Dictionary = bag.slots[0].duplicate()
	require(bag.move_item(&"bag",0,&"quick",0),"Move into quick storage")
	require(bag.slots[0].is_empty() and bag.quick_slots[0] == sword,"Quick items physically vacate the backpack")
	require(bag.activate_quick(0) and bag.held_item().uid == sword.uid,"A quick tool can be held without duplicating its storage")
	require(bag.equipment[&"hands"].is_empty() and bag.quick_slots[0].uid == sword.uid,"Held quick tool has only one owner")
	bag.consume_use()
	require(bag.quick_slots[0].uses == 39,"Using held quick tool wears the stored instance")
	require(bag.move_item(&"quick",0,&"quick",4) and bag.held_item().uid == sword.uid,"Moving the active slot preserves grip and durability")
	require(bag.shift_transfer(&"quick",4) and bag.quick_slots[4].is_empty() and bag.held_id() == &"","Shift click returns quick item to backpack")
	bag.add(&"helmet",1)
	var helmet := bag.location(bag.slots.filter(func(item): return item.get("id") == &"helmet")[0].uid)
	require(bag.shift_transfer(helmet.kind,helmet.index) and bag.equipment[&"head"].id == &"helmet","Shift click prioritizes empty armor slot")
	bag.add(&"helmet",1)
	helmet = bag.location(bag.slots.filter(func(item): return item.get("id") == &"helmet")[0].uid)
	require(bag.shift_transfer(helmet.kind,helmet.index) and bag.quick_slots[0].id == &"helmet","Occupied armor slot remains worn; spare goes to quick storage")
	require(not bag.move_item(&"quick",0,&"gear",&"feet"),"Incompatible armor drops are rejected")
	bag.add(&"piedra",150)
	var stones := []
	for i in bag.CAPACITY:
		if bag.slots[i].get("id") == &"piedra": stones.append(i)
	bag.move_item(&"bag",stones[0],&"quick",1)
	bag.quick_slots[1].quantity = 60
	bag.slots[stones[1]].quantity = 70
	var total: int = bag.count(&"piedra")
	require(bag.shift_transfer(&"quick",1) and bag.quick_slots[1].is_empty() and bag.count(&"piedra") == total,"Shift transfer fills a partial stack then stores the remainder without loss")
	bag.move_item(&"bag",stones[1],&"quick",1)
	bag.remove_amount(&"piedra",bag.count(&"piedra"))
	require(bag.quick_slots[1].is_empty() and bag.count(&"piedra") == 0,"Crafting can consume materials from quick storage")
	var copy = bag.fork()
	copy.quick_slots[0].uses = 1
	require(bag.quick_slots[0].uses != 1,"Transactional copies isolate quick items")
	var count_before: int = bag.next_uid
	require(not bag.move_item(&"bag",-1,&"quick",0) and bag.next_uid == count_before,"Invalid drops do not modify inventory")
	# Empty slots never resolve to a spurious UID -1 drag source.
	require(bag.location(-1).is_empty(),"Empty drag sources have no location")
	print("%s: %d physical inventory checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(0 if failures == 0 else 1)
