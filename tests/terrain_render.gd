extends SceneTree
const Chunks = preload("res://scripts/terrain_chunks.gd")
const Profile = preload("res://scripts/terrain_profile.gd")
var checks := 0
var failures := 0
var viewport: SubViewport
var camera: Camera2D
func _initialize(): call_deferred("run")
func require(ok: bool,message: String):
 checks += 1
 if not ok: failures += 1; push_error(message)
func capture(renderer,center: Vector2) -> Image:
 camera.position = center; renderer.update_window(center,Vector2(viewport.size),true)
 for i in 3: await process_frame
 await RenderingServer.frame_post_draw
 return viewport.get_texture().get_image()
func run():
 if DisplayServer.get_name() == "headless": push_error("Requires native rendering"); quit(1); return
 viewport = SubViewport.new(); viewport.size = Vector2i(256,256); viewport.world_2d = World2D.new(); viewport.transparent_bg = true
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
 camera = Camera2D.new(); viewport.add_child(camera)
 var profile := Profile.new(); profile.chunk_size = 128
 var tiled := Chunks.new(); viewport.add_child(tiled); require(tiled.configure(73129,profile),"Four actual source textures load on the GPU")
 for center in [Vector2(512,512),Vector2(-512,-512),Vector2(100352,-70144)]:
  var actual: Image = await capture(tiled,center)
  tiled.hide()
  var full := Chunks.new(); viewport.add_child(full); var single := Profile.new(); single.chunk_size = 2048
  require(full.configure(73129,single),"Reference renderer uses the same seed and textures")
  var expected: Image = await capture(full,center)
  var differences := 0; var empty := 0
  for y in actual.get_height():
   for x in actual.get_width():
    var a := actual.get_pixel(x,y); var b := expected.get_pixel(x,y)
    if a.a < 0.99: empty += 1
    if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))) > 1.1/255: differences += 1
  require(empty == 0,"No gaps or transparent pixels at chunk joins: "+str(center))
  require(differences == 0,"Chunk partitioning introduces no visual difference across seams: "+str(center)+" differences="+str(differences))
  full.free(); tiled.show()
 var original: Image = await capture(tiled,Vector2.ZERO)
 await capture(tiled,Vector2(10000,20000))
 var returned: Image = await capture(tiled,Vector2.ZERO)
 require(original.get_data() == returned.get_data(),"Unloading and returning reproduces every rendered pixel")
 # With solid diagnostic source colors, compare CPU terrain queries to GPU mixing.
 for i in 4:
  var image := Image.create(2,2,false,Image.FORMAT_RGB8)
  image.fill([Color.RED,Color.GREEN,Color.BLUE,Color.BLACK][i]); tiled.textures[i] = ImageTexture.create_from_image(image)
  tiled.shared_material.set_shader_parameter(["normal_ground","dark_ground","vegetation_ground","dirt_ground"][i],tiled.textures[i])
 tiled.refresh_influences()
 var diagnostic: Image = await capture(tiled,Vector2(512,512))
 for y in range(0,256,16):
  for x in range(0,256,16):
   var weights: Vector4 = tiled.sampler.weights_at(Vector2(384+x,384+y))
   var pixel := diagnostic.get_pixel(x,y)
   require(maxf(absf(pixel.r-weights.x),maxf(absf(pixel.g-weights.y),absf(pixel.b-weights.z))) < 0.012,"Terrain type queries match the GPU masks")
 print("%s: %d rendered terrain checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures]); quit(1 if failures else 0)
