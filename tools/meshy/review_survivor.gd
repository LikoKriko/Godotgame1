extends SceneTree
## Render a fair original-FBX vs live-skin comparison and an action contact sheet.
## Pass -- /absolute/unrigged/source.glb [output directory].
var output:="res://docs/previews"
func _initialize():call_deferred("run")
func setup_view(column:int,row:int,label:String) -> Dictionary:
 var viewport:=SubViewport.new();viewport.size=Vector2i(400,400);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 var box:=SubViewportContainer.new();box.position=Vector2(column*400,row*440+40);box.size=Vector2(400,400);root.add_child(box);box.add_child(viewport)
 var title:=Label.new();title.text=label;title.position=Vector2(column*400+10,row*440+10);title.add_theme_font_size_override("font_size",18);root.add_child(title)
 var world:=Node3D.new();viewport.add_child(world)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("444c51");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.75;world.add_child(env)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-30,0);world.add_child(light)
 var cam:=Camera3D.new();cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=78;world.add_child(cam)
 return {"world":world,"camera":cam}
func point_camera(cam:Camera3D,angle:float) -> void:
 cam.position=Vector3(sin(angle)*200,48,cos(angle)*200);cam.look_at(Vector3(0,32,1))
func capture(path:String) -> void:
 for frame in 4:await process_frame
 await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png(output+"/"+path)==OK)
func clear_views() -> void:
 for child in root.get_children():child.queue_free()
 await process_frame
func run():
 var args:=OS.get_cmdline_user_args();assert(not args.is_empty(),"Pass the original unrigged GLB")
 if args.size()>1:output=args[1]
 root.size=Vector2i(1600,880);root.content_scale_size=Vector2i.ZERO
 var mesh:Mesh=load("res://assets/characters/prototype_3d/meshy/survivor_skin.res")
 var views:=["Frente","Lateral derecho","Espalda","Lateral izquierdo"]
 for row in 2:
  for column in 4:
   var view:=setup_view(column,row,("FBX original · " if row==0 else "En juego · ")+views[column])
   if row==0:
    var document:=GLTFDocument.new();var state:=GLTFState.new();assert(document.append_from_file(args[0],state)==OK)
    var original:=document.generate_scene(state);view.world.add_child(original)
    original.scale=Vector3.ONE*float(mesh.get_meta("uniform_scale"));original.position=mesh.get_meta("translation")
    for part:MeshInstance3D in original.find_children("*","MeshInstance3D",true,false):part.material_override=mesh.get_meta("source_material",mesh.surface_get_material(0))
   else:
    var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();view.world.add_child(actor);actor.family_override=&"";actor.animate(&"idle",0,false)
   point_camera(view.camera,[0.0,-PI/2,PI,PI/2][column])
 await capture("survivor_meshy_comparison.png")
 await clear_views()
 var cases=[[&"walk",&"",.25],[&"run",&"",.25],[&"action",&"axe",.5],[&"draw",&"bow",1.0],[&"pickup",&"",.5],[&"drink",&"bottle",.5],[&"slide",&"",.5],[&"action",&"axe",.7]]
 for i in cases.size():
  var view:=setup_view(i%4,i/4,"Armadura · recuperación" if i==7 else String(cases[i][0]))
  var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();view.world.add_child(actor)
  actor.family_override=cases[i][1];actor.displayed_item=&"botella" if i==5 else cases[i][1];actor.item_water_ml=500;actor.nock_visible=i==3
  actor.aim_contact=Vector3(4,3,20) if i==4 else (Vector3(0,36,32) if i in [2,7] else Vector3.INF)
  if i==7:actor.wear({"id":&"burdock_armor"})
  actor.animate(cases[i][0],cases[i][2],cases[i][1]==&"axe",0,.25)
  view.camera.size=100
  point_camera(view.camera,-PI/5)
 await capture("survivor_meshy_actions.png")
 await clear_views();quit()
