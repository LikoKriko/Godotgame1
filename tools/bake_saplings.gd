extends SceneTree
## Keep the uploaded five-tree sheet intact; extract transparent, separate variants.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var source := Image.load_from_file("res://entregables/entorno/plantas/arbolitos1.png")
	if source == null: quit(1); return
	var regions := [Rect2i(100,0,400,580),Rect2i(680,0,450,580),Rect2i(1350,0,300,580),Rect2i(280,590,620,570),Rect2i(1000,590,400,570)]
	for index in regions.size():
		var picture := source.get_region(regions[index])
		picture.convert(Image.FORMAT_RGBA8)
		for y in picture.get_height():
			for x in picture.get_width():
				var paint := picture.get_pixel(x,y)
				if maxf(paint.r,maxf(paint.g,paint.b)) < 0.035: picture.set_pixel(x,y,Color.TRANSPARENT)
		picture = picture.get_region(picture.get_used_rect())
		if picture.save_png("res://assets/environment/imported/sapling_%02d.png" % (index+1)) != OK: quit(1); return
	print("PASS five isolated sapling designs"); quit()
