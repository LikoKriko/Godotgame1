extends SceneTree
const Imported = preload("res://scripts/imported_nature.gd")
const Style = preload("res://scripts/visual_style.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var arrangements := [[7,8,0],[2,9,7],[6,11,8],[4,0,9],[10,7,3]]
	for i in 5:
		var canvas := Image.create(160,100,false,Image.FORMAT_RGBA8)
		for part in 3:
			var source: Image = Imported.texture(Imported.GRASS[arrangements[i][part]]).get_image()
			source.convert(Image.FORMAT_RGBA8)
			var width := 64 if part == 1 else 52
			source.resize(width,maxi(12,roundi(width*float(source.get_height())/source.get_width())),Image.INTERPOLATE_NEAREST)
			if (i+part)%2 == 0: source.flip_x()
			for y in source.get_height():
				for x in source.get_width():
					var paint := source.get_pixel(x,y)
					if paint.v < 0.035: paint.a = 0
					else: paint = Color(paint.r*(0.97+i*0.01),paint.g,paint.b*1.02,paint.a)
					source.set_pixel(x,y,paint)
			var origin := Vector2i(6+part*46,82-source.get_height()+((i+part)%3)*4)
			canvas.blend_rect(source,Rect2i(Vector2i.ZERO,source.get_size()),origin)
		var cropped := canvas.get_region(canvas.get_used_rect().grow(1).intersection(Rect2i(0,0,160,100)))
		var path := "res://assets/environment/imported/cesped_%02d.png" % (13+i)
		if cropped.save_png(path) != OK: quit(1); return
		print("GRASS ",13+i," ",cropped.get_size())
	print("PASS five composed grass variants")
	quit()
