extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false)
 var queries := []
 var random := RandomNumberGenerator.new(); random.seed = 77391
 for i in 1000: queries.append(Vector2(random.randf_range(-480,480),random.randf_range(-260,260)))
 for i in 12: game.world_view.update_trees(Vector2.ZERO,1.0/60)
 var output := {"objects":game.world_view.hit_meshes.targets.size(),"trees":game.world_view.tree_sprites.size(),"timings_usec":{}}
 for name in ["hud","cursor","trees"]:
  var rounds := []
  for repeat in 7:
   var start := Time.get_ticks_usec()
   if name == "hud":
    for i in 300: game.styled_hud.refresh()
   elif name == "cursor":
    for point in queries: game.world_view.hit_meshes.target_at(point)
   else:
    for i in 300: game.world_view.update_trees(Vector2.ZERO,1.0/60)
   rounds.append(Time.get_ticks_usec()-start)
  rounds.sort(); output.timings_usec[name] = rounds[3]
 print(JSON.stringify(output)); game.free(); quit()
