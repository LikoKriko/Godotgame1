extends SceneTree
const Imported = preload("res://scripts/imported_nature.gd")
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func require(ok: bool,message: String):
 checks += 1
 if not ok: failures += 1; push_error(message)
func run():
 var world = preload("res://scripts/test_world.gd").new(); world.generate(73129)
 require(Imported.GRASS.size() == 17,"Twelve originals and five new compositions are available")
 var used := {}
 for tuft in world.grass_tufts: used[tuft.variant] = true
 for i in range(12,17):
  require(used.has(i),"Procedural generation mixes the new variant "+str(i))
  var image := Imported.texture(Imported.GRASS[i]).get_image()
  require(image.get_used_rect().has_area(),"New grass has a visible alpha silhouette")
 var platforms = preload("res://scripts/raised_ground.gd")
 for data in world.platforms:
  var high := platforms.detailed_texture(data.variant,data.rect.size)
  require(high.get_width() == roundi(data.rect.size.x*1.53125*2),"Platform raster has twice the sampling density")
  require(high == platforms.detailed_texture(data.variant,data.rect.size),"Platform texture is reused")
 var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false)
 game.player = game.hut.base-Vector2(0,80); game.hut._process(0)
 require(is_equal_approx(game.hut.exterior.modulate.a,0.35),"Hut becomes translucent when covering the player")
 game.player = game.hut.base+Vector2(0,90); game.hut._process(0)
 require(game.hut.exterior.modulate.a == 1,"Hut opacity returns outside the obstructed view")
 require(game.hut.footprint.size.x < 224 and game.hut.footprint.size.y < 98,"Hut collision is smaller than the old oversized footprint")
 print("%s: %d environment polish checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures]); game.free(); quit(1 if failures else 0)
