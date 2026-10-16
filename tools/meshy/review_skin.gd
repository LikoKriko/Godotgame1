extends SceneTree
## Compare untouched source shading with the skin-only polish, close up.
func _initialize():call_deferred("run")
func run():
 var args:=OS.get_cmdline_user_args();assert(args.size()==2,"Pass original.glb output.png")
 root.size=Vector2i(1400,1760);var mesh:Mesh=load("res://assets/characters/prototype_3d/meshy/survivor_skin.res")
 for row in 2:
  for column in 2:
   var title:=Label.new();title.text=("Original" if column==0 else "Pulido")+(" · frente" if row==0 else " · espalda");title.position=Vector2(column*700+12,row*880+8);title.add_theme_font_size_override("font_size",22);root.add_child(title)
   var box:=SubViewportContainer.new();box.position=Vector2(column*700,row*880+30);box.size=Vector2(700,850);root.add_child(box)
   var viewport:=SubViewport.new();viewport.size=Vector2i(700,850);viewport.own_world_3d=true;box.add_child(viewport)
   var world:=Node3D.new();viewport.add_child(world)
   var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("444c51");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.75;world.add_child(env)
   var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-30,0);world.add_child(light)
   if column==0:
    var doc:=GLTFDocument.new();var state:=GLTFState.new();assert(doc.append_from_file(args[0],state)==OK)
    var original:=doc.generate_scene(state);world.add_child(original);original.scale=Vector3.ONE*float(mesh.get_meta("uniform_scale"));original.position=mesh.get_meta("translation")
    for part:MeshInstance3D in original.find_children("*","MeshInstance3D",true,false):part.material_override=mesh.get_meta("source_material")
   else:
    var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();world.add_child(actor);actor.family_override=&"";actor.animate(&"idle",0,false)
   var camera:=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=42
   camera.position=Vector3(0,48,140 if row==0 else -140);camera.look_at(Vector3(0,44,1))
 for i in 5:await process_frame
 await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png(args[1])==OK)
 for child in root.get_children():child.queue_free()
 await process_frame;quit()
