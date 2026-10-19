extends SceneTree
## Render the current rock, refresh its two icons and show its metre scale.
func _initialize():call_deferred("run")
func run() -> void:
 root.size=Vector2i(256,256);root.transparent_bg=true
 var world:=Node3D.new();root.add_child(world)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_CLEAR_COLOR;env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.7;world.add_child(env)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-30,0);world.add_child(light)
 var rock:=MeshInstance3D.new();rock.mesh=load("res://assets/models/meshy/rock1/model.res");world.add_child(rock)
 var camera:=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.65;camera.position=Vector3(3,3.4,6);camera.look_at(Vector3(0,.5,0))
 await frames()
 var icon:=root.get_texture().get_image()
 assert(icon.save_png("res://assets/models/meshy/rock1/icon.png")==OK)
 assert(icon.save_png("res://assets/items/prototype_3d/icons/piedra.png")==OK)
 root.size=Vector2i(1200,800);root.transparent_bg=false;env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("444c51")
 var hero=load("res://scripts/prototype_3d/survivor_model.gd").new();world.add_child(hero);hero.scale=Vector3.ONE*1.75/64;hero.position=Vector3(-2.4,0,0);hero.animate(&"idle",0,true)
 var plane:=MeshInstance3D.new();plane.mesh=PlaneMesh.new();plane.mesh.size=Vector2(10,8);plane.position.y=-.005;world.add_child(plane)
 camera.size=5.5;camera.position=Vector3(4,3.1,7);camera.look_at(Vector3(-.8,.65,0))
 var title:=Label.new();title.text="Roca1 · 1 metro de altura · 11.931 triángulos";title.position=Vector2(22,18);title.add_theme_font_size_override("font_size",25);root.add_child(title)
 await frames()
 assert(root.get_texture().get_image().save_png("res://docs/previews/rock1_optimized.png")==OK)
 world.queue_free();await process_frame;quit()
func frames() -> void:
 for i in 5:await process_frame
 await RenderingServer.frame_post_draw
