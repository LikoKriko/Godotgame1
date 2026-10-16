extends SceneTree
const Cache=preload("res://scripts/prototype_3d/terrain_mask_cache.gd")
const Sampler=preload("res://scripts/terrain_sampler.gd")
const Profile=preload("res://scripts/terrain_profile.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func wait_ready(cache):
 var deadline:=Time.get_ticks_msec()+5000
 while cache.busy() and Time.get_ticks_msec()<deadline:cache.collect();await process_frame
 require(not cache.busy(),"Mask preparation completes asynchronously")
func run():
 var profile:=Profile.new();var sampler:=Sampler.new();sampler.configure(73129,profile);sampler.existing_paths=true
 sampler.add_influence(&"test",&"vegetation",Rect2(-140,-120,320,260),.8)
 var cache:=Cache.new()
 cache.request(Vector2i.ZERO,Rect2(-32,-32,64,64),sampler,profile)
 await wait_ready(cache)
 require(cache.data.has(Vector2i.ZERO),"A prepared mask publishes a reusable rendering texture")
 require(cache.data[Vector2i.ZERO].texture.get_size()==Vector2(11,11),"Mask size has a global grid and a complete interpolation border")
 var texture=cache.data[Vector2i.ZERO].texture
 cache.request(Vector2i.ZERO,Rect2(-32,-32,64,64),sampler,profile)
 require(cache.data[Vector2i.ZERO].texture==texture and not cache.busy(),"An unchanged chunk reuses its existing mask")
 cache.request(Vector2i.ONE,Rect2(32,32,64,64),sampler,profile);cache.forget(Vector2i.ONE)
 for i in 4:cache.collect();await process_frame
 require(not cache.data.has(Vector2i.ONE),"Unloaded chunks cannot be republished by stale worker results")
 cache.invalidate();require(cache.data.is_empty(),"Influence changes invalidate cached masks")
 cache.request(Vector2i.ZERO,Rect2(-32,-32,64,64),sampler,profile)
 await wait_ready(cache)
 require(cache.data[Vector2i.ZERO].texture!=texture,"Invalidation rebuilds the mask rather than retaining old paths")
 cache.finish();require(cache.data.is_empty() and cache.pending.is_empty(),"Scene exit joins the worker and releases its resources")
 var terrain=load("res://scripts/prototype_3d/terrain_chunks.gd").new();root.add_child(terrain);terrain.configure(73129)
 terrain.update_window(Vector2.ZERO,Vector2(256,256))
 var deadline:=Time.get_ticks_msec()+5000
 while terrain.mask_cache.busy() and Time.get_ticks_msec()<deadline:await process_frame
 require(terrain.active.values()[0].material_override.shader==load("res://shaders/prototype_3d/chunk_ground_cached.gdshader"),"The renderer installs completed masks on active chunks")
 terrain.refresh_influences();require(terrain.mask_cache.data.is_empty(),"Terrain influence refresh requests fresh masks")
 terrain.free()
 print("%s: %d mask generation, reuse, invalidation and streaming lifetime checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
