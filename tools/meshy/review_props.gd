extends SceneTree
## Actual imported resources and worn/held poses, rendered by Godot.
func _initialize():call_deferred("run")
func run():
 var args:=OS.get_cmdline_user_args()
 var output:String=args[0] if not args.is_empty() else "/tmp/day-zero-meshy-review"
 DirAccess.make_dir_recursive_absolute(output)
 root.size=Vector2i(640,640)
 var world:=Node3D.new();root.add_child(world)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("444c51");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.7;world.add_child(env)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-30,0);world.add_child(light)
 var camera:=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 for id:String in ["axe","pickaxe","bow","leaf_armor","rock1"]:
  var node:=MeshInstance3D.new();node.mesh=load("res://assets/models/meshy/"+id+"/model.res");world.add_child(node)
  var bounds:=node.mesh.get_aabb();camera.size=bounds.size[bounds.size.max_axis_index()]*1.25
  var direction:=Vector3(.20,.12,1).normalized()
  if id=="bow":direction=Vector3(1,.08,.25).normalized()
  if id=="rock1":direction=Vector3(.4,.65,1).normalized()
  camera.position=bounds.get_center()+direction*camera.size*3;camera.look_at(bounds.get_center())
  root.transparent_bg=false;env.environment.background_mode=Environment.BG_COLOR;root.size=Vector2i(640,640)
  await capture(output+"/"+id+"_native.png")
  root.transparent_bg=true;env.environment.background_mode=Environment.BG_CLEAR_COLOR;root.size=Vector2i(256,256)
  await capture("res://assets/models/meshy/"+id+"/icon.png")
  var item:String={"leaf_armor":"burdock_armor","rock1":"piedra"}.get(id,id)
  await capture("res://assets/items/prototype_3d/icons/"+item+".png")
  node.free()
 root.size=Vector2i(800,900);root.transparent_bg=false;env.environment.background_mode=Environment.BG_COLOR
 var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();world.add_child(actor);actor.wear({"id":&"burdock_armor"})
 camera.size=78
 for family:StringName in [&"axe",&"pickaxe",&"bow"]:
  actor.family_override=family;actor.aim_contact=Vector3(0,36,60)
  for state:StringName in [&"idle",&"action"]:
   actor.animate(&"draw" if family==&"bow" and state==&"action" else state,1 if family==&"bow" else .5,true)
   camera.position=Vector3(100,55,140);camera.look_at(Vector3(0,32,0))
   await capture(output+"/"+String(family)+"_"+String(state)+"_worn.png")
 actor.free();world.free();quit()
func capture(path:String):
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png(path)==OK)
