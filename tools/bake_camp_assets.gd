extends SceneTree
func _initialize() -> void: call_deferred("run")
func clean(image: Image) -> Image:
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var paint := image.get_pixel(x,y)
			if maxf(paint.r,maxf(paint.g,paint.b)) < 0.035: image.set_pixel(x,y,Color.TRANSPARENT)
	return image.get_region(image.get_used_rect().grow(2).intersection(Rect2i(Vector2i.ZERO,image.get_size())))
func run() -> void:
	var names := ["01_Refugio_comunal.png","02_Cabana_primitiva.png","03_Cabana_con_cama.png","04_Taller_primitivo.png","05_Zona_comunal.png"]
	for i in names.size():
		var image := Image.load_from_file(ProjectSettings.globalize_path("res://entregables/edificio/"+names[i]))
		var cropped := clean(image)
		if cropped.save_png("res://assets/environment/imported/camp_%02d.png" % (i+1)) != OK: quit(1); return
		print("CAMP ",i+1," ",cropped.get_size())
	var leather := Image.load_from_file(ProjectSettings.globalize_path("res://entregables/items/cuerocurtido_fases.png"))
	for i in 2:
		var part := leather.get_region(Rect2i(i*335,265,335,410))
		var cropped := clean(part)
		if cropped.save_png("res://assets/items/"+("tanned_leather.png" if i == 0 else "raw_hide.png")) != OK: quit(1); return
	var salt := clean(Image.load_from_file(ProjectSettings.globalize_path("res://entregables/items/saco_sal.png")))
	if salt.save_png("res://assets/items/salt_bag.png") != OK: quit(1); return
	print("PASS camp and material crops; source images unchanged")
	quit()
