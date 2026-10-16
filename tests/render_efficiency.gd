extends SceneTree
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func require(value: bool,message: String):
	checks += 1
	if not value: failures += 1; push_error(message)
func frames(count: int):
	for i in count:
		await process_frame
		await RenderingServer.frame_post_draw
func run():
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game); game.set_process(false)
	await frames(4)
	var mask = game.solar_lighting.shadows.mask
	var before: int = mask.redraws
	var pixels: Image = mask.get_viewport().get_texture().get_image()
	await frames(20)
	require(mask.redraws == before,"An unchanged idle sprite does not redraw its offscreen color/shadow mask")
	require(pixels.get_data() == mask.get_viewport().get_texture().get_image().get_data(),"Reusing the mask preserves every pixel")
	var hud = game.styled_hud
	var built: int = hud.terrain_rebuilds
	for i in 20: hud.refresh()
	require(hud.terrain_rebuilds == built,"HUD updates reuse the minimap terrain raster")
	var map: Image = hud.map_terrain.get_image()
	for cell in game.world.cells:
		var tile: Dictionary = game.world.cells[cell]
		var expected := Color("737968") if tile.blocked else Color("414a39")
		if tile.road and not tile.blocked: expected = Color("6a6351")
		require(map.get_pixelv(cell-game.world.FIRST).is_equal_approx(expected),"Minimap cache retains the terrain color of each cell")
	var cell: Vector2i = game.world.props.keys()[0]
	game.world.release_prop(cell); hud.refresh()
	require(hud.terrain_rebuilds == built+1,"Changed resources rebuild the minimap before reuse")
	game.player += Vector2(0.03,0.01)
	game.full_avatar.update_pose(0.1)
	await frames(2)
	require(mask.redraws > before,"A changed animation frame still updates the visible mask")
	var moved: Image = mask.get_viewport().get_texture().get_image()
	require(moved.get_data() != pixels.get_data(),"Walking changes the rendered silhouette")
	require(game.full_avatar.cache_bytes <= game.full_avatar.CACHE_BYTES,"Decoded sprite cache remains within its budget")
	print("%s: %d render reuse checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	game.free(); quit(1 if failures else 0)
