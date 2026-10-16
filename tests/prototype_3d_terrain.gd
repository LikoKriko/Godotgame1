extends SceneTree
const Chunks=preload("res://scripts/prototype_3d/terrain_chunks.gd")
const Profile=preload("res://scripts/terrain_profile.gd")
var failures:=0
var viewport:SubViewport
var camera:Camera3D
func require(value:bool,message:String) -> void:
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func capture(terrain,point:Vector2) -> Image:
 var world_point:=Vector3(point.x*Chunks.METRES_PER_UNIT,0,point.y*Chunks.METRES_PER_UNIT)
 camera.look_at_from_position(world_point+Vector3.UP*10,world_point,Vector3.FORWARD)
 terrain.update_window(point,Vector2(256,256))
 var deadline:=Time.get_ticks_msec()+10000
 while terrain.mask_cache.busy() and Time.get_ticks_msec()<deadline:await process_frame
 require(not terrain.mask_cache.busy(),"Mask preparation completes before native continuity comparison")
 for i in 3:await process_frame;await RenderingServer.frame_post_draw
 return viewport.get_texture().get_image()
func run():
 if DisplayServer.get_name()=="headless":push_error("Requires native GPU rendering");quit(1);return
 viewport=SubViewport.new();viewport.size=Vector2i(256,256);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=256*Chunks.METRES_PER_UNIT;viewport.add_child(camera)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees.x=-90;viewport.add_child(sun)
 var small:=Profile.new();small.chunk_size=128;small.cache_limit=8
 var tiled:=Chunks.new();viewport.add_child(tiled);require(tiled.configure(73129,small),"3D terrain loads four original textures")
 for point in [Vector2(512,512),Vector2(-512,-512),Vector2(100352,-70144)]:
  var actual:Image=await capture(tiled,point);tiled.hide()
  var single:=Chunks.new();viewport.add_child(single);var large:=Profile.new();large.chunk_size=2048
  require(single.configure(73129,large),"Single-plane reference shares seed and masks")
  var expected:Image=await capture(single,point)
  var differences:=0;var empty:=0
  for y in 256:
   for x in 256:
    var a:=actual.get_pixel(x,y);var b:=expected.get_pixel(x,y)
    if a.a<0.99:empty+=1
    if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>2.1/255:differences+=1
  require(empty==0,"3D chunk borders have no holes at "+str(point))
  require(differences==0,"Chunk boundaries do not change rendered terrain: %s differences=%d"%[point,differences])
  single.free();tiled.show()
 var first:Image=await capture(tiled,Vector2.ZERO)
 await capture(tiled,Vector2(20000,-20000))
 var returned:Image=await capture(tiled,Vector2.ZERO)
 require(first.get_data()==returned.get_data(),"Reloading reproduces exactly the same terrain pixels")
 require(tiled.cached.size()<=small.cache_limit,"Hidden chunk cache remains bounded")
 var point:=Vector3(2,0,-1)
 require(tiled.terrain_at(point)==tiled.sampler.type_at(Vector2(point.x,point.z)/Chunks.METRES_PER_UNIT),"3D terrain queries share the rendered coordinate scale")
 viewport.free();print("%s: 3D terrain continuity, determinism and bounded cache"%["PASS" if failures==0 else "FAIL"]);quit(1 if failures else 0)
