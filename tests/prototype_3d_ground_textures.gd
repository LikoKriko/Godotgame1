extends SceneTree
## Render the actual shader logic with diagnostic colours to separate roads/biomes.
const Chunks=preload("res://scripts/prototype_3d/terrain_chunks.gd")
const Profile=preload("res://scripts/terrain_profile.gd")
var checks:=0
var failures:=0
var viewport:SubViewport
var camera:Camera3D
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func colour_texture(colour:Color) -> ImageTexture:
 var image:=Image.create(4,4,false,Image.FORMAT_RGB8);image.fill(colour);return ImageTexture.create_from_image(image)
func run() -> void:
 if DisplayServer.get_name()=="headless":push_error("Requires native rendering");quit(1);return
 var names:=["terreno1_claro_1.png","terreno1_oscuro_1.png","terreno1_claro_2.png","terreno1_claro_1_Path.png"]
 var profile:=Profile.new()
 for i in names.size():
  require(profile.texture_paths[i].get_file()==names[i],"Profile maps the correct supplied texture")
  require(FileAccess.get_sha256(profile.texture_paths[i])==FileAccess.get_sha256("res://entregables/entorno/terreno/"+names[i]),"Original PNG bytes are unchanged")
 viewport=SubViewport.new();viewport.size=Vector2i(96,96);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.75;viewport.add_child(camera)
 var colours:=[Color.RED,Color.BLUE,Color.GREEN,Color.MAGENTA]
 var cases:=[
  [Vector4(1,0,0,0),Vector2(600,600),false,false,Color.RED],
  [Vector4(0,1,0,0),Vector2(600,600),false,false,Color.BLUE],
  [Vector4(0,0,1,0),Vector2(600,600),false,false,Color.GREEN],
  [Vector4(0,0,0,1),Vector2(600,600),false,false,Color.RED],
  [Vector4(0,0,0,1),Vector2(600,600),true,false,Color.RED],
  [Vector4(0,1,0,0),Vector2.ZERO,true,false,Color.MAGENTA],
  [Vector4(0,0,1,0),Vector2.ZERO,false,true,Color.MAGENTA]]
 for cached in [false,true]:
  for test in cases:
   var config:=Profile.new();config.chunk_size=128;config.proportions=test[0]
   var terrain:=Chunks.new();terrain.use_mask_cache=cached;viewport.add_child(terrain);require(terrain.configure(73129,config),"Terrain configures")
   terrain.sampler.existing_paths=test[2];terrain.relief_enabled=test[3]
   for i in 4:terrain.shared_material.set_shader_parameter(["normal_ground","dark_ground","vegetation_ground","dirt_ground"][i],colour_texture(colours[i]))
   var point:Vector2=test[1];terrain.update_window(point,Vector2(128,128))
   var deadline:=Time.get_ticks_msec()+10000
   while terrain.mask_cache.busy() and Time.get_ticks_msec()<deadline:await process_frame
   require(not terrain.mask_cache.busy(),"Cached materials are ready")
   # Lighting is disabled only for the probe, keeping the production shader's
   # includes, texture binding, path masks and blending exactly as loaded.
   for node in terrain.active.values():
    var material:ShaderMaterial=node.material_override;var shader:=Shader.new();shader.code=material.shader.code.replace("render_mode cull_back;","render_mode unshaded, cull_back;");material.shader=shader
   var position:=Vector3(point.x*Chunks.METRES_PER_UNIT,0,point.y*Chunks.METRES_PER_UNIT)
   camera.look_at_from_position(position+Vector3.UP*10,position,Vector3.FORWARD)
   for frame in 3:await process_frame;await RenderingServer.frame_post_draw
   var actual:=viewport.get_texture().get_image().get_pixel(48,48)
   require(Vector3(actual.r,actual.g,actual.b).distance_to(Vector3(test[4].r,test[4].g,test[4].b))<.04,"Road PNG is exclusive to roads; general regions use their assigned PNG in both shaders")
   terrain.free();await process_frame
 print("%s: %d original texture, biome and road rendering checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
