extends SceneTree
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func require(ok: bool,message: String):
 checks += 1
 if not ok: failures += 1; push_error(message)
func run():
 var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false)
 var world = game.world
 require(world.platforms.size() == 4,"Four raised platforms are generated")
 var variants := {}
 for platform in world.platforms:
  variants[platform.variant] = true
  require(platform.rect.size.x >= 51.2 and platform.rect.size.x <= 76.8 and platform.height == 9.6,"Platform sizes and physical elevation match the requested scale")
  for cell in world.props: require(not platform.rect.intersects(world.prop_collisions[cell]),"Raised terrain does not overlap solid props or plants")
  require(world.walkable(platform.rect.get_center()),"A platform is accessible by walking")
  var found := false
  for y in 12:
   for x in 12:
    var point: Vector2 = platform.rect.position+platform.rect.size*Vector2((x+0.5)/12,(y+0.5)/12)
    if world.surface_height(point) > 0:
     game.player = point; game.update_ground_support(); game.full_avatar.update_pose(0)
     require(game.ground_height == 9.6,"Walking onto the stone top raises the player")
     found = true; break
   if found: break
  require(found,"Every uploaded platform contains an accessible top surface")
  var transitions := 0; var was_above := false
  for step in 101:
   var point: Vector2 = platform.rect.position+platform.rect.size*Vector2(step/100.0,0.55)
   var above: bool = world.surface_height(point) > 0
   if above != was_above: transitions += 1
   was_above = above
  require(transitions <= 2,"Crossing the stone top does not drop through cracks between slabs")
 require(variants.size() == 3,"All three uploaded designs appear")
 var tested_small := false; var tested_large := false
 for cell in world.props:
  if world.props[cell] != 1: continue
  var point: Vector2 = world.prop_collisions[cell].get_center()
  var height: float = world.physical_height(cell)
  if height <= world.JUMP_LIMIT and not tested_small:
   require(not world.walkable(point,1) and world.walkable(point,1,height),"Small rocks block walking but can be cleared by a high enough jump")
   game.player = point-Vector2(0,17); game.previously_airborne = true; game.rock_support = world.NO_SUPPORT
   game.locomotion.reset(); game.update_ground_support()
   require(game.rock_support == cell and game.ground_height == height,"A jump can land on and remain above a small rock")
   game.update_ground_support()
   require(game.rock_support == cell and game.ground_height == height,"Remaining still preserves support on the next frame")
   var Save = preload("res://scripts/save_game.gd")
   var state: Dictionary = Save.capture(game)
   require(Save.restore(game,state) and game.rock_support == cell and game.ground_height == height,"Save/restore retains standing on a small rock")
   game.player = point+Vector2(100,100); game.update_ground_support()
   require(game.ground_height == 0 and game.rock_support == world.NO_SUPPORT,"Leaving a small rock returns to ground height")
   tested_small = true
  elif height > world.JUMP_LIMIT and not tested_large:
   require(not world.walkable(point,1,100),"A rock taller than thirty percent cannot be jumped even with excess clearance")
   tested_large = true
 require(tested_small and tested_large,"Both physical height classes are exercised")
 require(not world.walkable(game.hut.footprint.get_center(),1,100),"Jumping cannot cross a tall building")
 print("%s: %d elevation/jump checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures]); game.free(); quit(1 if failures else 0)
