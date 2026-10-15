extends SceneTree
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var world=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();world.use_test_layout=true;root.add_child(world)
 world.player.set_physics_process(false)
 await physics_frame
 require(world.player is CharacterBody3D and world.camera_rig.camera is Camera3D,"Prototype uses real 3D physics and perspective camera")
 require(world.player.model.axe.get_child_count()>5,"Axe contains solid blade, wooden shaft and rope geometry")
 var bind_mesh: Mesh = world.player.model.mesh_node.mesh
 require(world.player.model.rig.skeleton.get_bone_count()==20,"Humanoid has an articulated skeleton with four cloth controls")
 require(absf(world.player.model.mesh_node.mesh.get_aabb().size.y*world.player.model.scale.y-1.75)<0.001,"Survivor standing height is exactly 1.75 metres")
 var arrays: Array = bind_mesh.surface_get_arrays(0)
 var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
 var normalized_weights := not weights.is_empty()
 for i in range(0,weights.size(),4):
  normalized_weights = normalized_weights and absf(weights[i]+weights[i+1]+weights[i+2]+weights[i+3]-1)<0.001
 require(normalized_weights,"Every skin vertex has normalized weights")
 require(world.player.model.body_material.get_shader_parameter("painted_materials") is Texture2D,"Painted atlas is imported and assigned")
 var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
 var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
 var outward_torso := false
 for i in vertices.size():
  if absf(vertices[i].x)<0.001 and vertices[i].y>39 and vertices[i].y<44 and vertices[i].z>2.5:
   outward_torso = normals[i].z>0.5
   break
 require(outward_torso,"Torso normals face outward for correct lighting")
 for state in [&"idle",&"walk",&"run",&"crouch",&"crouch_walk",&"slide",&"jump",&"slide_jump",&"equip_walk",&"action"]:
  for i in 12:
   world.player.model.animate(state,i/11.0,true)
   require(world.player.model.grip_error<0.04,"Both hands retain their anatomical grip")
   require(world.player.model.mesh_node.mesh.get_aabb().size.y>30,"Whole character has nonzero volume")
   var bones: Array[Transform3D] = world.player.model.rig.posed
   for side in 2:
    var arm := 4+side*3; var leg := 10+side*3
    require(absf(bones[arm].origin.distance_to(bones[arm+1].origin)-10)<0.001,"Upper arm retains bone length")
    require(absf(bones[leg].origin.distance_to(bones[leg+1].origin)-12.5)<0.001,"Thigh retains bone length")
 require(world.player.model.mesh_node.mesh==bind_mesh,"Animation never rebuilds the skin mesh")
 world.player.model.animate(&"walk",0.2,false,0,0.2,Vector3.RIGHT)
 require(world.player.model.last_pose.legs[0].end.x>-3.4,"Strafe gait moves feet sideways relative to the facing direction")
 world.player.model.animate(&"walk",0.2,false,0,0.2,Vector3.FORWARD)
 require(world.player.model.last_pose.legs[0].end.z<0,"Backward gait follows the actual travel direction")
 var original:float=world.camera_rig.yaw;world.camera_rig.look(Vector2(100,100000))
 require(world.camera_rig.yaw!=original and absf(world.camera_rig.pitch+PI/2)<0.00001,"Mouse orbit reaches the full downward pole without inverting")
 world.camera_rig.pitch = -0.12; world.camera_rig.yaw = 0
 world.player.position = Vector3(-0.6,0,-0.65); world.camera_rig.update(1.0)
 await physics_frame
 require(not world.camera_rig.target().is_empty(),"Reticle selects a real trunk with a physics ray")
 var selected: Dictionary = world.camera_rig.target()
 var toward: Vector3=selected.position-world.player.global_position
 world.player.model.rotation.y=atan2(toward.x,toward.z)
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
