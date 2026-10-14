extends SceneTree
const Chunks = preload("res://scripts/terrain_chunks.gd")
const Profile = preload("res://scripts/terrain_profile.gd")
const Sampler = preload("res://scripts/terrain_sampler.gd")
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func require(ok: bool,message: String):
 checks += 1
 if not ok: failures += 1; push_error(message)
func run():
 var profile := Profile.new(); var a := Sampler.new(); var b := Sampler.new()
 a.configure(73129,profile); b.configure(73129,profile)
 var distribution := [0,0,0,0]
 for y in 80:
  for x in 80:
   var point := Vector2((x-40)*619,(y-40)*587)
   var weights := a.weights_at(point)
   require(weights.is_equal_approx(b.weights_at(point)),"Identical seeds produce identical global terrain")
   require(absf(weights.x+weights.y+weights.z+weights.w-1) < 0.00001,"Terrain weights stay normalized")
   distribution[Sampler.TYPES.find(a.type_at(point))] += 1
 require(distribution[0]/6400.0 >= 0.65 and distribution[0]/6400.0 <= 0.70,"Normal terrain occupies the configured 65–70 percent on a broad independent sample")
 for boundary in [-1024,-512,0,512,1024,100352]:
  for y in [-731,-13,0,917]:
   require(a.weights_at(Vector2(boundary-0.001,y)).distance_to(a.weights_at(Vector2(boundary+0.001,y))) < 0.001,"Weights are continuous across positive, negative and far chunk borders")
 var only := Profile.new(); only.proportions = Vector4(1,0,0,0)
 var special := Sampler.new(); special.configure(73129,only)
 require(special.weights_at(Vector2.ZERO) == Vector4(1,0,0,0),"Configured zero shares cannot introduce unwanted variants")
 only.proportions = Vector4(0,0,0,1); special.configure(73129,only)
 require(special.weights_at(Vector2.ZERO) == Vector4(0,0,0,1),"A single selected terrain can occupy the entire natural base")
 var chunks := Chunks.new(); root.add_child(chunks); profile.chunk_size = 128; profile.cache_limit = 8
 require(chunks.configure(73129,profile),"All four terrain references load")
 chunks.update_window(Vector2.ZERO,Vector2(256,256),true)
 var original = chunks.active[Vector2i.ZERO]
 var generated: int = chunks.generations
 chunks.update_window(Vector2.ZERO,Vector2(256,256))
 require(chunks.generations-generated <= profile.chunks_per_frame,"Prefetch work respects the frame budget")
 chunks.update_window(Vector2(3000,-2000),Vector2(256,256))
 require(chunks.cached.size() <= profile.cache_limit and not chunks.active.has(Vector2i.ZERO),"Distant chunks unload and cache stays bounded")
 for i in 20: chunks.advance_generation()
 chunks.update_window(Vector2.ZERO,Vector2(256,256))
 require(chunks.active.has(Vector2i.ZERO) and chunks.sampler.weights_at(Vector2(10,20)).is_equal_approx(a.weights_at(Vector2(10,20))),"Returning reconstructs the exact original terrain")
 profile.cache_limit = 96
 var reused: int = chunks.reuses
 chunks.update_window(Vector2(700,0),Vector2(256,256)); chunks.update_window(Vector2.ZERO,Vector2(256,256))
 require(chunks.reuses > reused,"Nearby cached chunks reuse graphics rather than regenerate")
 a.add_influence(&"tree",&"dirt",Rect2(-20,-20,40,40))
 require(a.type_at(Vector2.ZERO) == &"dirt","Placement hooks can request bare soil around objects")
 chunks.free()
 print("%s: %d terrain/chunk checks; proportions=%s; %d failures" % ["PASS" if failures == 0 else "FAIL",checks,distribution,failures]); quit(1 if failures else 0)
