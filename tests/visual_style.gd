extends SceneTree
const Style = preload("res://scripts/visual_style.gd")
var failures := 0
func _initialize() -> void:
	var source := Image.create(20,20,false,Image.FORMAT_RGBA8)
	source.fill_rect(Rect2i(3,3,14,14),Color.BLACK)
	var pigment := Color8(155,145,100)
	source.fill_rect(Rect2i(6,6,8,8),pigment)
	var cleaned := Style.outlined(Style.clean_border(source))
	for x in range(3,17):
		if cleaned.get_pixel(x,4) != pigment:
			failures += 1
	var quantized := Image.create(1,1,false,Image.FORMAT_RGBA8)
	quantized.set_pixel(0,0,Style.OUTLINE_COLOR)
	if cleaned.get_pixel(9,2) != quantized.get_pixel(0,0) or cleaned.get_pixel(9,1).a != 0:
		failures += 1
	if cleaned.get_pixel(9,9) != pigment: failures += 1
	var texture := ImageTexture.create_from_image(source)
	var world_size := Vector2.ONE*20/Style.PIXELS_PER_WORLD
	var small := Style.normalized(texture,world_size)
	var large := Style.normalized(texture,world_size*2)
	if small.get_size() != Vector2(20,20) or large.get_size() != Vector2(40,40): failures += 1
	if Style.normalized(texture,world_size) != small: failures += 1
	print("%s: shared contour policy, thick-border removal, preserved center pigment, one-pixel outline and scaled cache" % ("PASS" if failures == 0 else "FAIL"))
	quit(1 if failures else 0)
