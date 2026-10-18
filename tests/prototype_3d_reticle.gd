extends SceneTree
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func face(player,point:Vector3) -> void:
 for frame in 90:player.update_facing(point,1.0/60)
func run() -> void:
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();game.use_test_layout=true;root.add_child(game)
 game.set_physics_process(false);game.player.set_physics_process(false)
 for enemy in get_nodes_in_group("prototype_enemies"):enemy.set_physics_process(false)
 var player=game.player;var rig=game.camera_rig
 var reticle:Control=game.find_child("Reticle",true,false)
 for dimensions:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1024,768)]:
  root.size=dimensions
  await process_frame;await process_frame
  require(reticle!=null and reticle.get_global_rect().get_center().distance_to(root.get_visible_rect().get_center())<.01,"Drawn reticle remains at the physics-ray center after viewport resizing")
 for hud_size in [1,5]:
  game.settings.values.hud_size=hud_size;game.hud.fit()
  require(reticle.get_global_rect().get_center().distance_to(root.get_visible_rect().get_center())<.01,"HUD scaling cannot shift the aiming point")
 player.position=Vector3(12,0,12);rig.yaw=0;rig.pitch=0
 player.velocity=Vector3.DOWN;player.move_and_slide() # Establish real support for melee.
 await physics_frame;rig.update(1)
 var anchor:Vector3=player.position+Vector3(0,1.45,0)
 var center:Vector2=root.get_visible_rect().get_center()
 var close_gap:float=absf(rig.camera.unproject_position(anchor).x-center.x)
 var current:Vector3=rig.camera.position
 rig.camera.position.x=.60
 var old_gap:float=absf(rig.camera.unproject_position(anchor).x-center.x)
 rig.camera.position=current
 require(absf(close_gap-old_gap*.5)<.01,"Actual projected character-to-reticle gap is halved, not just the drawn dot moved")
 for direction in 16:
  var angle:=direction*TAU/16
  var point:Vector3=player.position+Vector3(sin(angle),.8,cos(angle))*.8
  player.action_elapsed=-1;face(player,point)
  var wanted:=Vector3(point.x-player.position.x,0,point.z-player.position.z).normalized()
  require(player.model.global_basis.z.normalized().dot(wanted)>.99999,"Standing body converges on nearby reticle contacts at every yaw")
  player.action_elapsed=0;player.action_point=point
  player.position+=Vector3(.15,0,-.08)
  face(player,player.position-Vector3.BACK*30)
  wanted=Vector3(point.x-player.position.x,0,point.z-player.position.z).normalized()
  require(player.model.global_basis.z.normalized().dot(wanted)>.99999,"Moving during a locked melee action keeps facing its contact, not the new camera ray")
  require(player.action_point==point,"Facing adjustments do not retarget a melee strike")
  player.position=Vector3(12,0,12)
 player.action_elapsed=-1
 for height in [-20.0,20.0]:
  face(player,player.position+Vector3(0,height,0))
  require(player.model.global_basis.is_finite() and player.model.global_basis.z.normalized().dot(Vector3.BACK)< -.999,"Vertical aim keeps stable camera yaw rather than flipping at the feet")
 # Real center-ray selection, reachable hit and physical blade tip, using the
 # production camera boom and a curved trunk, without a separate player ray.
 var tree=get_nodes_in_group("prototype_trees")[0]
 var point:Vector3=tree.global_position+Vector3(0,1.39,0)
 player.position=Vector3(point.x,0,point.z+.85)
 var offset:Vector3=point-(player.position+Vector3(0,1.45,0))
 var flat:=Vector2(offset.x,offset.z).length()
 rig.yaw=atan2(-offset.x,-offset.z)+asin(rig.SHOULDER/flat)
 var forward_distance:=sqrt(flat*flat-rig.SHOULDER*rig.SHOULDER)
 rig.pitch=atan2(offset.y,forward_distance)-asin(.12/sqrt(offset.y*offset.y+forward_distance*forward_distance))
 await physics_frame;rig.update(1)
 var aim:Dictionary=rig.aim_sample()
 require(not aim.hit.is_empty() and game.target_owner(aim.hit.collider)==tree,"Visible center ray selects the nearby real trunk")
 require(rig.camera.unproject_position(aim.point).distance_to(center)<.05,"Interaction contact projects onto the exact visible reticle")
 face(player,aim.point)
 game.bag.select_tool(&"axe");player.equipped=true;player.equip_elapsed=-1
 require(player.strike(),"Axe attack starts from the visible contact")
 require(player.action_target.position.distance_to(player.action_point)<.00001,"Target collider and animation share one sampled contact")
 face(player,aim.point)
 player.model.family_override=&"axe";player.model.aim_contact=player.model.to_local(player.action_point)
 player.model.animate(&"action",.5,true)
 require(player.model.tip_socket.global_position.distance_to(player.action_point)<.015,"Rendered blade tip reaches the same contact selected by the reticle")
 var health:int=tree.health
 player.advance_action(player.Clips.duration(&"action",&"axe")*.5)
 require(tree.health==health-1,"Clicking the reachable trunk actually applies the axe impact")
 game.free();print("%s: %d reticle projection, facing, locked-contact and physical-impact checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
