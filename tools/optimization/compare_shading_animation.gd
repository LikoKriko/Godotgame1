extends SceneTree
## Reproducible native before/after captures and alternating render measurements.
const Motion=preload("res://scripts/prototype_3d/young_pose.gd")
var folder:String
var stats:Dictionary={}
var quality=preload("res://scripts/prototype_3d/quality_materials.gd").new()
func _initialize():call_deferred("run")
func frame():
 await process_frame
 await RenderingServer.frame_post_draw
func capture(name:String):
 for i in 3:await frame()
 root.get_texture().get_image().save_png(folder+"/"+name+".png")
func apply_mode(terrain,cached:bool) -> void:
 terrain.use_mask_cache=cached
 for key in terrain.active:terrain.active[key].material_override=terrain.material_for(terrain.chunk_rect(key))
func run():
 if DisplayServer.get_name()=="headless":push_error("Requires native rendering");quit(1);return
 var args:=OS.get_cmdline_user_args();folder=args[0] if not args.is_empty() else "res://work/shading-animation-comparison"
 for mode in ["before","after"]:DirAccess.make_dir_recursive_absolute(folder+"/"+mode)
 root.size=Vector2i(640,640);Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var world:=Node3D.new();root.add_child(world)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("444c51");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.7;world.add_child(env)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-25,0);world.add_child(light)
 var camera:=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 var terrain=load("res://scripts/prototype_3d/terrain_chunks.gd").new();terrain.use_mask_cache=false;world.add_child(terrain)
 var profile=load("res://scripts/terrain_profile.gd").new();profile.chunk_size=1024;profile.preload_chunks=0;profile.retain_chunks=0;profile.cache_limit=1
 terrain.configure(73129,profile);terrain.sampler.existing_paths=true;terrain.sampler.add_influence(&"review",&"vegetation",Rect2(-140,-120,320,260),.8)
 var index:=0
 for point:Vector2 in [Vector2(400,360),Vector2(-400,-300),Vector2(100352,-70144)]:
  var position:=Vector3(point.x*terrain.METRES_PER_UNIT,0,point.y*terrain.METRES_PER_UNIT)
  camera.size=768*terrain.METRES_PER_UNIT;camera.look_at_from_position(position+Vector3.UP*30,position,Vector3.FORWARD)
  terrain.update_window(point,Vector2(768,768));terrain.refresh_influences()
  for cached in [false,true]:
   apply_mode(terrain,cached)
   var deadline:=Time.get_ticks_msec()+30000
   while terrain.mask_cache.busy() and Time.get_ticks_msec()<deadline:await frame()
   for i in 10:await frame()
   await capture(("after" if cached else "before")+"/terrain_%d"%index)
   for percent in [65,35]:
    for key in terrain.active:
     var node=terrain.active[key]
     node.material_override=quality.material(terrain.material_for(terrain.chunk_rect(key)),percent)
    await capture(("after" if cached else "before")+"/terrain_%d_q%d"%[index,percent])
   apply_mode(terrain,cached)
  var samples:Dictionary={false:[],true:[]}
  for repeat in 5:
   for cached in ([false,true] if repeat%2==0 else [true,false]):
    apply_mode(terrain,cached)
    for i in 4:await frame()
    var ticks:=Time.get_ticks_usec()
    for i in 30:await frame()
    samples[cached].append((Time.get_ticks_usec()-ticks)/30000.0)
  samples[false].sort();samples[true].sort()
  stats["terrain_%d"%index]={"before_ms":samples[false][2],"after_ms":samples[true][2],"reduction_percent":100*(1-samples[true][2]/samples[false][2])}
  index+=1
 terrain.free()
 camera.size=51;camera.position=Vector3(68,35,100);camera.look_at(Vector3(0,15,0))
 for cached in [false,true]:
  Motion.use_keyframes=cached
  var actor=load("res://scripts/prototype_3d/young_model.gd").new();world.add_child(actor);actor.use_bind_frame_cache=cached
  var mode:="after" if cached else "before"
  for state:StringName in [&"idle",&"walk",&"run",&"sit",&"sleep",&"boxing_walk"]:
   index=0
   for phase:float in [.073,.237,.519,.837]:
    actor.animate(state,phase,true)
    await capture(mode+"/enemy_%s_%d"%[state,index]);index+=1
  for i in 24:
   actor.animate(&"walk",fposmod(i*.0371,1),true,1.0/60)
   if i in [0,7,15,23]:await capture(mode+"/transition_%d"%i)
  actor.free()
 Motion.use_keyframes=true
 world.free()
 var file:=FileAccess.open(folder+"/timing.json",FileAccess.WRITE);file.store_string(JSON.stringify(stats,"  "));file.close()
 print("PASS: paired terrain and animation captures, alternating five-run render timings; ",stats);quit()
