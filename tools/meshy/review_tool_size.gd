extends SceneTree
## Real held meshes and grip poses at the user's 60% tool scale.
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1600,1000)
 var cases=[[&"idle",0.0,"Reposo"],[&"walk",.25,"Marcha"],[&"equip",.65,"Equipar"],[&"action",.5,"Golpe bajo"]]
 for row in 2:
  for column in 4:
   var box:=SubViewportContainer.new();box.position=Vector2(column*400,row*500+30);box.size=Vector2(400,470);root.add_child(box)
   var viewport:=SubViewport.new();viewport.own_world_3d=true;viewport.size=Vector2i(400,470);box.add_child(viewport)
   var label:=Label.new();label.text=("Hacha" if row==0 else "Pico")+" · "+cases[column][2];label.position=Vector2(column*400+8,row*500+4);label.add_theme_font_size_override("font_size",18);root.add_child(label)
   var world:=Node3D.new();viewport.add_child(world)
   var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("444c51");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.75;world.add_child(env)
   var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-30,0);world.add_child(light)
   var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();world.add_child(actor);actor.family_override=&"axe" if row==0 else &"pickaxe";actor.aim_contact=Vector3(0,14,28)
   actor.animate(cases[column][0],cases[column][1],true,0,.25)
   var camera:=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=76;camera.position=Vector3(95,51,145);camera.look_at(Vector3(0,31,2))
 for i in 5:await process_frame
 await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png("res://docs/previews/tools_reduced_grips.png")==OK)
 for child in root.get_children():child.queue_free()
 await process_frame;quit()
