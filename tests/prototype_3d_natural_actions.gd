extends SceneTree
## Camera selection, authored contact and inventory commit must agree.
const Clips=preload("res://scripts/prototype_3d/survivor_animation.gd")
class AimTarget extends StaticBody3D:
 var health:=10
 func _init():
  collision_layer=8;collision_mask=0;add_to_group("prototype_trees")
  var shape=CollisionShape3D.new();shape.shape=SphereShape3D.new();shape.shape.radius=0.025;add_child(shape)
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func face(player,point:Vector3) -> void:
 for frame in 60:player.update_facing(point,1.0/60)
func run():
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();game.use_test_layout=true;root.add_child(game)
 game.set_physics_process(false);game.player.set_physics_process(false)
 for enemy in get_nodes_in_group("prototype_enemies"):enemy.set_physics_process(false)
 var player=game.player;var rig=game.camera_rig;var actor=player.model
 player.position=Vector3(12,0,12);rig.yaw=0;rig.pitch=-0.12
 var small=AimTarget.new();game.add_child(small)
 for dimensions:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1024,768)]:
  root.size=dimensions;await process_frame;await physics_frame;rig.update(1)
  var center:=root.get_visible_rect().size*.5
  var radius:float=root.get_visible_rect().size.y*rig.ACTION_RADIUS
  small.global_position=rig.camera.project_position(center+Vector2(radius*.5,0),4.4)
  await physics_frame
  var exact:Dictionary=rig.aim_sample();var assisted:Dictionary=rig.action_sample()
  require(exact.hit.is_empty() or exact.hit.collider!=small,"Small target really misses the exact center ray")
  require(not assisted.hit.is_empty() and assisted.hit.collider==small,"Small target inside the reticle tolerance is selected at every resolution")
  require(rig.camera.unproject_position(assisted.point).distance_to(center)<=radius+.1,"Contact stays inside the small screen-space disk")
  require(assisted.point==assisted.hit.position,"Animation and hit use the same physical point")
  var centered=AimTarget.new();game.add_child(centered);centered.global_position=rig.camera.project_position(center,4.4)
  await physics_frame
  require(rig.action_sample().hit.get("collider")==centered,"Exact center target wins over a nearby candidate")
  centered.free()
  small.global_position=rig.camera.project_position(center+Vector2(radius*2.2,0),4.4)
  await physics_frame
  require(rig.action_sample().hit.get("collider")!=small,"Assistance cannot acquire a target outside the disk")
  small.global_position=rig.camera.project_position(center+Vector2(radius*.5,0),4.4)
  var wall=StaticBody3D.new();var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(1,1,.08);wall.add_child(shape);game.add_child(wall);wall.global_position=rig.camera.project_position(center,4.0)
  await physics_frame
  require(rig.action_sample().hit.get("collider")!=small,"First-surface rays cannot select a resource behind an occluding wall")
  wall.free()
 small.free()
 # All families retain one topology; the torso and pelvis have independent
 # but coordinated rotations, while supports and anatomical lengths survive.
 var mesh:Mesh=actor.mesh_node.mesh
 for family in Clips.FAMILIES:
  actor.family_override=family
  for state in [&"walk",&"run",&"crouch_walk",&"action",&"equip",&"unequip",&"jump",&"eat",&"drink",&"parry",&"hurt",&"death"]:
   for frame in 12:
    var t:=frame/12.0;actor.aim_contact=Vector3(0,38,32)
    actor.animate(state,t,family!=&"",0,t,Vector3.BACK if state in [&"walk",&"run",&"crouch_walk"] else Vector3.ZERO)
    require(actor.grip_error<.045,"Natural body dynamics keep occupied hands on their grips")
    for leg in actor.last_pose.legs:
     require(absf(leg.root.distance_to(leg.joint)-preload("res://scripts/prototype_3d/survivor_anatomy.gd").THIGH)<.001 and absf(leg.joint.distance_to(leg.end)-preload("res://scripts/prototype_3d/survivor_anatomy.gd").THIGH)<.001,"Dynamic weight transfer cannot stretch leg bones")
 require(actor.mesh_node.mesh==mesh,"Natural motion preserves the original bind mesh")
 var gait:=Clips.sample(&"axe",&"walk",.25,.25,Vector3.BACK)
 require(gait.body.basis.get_rotation_quaternion().angle_to(gait.pelvis.basis.get_rotation_quaternion())>.04,"Chest and pelvis counter-rotate instead of moving as one rigid block")
 for family in [&"axe",&"pickaxe",&"sword"]:
  actor.family_override=family
  for point:Vector3 in [Vector3(0,14,28),Vector3(0,30,32),Vector3(0,42,31)]:
   actor.aim_contact=point;actor.animate(&"action",.5,true)
   require(actor.last_pose.get("contact_reachable",false),"Near low/medium/high melee contact can be reached with a hip hinge")
   require(actor.tip_socket.position.distance_to(point)<.03,"The physical tool tip reaches the selected surface at impact")
 # Directed pickups cover reachable low/high contacts, all phases, and explicit
 # contact accuracy of the rendered hand, not only an authored target.
 actor.family_override=&""
 for pickup_state in [&"pickup",&"pickup_walk"]:
  for point:Vector3 in [Vector3(0,4,26),Vector3(0,6,30),Vector3(5,18,20),Vector3(-4,32,19)]:
   actor.aim_contact=point
   for frame in 33:
    var t:=frame/32.0;actor.animate(pickup_state,t,false,0,t,Vector3.BACK if pickup_state==&"pickup_walk" else Vector3.ZERO)
    for leg in actor.last_pose.legs:
     require(leg.end.y>=1 and leg.joint.y>=.5,"Pickup feet and knees stay above the floor throughout entry/contact/recovery")
    if frame==16:
     require(actor.rig.posed[9].origin.distance_to(point)<.03,"Rendered palm reaches the exact selected pickup point")
     require(actor.last_pose.contact_reachable if actor.last_pose.has("contact_reachable") else true,"Pickup contact is anatomically reachable")
 # The real E path keeps the object visible until the hand arrives, and rejects
 # repeat presses, walking out of reach and capacity failure without item loss.
 var rock=get_nodes_in_group("prototype_rocks")[0]
 player.position=rock.global_position+Vector3(0,0,.9);player.equipped=false;game.bag.active_quick_uid=-1;player.preview_state=&""
 rig.update(1);rig.camera.look_at(rock.global_position+Vector3.UP*.13);await physics_frame
 var before:int=game.bag.count(&"piedra")
 require(game.interact() and rock.visible and game.bag.count(&"piedra")==before,"E begins reach with no early inventory transfer")
 require(not game.interact(),"Repeated E cannot start a duplicate pickup")
 face(player,player.pickup_point)
 player.advance_preview(Clips.duration(&"pickup")*.49)
 require(rock.visible and game.bag.count(&"piedra")==before,"Item persists until the contact threshold")
 player.advance_preview(Clips.duration(&"pickup")*.01)
 require(not rock.visible and game.bag.count(&"piedra")==before+2,"Exactly one transfer occurs when the hand arrives")
 player.advance_preview(1)
 require(game.bag.count(&"piedra")==before+2,"Recovery cannot apply the pickup a second time")
 var drop=game.corpse_loot.spawn_drop(game.bag.make_item(&"palo",1),Vector3(12,0,12))
 player.position=drop.global_position+Vector3(0,0,.8);player.preview_state=&""
 rig.update(1);rig.camera.look_at(drop.global_position+Vector3.UP*.05);await physics_frame
 require(game.interact(),"Dropped item can begin a directed pickup")
 player.position+=Vector3(0,0,3);face(player,player.pickup_point);player.advance_preview(Clips.duration(&"pickup")*.5)
 require(not drop.item.is_empty(),"Moving out of arm reach cannot collect a distant item")
 player.advance_preview(1);player.position=drop.global_position+Vector3(0,0,.8)
 for i in game.bag.slots.size():game.bag.slots[i]=game.bag.make_item(&"sword",1)
 rig.update(1);rig.camera.look_at(drop.global_position+Vector3.UP*.05);await physics_frame
 require(game.interact(),"Capacity is checked at actual contact")
 face(player,player.pickup_point);player.advance_preview(Clips.duration(&"pickup")*.5)
 require(not drop.item.is_empty() and drop.visible,"Full inventory cannot destroy or hide the world item")
 game.free();print("%s: %d natural motion, reticle tolerance and timed pickup checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
