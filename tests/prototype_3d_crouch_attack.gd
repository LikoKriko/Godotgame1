extends SceneTree
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func key(code:int,pressed:bool):
 var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;Input.parse_input_event(event)
func _initialize():call_deferred("run")
func run():
 var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();root.add_child(actor)
 for family in [&"",&"axe",&"pickaxe",&"sword",&"bow"]:
  actor.family_override=family
  var state:StringName=&"draw" if family==&"bow" else &"action"
  actor.aim_contact=Vector3(0,28,30)
  for frame in 33:
   var t:=frame/32.0
   actor.action_crouch=0;actor.animate(state,t,family!=&"")
   var standing:Vector3=actor.rig.posed[0].origin
   actor.action_crouch=1;actor.animate(state,t,family!=&"")
   require(actor.rig.posed[0].origin.y<standing.y-5.5,"The whole attack remains crouched instead of selecting the standing gesture")
   require(actor.grip_error<.045,"Crouched tool gestures preserve both grips")
   for leg in actor.last_pose.legs:
    require(absf(leg.root.distance_to(leg.joint)-preload("res://scripts/prototype_3d/survivor_anatomy.gd").THIGH)<.001 and absf(leg.joint.distance_to(leg.end)-preload("res://scripts/prototype_3d/survivor_anatomy.gd").THIGH)<.001,"Crouched attacks bend knees without shortening legs")
   if frame==16 and family in [&"axe",&"pickaxe",&"sword"]:
    require(actor.can_reach_contact(actor.aim_contact,family),"Reach checks use the same crouched anatomy as animation")
    require(actor.tip_socket.position.distance_to(actor.aim_contact)<.03,"Crouched attack still ends at the selected aim contact")
 actor.free()
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();game.use_test_layout=true;root.add_child(game);game.set_physics_process(false);game.settings.values.auto_run=false
 for enemy in get_nodes_in_group("prototype_enemies"):enemy.set_physics_process(false)
 var player=game.player;player.position=Vector3(12,.05,12)
 for i in 20:await physics_frame
 key(KEY_CTRL,true)
 for i in 15:await physics_frame
 require(player.locomotion.crouch>.99,"Actual Ctrl input enters crouch")
 for family in [&"axe",&"pickaxe",&"sword"]:
  game.bag.select_tool(family);player.equipped=true;player.equip_elapsed=-1
  require(player.strike(),"Holding Ctrl allows a new melee attack with "+String(family))
  var seconds:float=player.Clips.duration(&"action",family)
  for i in int(ceil(seconds*60))+3:
   await physics_frame
   require(player.model.action_crouch>.99 and player.locomotion.crouch>.99,"Ctrl keeps crouch active through the entire attack and recovery")
  require(player.action_elapsed<0,"Crouched attack finishes and allows the next attack")
 key(KEY_W,true)
 require(player.strike(),"Player can attack while walking crouched")
 for i in 12:await physics_frame
 require(Vector2(player.velocity.x,player.velocity.z).length()<1.1 and player.model.action_crouch>.99,"Moving attack retains crouch speed and posture")
 key(KEY_W,false);key(KEY_CTRL,false)
 for i in 15:await physics_frame
 require(player.locomotion.crouch<.01 and player.model.action_crouch<.01,"Releasing Ctrl restores standing posture smoothly, including during an attack")
 game.free();print("%s: %d crouched attack, contact, grip and live Ctrl checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
