extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(900,900)
 var world:=Node3D.new();root.add_child(world)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("444c51");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.65;world.add_child(env)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-30,0);world.add_child(light)
 var bottle:=MeshInstance3D.new();bottle.mesh=load("res://assets/items/prototype_3d/bottle_meshy/bottle.res");world.add_child(bottle)
 var cam:=Camera3D.new();world.add_child(cam);cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=13;var center:=bottle.mesh.get_aabb().get_center();cam.position=center+Vector3(16,7.4,25);cam.look_at(center)
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/previews/bottle_meshy.png")
 root.size=Vector2i(256,256);root.transparent_bg=true;env.environment.background_mode=Environment.BG_CLEAR_COLOR
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 var icon:=root.get_texture().get_image()
 icon.save_png("res://assets/items/prototype_3d/bottle_meshy/icon.png")
 for id in ["botella","botella_full","water"]:icon.save_png("res://assets/items/prototype_3d/icons/"+id+".png")
 world.free();quit()
