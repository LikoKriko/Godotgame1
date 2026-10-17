extends SceneTree
## Real K-menu spawn and in-world height relative to the survivor.
func _initialize():call_deferred("run")
func run() -> void:
 root.size=Vector2i(1280,900)
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();game.use_test_layout=true;root.add_child(game);game.paused=true
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false);game.camera_rig.set_physics_process(false)
 for enemy in get_nodes_in_group("prototype_enemies"):enemy.set_physics_process(false)
 game.player.position=Vector3(0,0,2);game.player.model.rotation.y=0;game.player.model.animate(&"idle",0,true)
 game.distance_optimization.set_process(false)
 game.paused=false;game.toggle_catalog();game.item_catalog.sprout_button.pressed.emit()
 assert(get_nodes_in_group("prototype_sprouts").size()==1)
 for i in 5:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/previews/enemy3_k_menu.png")
 game.item_catalog.hide();game.paused=true
 var enemy=get_nodes_in_group("prototype_sprouts")[0];enemy.set_physics_process(false);enemy.position.y=0;enemy.phase=.71;enemy.show_pose(false)
 for ui in game.find_children("*","CanvasLayer",true,false):ui.visible=false
 var camera:=Camera3D.new();game.add_child(camera);camera.fov=40;camera.position=Vector3(4.5,2.7,-3);camera.look_at(Vector3(1.3,.75,2));camera.current=true
 for i in 5:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/previews/enemy3_in_game.png")
 game.free();quit()
