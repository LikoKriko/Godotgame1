extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func require(condition: bool,message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
func capture() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func luminance(image: Image, rect: Rect2i) -> float:
	var total := 0.0
	var count := 0
	for y in range(rect.position.y,rect.end.y,7):
		for x in range(rect.position.x,rect.end.x,7):
			var color := image.get_pixel(x,y)
			total += color.r*0.2126+color.g*0.7152+color.b*0.0722
			count += 1
	return total/count
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.day_cycle.hour = 12
	game.solar_lighting.update_light()
	var noon: Image = await capture()
	game.solar_lighting.shadows.hide()
	var without: Image = await capture()
	var changed := 0
	for y in range(260,850,3):
		for x in range(300,1550,3):
			if noon.get_pixel(x,y).r < without.get_pixel(x,y).r-0.005:
				changed += 1
	require(changed > 50,"Alpha silhouettes cast visible ground shadows")
	game.day_cycle.hour = 23
	game.solar_lighting.update_light()
	var night: Image = await capture()
	var ground := Rect2i(850,240,420,520)
	require(luminance(night,ground) < luminance(noon,ground)*0.45,"Terrain, grass and props become consistently dark at night")
	require(not game.solar_lighting.sun.visible and not game.solar_lighting.shadows.visible,"Night disables the solar light and solar shadows")
	var base := Vector2(177,-210)
	game.day_cycle.hour = 7
	game.solar_lighting.update_light()
	var dawn: Transform2D = game.solar_lighting.shadows.projection(base)
	game.day_cycle.hour = 19
	game.solar_lighting.update_light()
	var dusk: Transform2D = game.solar_lighting.shadows.projection(base)
	require((dawn*base).is_equal_approx(base) and (dusk*base).is_equal_approx(base),"Moving shadows remain anchored to feet and trunks")
	require((dawn*(base+Vector2(0,-64))).x < base.x and (dusk*(base+Vector2(0,-64))).x > base.x,"Projected silhouette changes direction with solar travel")
	print("%s: %d solar rendering checks, %d failures: silhouette shadows, dark terrain, night, anchors and sun movement" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(0 if failures == 0 else 1)
