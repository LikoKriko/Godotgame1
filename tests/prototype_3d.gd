extends SceneTree
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var world=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();root.add_child(world)
 world.player.set_physics_process(false)
 await physics_frame
 require(world.player is CharacterBody3D and world.camera_rig.camera is Camera3D,"Prototype uses real 3D physics and perspective camera")
 require(world.player.model.axe.get_child_count()>5,"Axe contains solid blade, wooden shaft and rope geometry")
 for state in [&"idle",&"walk",&"run",&"equip",&"action"]:
  for i in 12:
   world.player.model.animate(state,i/11.0,true)
   require(world.player.model.grip_error<0.04,"Both hands retain their anatomical grip")
   require(world.player.model.mesh_node.mesh.get_aabb().size.y>30,"Whole character has nonzero volume")
 require(world.player.model.cached_poses.size()<=64,"Pose cache is bounded")
 var original:float=world.camera_rig.yaw;world.camera_rig.look(Vector2(100,100000))
 require(world.camera_rig.yaw!=original and world.camera_rig.pitch<=deg_to_rad(65),"Mouse orbit and pitch limits work")
 world.camera_rig.pitch = -0.12; world.camera_rig.yaw = 0
 world.player.position = Vector3(-0.6,0,0); world.camera_rig.update(1.0)
 await physics_frame
 require(not world.camera_rig.target().is_empty(),"Reticle selects a real trunk with a physics ray")
 var selected: Dictionary = world.camera_rig.target()
 var before: int = world.bag.held_item().uses
 require(world.resolve_hit(selected) and world.bag.held_item().uses==before-1,"Successful axe contact spends one use")
 world.player.position = Vector3(0.6,0,8)
 require(not world.resolve_hit(selected) and world.bag.held_item().uses==before-1,"Out-of-range strikes cannot spend uses or collect wood")
 world.player.position = Vector3(-6.55,0,-2);world.camera_rig.update(1.0)
 await physics_frame
 world.camera_rig.update(1.0)
 require(world.camera_rig.actual_distance<world.camera_rig.DISTANCE,"Camera sphere shortens the orbit at the test wall")
 var tree=get_nodes_in_group("prototype_trees")[1]
 require(tree.hit() and tree.hit() and tree.hit() and tree.health==0 and not tree.visible,"Three axe hits deplete the tree")
 require(not tree.hit(),"Depleted trees cannot duplicate rewards")
 world.toggle_pause();require(world.paused and world.pause_panel.visible,"Pause releases player control")
 world.toggle_pause();require(not world.paused,"Resume restores player control")
 print("%s: %d 3D prototype checks, %d failures" %["PASS" if failures==0 else "FAIL",checks,failures]);world.free();quit(1 if failures else 0)
