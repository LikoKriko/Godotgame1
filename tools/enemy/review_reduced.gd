extends SceneTree
## Render actual runtime skins and key poses; optional output folder.
func _initialize():call_deferred("run")
func run():
 var args:=OS.get_cmdline_user_args();var folder:String=args[0] if not args.is_empty() else "/tmp/mossclaw-review"
 DirAccess.make_dir_recursive_absolute(folder);root.size=Vector2i(640,640)
 var world:=Node3D.new();root.add_child(world)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("444c51");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.7;world.add_child(env)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-25,0);world.add_child(light)
 var camera:=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=52
 var actor=load("res://scripts/prototype_3d/young_model.gd").new();world.add_child(actor)
 for state:StringName in [&"reference",&"idle",&"walk",&"attack",&"boxing_guard",&"hook",&"death",&"corpse"]:
  for side in 2:
   actor.animate(state,1.0 if state in [&"death",&"corpse"] else .5,side==0)
   for view in 2:
    var angle:=0.0 if view==0 else deg_to_rad(68)
    camera.position=Vector3(sin(angle)*100,24,cos(angle)*100);camera.look_at(Vector3(0,15,0))
    await capture(folder+"/"+String(state)+"_%d_%d.png"%[side,view])
 world.free();await process_frame
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();game.use_test_layout=true;root.add_child(game);freeze(game)
 for layer in game.find_children("*","CanvasLayer",true,false):layer.visible=false
 var enemy=get_nodes_in_group("prototype_enemies")[0];enemy.position=Vector3.ZERO;enemy.model.animate(&"idle",0,true);game.player.hide()
 var cam:=Camera3D.new();game.add_child(cam);cam.current=true;cam.fov=40;cam.position=Vector3(1.7,1.15,2.9);cam.look_at(Vector3(0,.43,0))
 root.size=Vector2i(1000,800);await capture("res://docs/previews/young_reduced_in_game.png")
 game.free();quit()
func freeze(node:Node):
 node.set_process(false);node.set_physics_process(false)
 for child in node.get_children():freeze(child)
func capture(path:String):
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png(path)==OK)
