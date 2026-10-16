extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1280,900)
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();game.use_test_layout=true;root.add_child(game)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false);game.camera_rig.set_physics_process(false)
 for enemy in get_nodes_in_group("prototype_enemies"):enemy.set_physics_process(false)
 for ui in game.find_children("*","CanvasLayer",true,false):ui.visible=false
 game.player.position=Vector3(2,0,2);game.player.model.rotation.y=0
 var actor=game.player.model;actor.family_override=&"axe";actor.wear({"id":&"burdock_armor"});actor.animate(&"idle",0,true)
 var rock=load("res://scripts/prototype_3d/rock.gd").new();game.add_child(rock);rock.configure(1);rock.position=Vector3(3.1,0,1)
 for id:StringName in [&"pickaxe",&"bow"]:
  var prop=load("res://scripts/prototype_3d/item_models.gd").create({"id":id});game.add_child(prop);prop.position=Vector3(1.3 if id==&"bow" else 2.0,.02,2.7)
 var camera:=Camera3D.new();game.add_child(camera);camera.fov=40;camera.position=game.player.position+Vector3(2.8,2,4.5);camera.look_at(game.player.position+Vector3(.25,.7,0));camera.current=true
 for i in 5:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/previews/meshy_gear_in_game.png")
 game.free();quit()
