extends SceneTree
var failures:=0
var checks:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func equip(game,id:StringName) -> void:
 require(game.bag.select_tool(id),"Tool can enter a real quick slot")
 game.player.equipped=true;game.player.equip_elapsed=-1;game.player.action_elapsed=-1
func orient(game,point:Vector3) -> void:
 var toward:Vector3=point-game.player.global_position
 game.player.model.rotation.y=atan2(toward.x,toward.z)
func run():
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();game.use_test_layout=true;root.add_child(game);game.set_physics_process(false);game.player.set_physics_process(false)
 var geometry=preload("res://scripts/prototype_3d/prop_mesh.gd")
 for end in [Vector3(4,12,-8),Vector3(0,1,0),Vector3(0,-14,-4)]:
  var segment=geometry.segment(game,Vector3(1,3,-2),end,0.11,geometry.material(&"rope"))
  require((segment.transform*Vector3(0,-0.5,0)).distance_to(Vector3(1,3,-2))<0.001 and (segment.transform*Vector3(0,0.5,0)).distance_to(end)<0.001,"Rotated rope/shaft endpoints remain attached without scaling distortion")
  segment.free()
 var enemy=get_nodes_in_group("prototype_enemies")[0];enemy.set_physics_process(false);enemy.position=Vector3(10,0,10);enemy.update_hurtboxes()
 game.progression.rng.seed=42
 game.player.position=Vector3(10,0,10.85)
 await physics_frame
 var point:Vector3=enemy.position+Vector3(0,0.6,0.1);orient(game,point)
 for id in [&"sword",&"axe",&"pickaxe"]:
  equip(game,id);enemy.health=10
  var before:int=game.bag.held_item().uses
  require(game.resolve_hit({"collider":enemy,"position":point}),"Melee hits a real nearby enemy volume with "+String(id))
  require(enemy.health==(7 if id==&"sword" else 9),"Sword/tool damage remains 3/1")
  require(game.bag.held_item().uses==before-(1 if id==&"sword" else 2),"Enemy impacts apply category-specific wear")
  before=game.bag.held_item().uses
  require(not game.resolve_hit({}) and game.bag.held_item().uses==before,"Air swings do not wear melee equipment")
 var tree=get_nodes_in_group("prototype_trees")[1]
 game.player.position=tree.global_position+Vector3(0,0,1.05)
 point=tree.global_position+Vector3(0,1.0,0.14);orient(game,point)
 await physics_frame
 for id in [&"sword",&"pickaxe",&"axe"]:
  equip(game,id)
  var before:int=game.bag.held_item().uses;var hp:int=tree.health
  require(game.resolve_hit({"collider":tree,"position":point}),"Aimed tree surface is within anatomical reach")
  require(tree.health==hp-(1 if id==&"axe" else 0),"Only axe damages the tree")
  require(game.bag.held_item().uses==before-(2 if id==&"pickaxe" else 1),"Correct/wrong work spends one/two uses")
 var rock=get_nodes_in_group("prototype_rocks")[1]
 game.player.position=rock.global_position+Vector3(0,0,1.0)
 point=rock.global_position+Vector3(0,0.6,0.18);orient(game,point)
 await physics_frame
 for id in [&"sword",&"axe",&"pickaxe"]:
  equip(game,id)
  var before:int=game.bag.held_item().uses;var hp:int=rock.health
  require(game.resolve_hit({"collider":rock,"position":point}),"Aimed rock surface is within reach")
  require(rock.health==hp-(1 if id==&"pickaxe" else 0),"Only pickaxe damages mineable rock")
  require(game.bag.held_item().uses==before-(2 if id==&"axe" else 1),"Rock impacts apply correct tool wear")
 equip(game,&"bow");game.player.position=Vector3(12,0,12);game.camera_rig.update(1)
 var bow:Dictionary=game.bag.held_item();var uses:int=bow.uses
 require(not game.player.strike() and game.player.action_elapsed<0 and bow.uses==uses,"Missing arrows cannot animate or wear the bow")
 require(game.status.text=="Necesitas flechas para disparar el arco","Missing ammunition shows exact requested message")
 game.bag.add(&"flecha",2)
 require(game.player.strike() and bow.uses==uses-1,"Drawing immediately wears bow once")
 game.player.advance_action(0.1);game.player.cancel_action()
 require(game.bag.count(&"flecha")==2,"Cancelling draw preserves ammunition")
 require(game.player.strike(),"Bow can draw after cancelling")
 game.player.model.family_override=&"bow";game.player.model.nock_visible=true;game.player.model.aim_contact=Vector3(0,42,80);game.player.model.animate(&"draw",1,true)
 game.player.action_point=Vector3(12,1,-10)
 game.player.advance_action(0.499)
 require(game.bag.count(&"flecha")==2 and get_nodes_in_group("player_arrows_3d").is_empty(),"No release before 0.5 seconds")
 game.player.advance_action(0.001)
 require(game.bag.count(&"flecha")==1 and bow.uses==uses-2,"Release consumes one arrow without extra wear")
 require(get_nodes_in_group("player_arrows_3d").size()==1,"Draw creates one solid 3D projectile")
 for arrow in get_nodes_in_group("player_arrows_3d"):arrow.free()
 var arrow=preload("res://scripts/prototype_3d/arrow.gd").new();game.add_child(arrow);enemy.health=10
 arrow.configure(game,enemy.position+Vector3(0,0.45,2),enemy.position+Vector3(0,0.45,-1));arrow.set_physics_process(false)
 arrow.travel(4)
 require(enemy.health==7,"Swept arrow ray hits real enemy and applies bow damage")
 require(arrow.is_queued_for_deletion(),"Arrow disappears after impact")
 var armor=game.bag.make_item(&"burdock_armor",1);game.bag.equipment[&"torso"]=armor;game.sync_equipment()
 require(game.player.model.leaf_armor.visible and game.inventory_panel.portrait_actor.leaf_armor.visible,"Torso equipment updates world and portrait")
 game.player.model.family_override=&"";game.player.model.animate(&"run",0.35,false)
 require(game.player.model.leaf_armor.transform.is_equal_approx(game.player.model.last_pose.body),"Armor shares the complete animated torso transform")
 game.bag.equipment[&"torso"]={};game.sync_equipment()
 require(not game.player.model.leaf_armor.visible,"Unequipping removes armor without changing body mesh")
 var actor=game.player.model;actor.family_override=&"bow";actor.nock_visible=true
 for phase in [0.0,0.5,1.0]:
  actor.aim_contact=Vector3(0,42,80);actor.animate(&"draw",phase,true)
  var prop=actor.held_props[&"bow"]
  var hand:Vector3=actor.to_global(actor.rig.posed[6 if actor.last_pose.active==1 else 9].origin)
  if phase<.26:
   require(not prop.nocked.visible,"Arrow appears after the nocking hand joins the raised bow")
   require((prop.string_segments[0].global_transform*Vector3(0,.5,0)).distance_to(prop.to_global(prop.rest_nock))<.001,"The string stays at rest while the bow is first lifted")
  else:
   require(prop.nocked.global_position.distance_to(hand)<0.001,"Arrow nock follows the actual drawing hand")
   require((prop.string_segments[0].global_transform*Vector3(0,0.5,0)).distance_to(hand)<0.001,"Bow string terminates at the actual drawing hand")
 actor.family_override=&"bottle";actor.aim_contact=Vector3.INF;actor.animate(&"drink",0.5,true)
 var mouth:Vector3=actor.to_global(actor.last_pose.body*preload("res://scripts/prototype_3d/survivor_anatomy.gd").MOUTH)
 require(actor.grip_socket.to_global(preload("res://scripts/prototype_3d/held_profiles.gd").profile(&"bottle").tip).distance_to(mouth)<actor.scale.x*2,"Bottle mouth approaches lips rather than forehead")
 var uid:int=game.bag.held_item().uid;var location:Dictionary=game.bag.location(uid)
 game.player.action_elapsed=-1;require(game.player.select_quick(location.index) and not game.player.equipped,"Pressing active quick key frees hands")
 game.player.equip_elapsed=-1
 require(game.player.select_quick(location.index) and game.player.equipped,"Pressing again equips the same object instance")
 print("%s: %d 3D equipment, contact, bow and armor checks"%["PASS" if failures==0 else "FAIL",checks])
 game.free();quit(1 if failures else 0)
