extends SceneTree
const Shadows = preload("res://scripts/sun_shadows.gd")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func require(value: bool,message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func run() -> void:
	var fixture := Image.create(40,60,false,Image.FORMAT_RGBA8)
	fixture.fill_rect(Rect2i(16,12,8,30),Color("8b5931"))
	fixture.fill_rect(Rect2i(4,44,32,12),Color("426b36"))
	require(Shadows.contact_row(fixture,2) == 42,"Tree base excludes ground grass and lower bitmap margin")
	fixture.fill_rect(Rect2i(10,8,20,34),Color("77786e"))
	require(Shadows.contact_row(fixture,1) == 42,"Rock base uses stone rather than grass decoration")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game); game.set_process(false)
	var shadows = game.solar_lighting.shadows
	var cropped := 0
	var kinds := {}
	for cell in game.world.props:
		var kind: int = game.world.props[cell]
		if kind not in [1,2,4]: continue
		kinds[kind] = true
		var data: Dictionary = shadows.prop_geometry(cell)
		var original: Dictionary = game.world_view.presentation(cell)
		var info: Dictionary = shadows.shadow_info(original.texture,kind)
		require(info.fraction > 0.5 and info.fraction <= 1,"Object silhouette keeps the visible body")
		if info.fraction < 0.99: cropped += 1
		var expected: Vector2 = Vector2(data.rect.get_center().x,data.rect.end.y)
		expected = data.transform*expected
		require(expected.is_equal_approx(data.base),"Shadow starts at the displayed trunk/stone rather than the collider end")
		for direction in [Vector2(1,0.1).normalized(),Vector2(-0.6,0.8).normalized()]:
			for stretch in [0.5,2.4]:
				shadows.direction = direction; shadows.stretch = stretch
				require((shadows.projection(data.base)*expected).is_equal_approx(expected),"Shadow contact remains joined throughout the sun cycle")
		require(shadows.shadow_info(original.texture,kind).texture == info.texture,"Repeated shadows reuse cached raster")
		if game.world_view.tree_sprites.has(cell):
			var sprite: Sprite2D = game.world_view.tree_sprites[cell]
			var transform := sprite.transform
			sprite.rotation = 0.035; sprite.position += Vector2(3,-1)
			var moved: Dictionary = shadows.prop_geometry(cell)
			var foot := sprite.global_transform*Vector2(moved.texture.get_width()/2.0,moved.texture.get_height())
			require(moved.base.is_equal_approx(foot),"Impact shake and rotation retain the visual shadow contact")
			sprite.transform = transform
	require(kinds.size() == 3 and cropped > 0,"Padded saplings and tightly cropped new rock silhouettes both retain their visual shadow anchors")
	print("%s: %d prop shadow anchor checks, %d failures; %d cropped ground margins" % ["PASS" if failures == 0 else "FAIL",checks,failures,cropped])
	quit(1 if failures else 0)
