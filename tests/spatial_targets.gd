extends SceneTree
var checks := 0
func _initialize() -> void: call_deferred("run")
func brute(meshes, point: Vector2) -> Vector2i:
	var result := Vector2i(99999,99999)
	var depth := -INF
	for cell in meshes.targets:
		if meshes.targets[cell].depth > depth and meshes.contains(cell,point):
			result = cell; depth = meshes.targets[cell].depth
	return result
func run() -> void:
	var host := Node2D.new(); root.add_child(host)
	var meshes = preload("res://scripts/hit_meshes.gd").new(); meshes.configure(host)
	var image := Image.create(24,24,false,Image.FORMAT_RGBA8)
	for y in 24:
		for x in 24:
			image.set_pixel(x,y,Color.WHITE if Vector2(x-12,y-12).length() < 10 and x%5 != 0 else Color.TRANSPARENT)
	var texture := ImageTexture.create_from_image(image)
	seed(31415)
	for i in 80:
		var point := Vector2(randf_range(-300,300),randf_range(-300,300))
		meshes.add(Vector2i(i,0),texture,Rect2(point,Vector2(60,60)),i%4)
	for stage in 4:
		if stage == 1:
			for i in 80: meshes.set_transform(Vector2i(i,0),Vector2(randf_range(-300,300),randf_range(-300,300)),randf_range(-PI,PI),Vector2(-2.5,1.8))
		if stage == 2: host.transform = Transform2D(0.3,Vector2(1.2,0.8),0,Vector2(127,-129))
		if stage == 3:
			for i in 40: meshes.remove(Vector2i(i,0))
		for query in 3000:
			var point := Vector2(randf_range(-450,450),randf_range(-450,450))
			if meshes.target_at(point) != brute(meshes,point): push_error("Spatial result differs from silhouette scan"); quit(1); return
			checks += 1
	# Ties must preserve insertion order, including after a bucket relocation.
	meshes.clear(); host.transform = Transform2D.IDENTITY
	for i in 2: meshes.add(Vector2i(i,0),texture,Rect2(Vector2.ZERO,Vector2(48,48)),10)
	meshes.set_transform(Vector2i.ZERO,Vector2(128,0),0,Vector2(2,2))
	meshes.set_transform(Vector2i.ZERO,Vector2.ZERO,0,Vector2(2,2))
	assert(meshes.target_at(Vector2(22,22)) == Vector2i.ZERO)
	meshes.clear(); host.free()
	print("PASS spatial targets: ",checks," comparisons, host transforms, rotation, negative scale, removal and depth ties"); quit()
