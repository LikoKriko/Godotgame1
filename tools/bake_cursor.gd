extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var source: Image = preload("res://assets/ui/cursor_source.png").get_image()
	source.convert(Image.FORMAT_RGBA8)
	for y in source.get_height():
		for x in source.get_width():
			var color := source.get_pixel(x,y)
			if maxf(color.r,maxf(color.g,color.b)) < 0.10: source.set_pixel(x,y,Color.TRANSPARENT)
	var bounds := source.get_used_rect()
	var picture := source.get_region(bounds)
	var factor := 24.0/bounds.size.y
	picture.resize(maxi(1,roundi(bounds.size.x*factor)),24,Image.INTERPOLATE_NEAREST)
	picture = preload("res://scripts/visual_style.gd").clean_border(picture)
	var hotspot := ((Vector2(628,628)-Vector2(bounds.position))*factor).round()
	if picture.save_png("res://assets/ui/cursor.png") != OK: quit(1); return
	var file := FileAccess.open("res://assets/ui/cursor.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"hotspot":[hotspot.x,hotspot.y],"height":24,"source":"entregables/interfaces/cursor.png"},"\t")); file.close()
	print("PASS cursor: ",picture.get_size()," hotspot ",hotspot); quit()
