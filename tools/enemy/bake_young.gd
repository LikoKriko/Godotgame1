extends SceneTree
const CELL := Vector2i(96,96)
const OUTPUT := "res://assets/enemies/first/"
var viewport: SubViewport
var camera: Camera3D
var actor: Node3D
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(256,256)
	viewport = SubViewport.new(); viewport.size = CELL
	viewport.transparent_bg = true; viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 64
	camera.position = Vector3(0,61,200); viewport.add_child(camera); camera.look_at(Vector3(0,17,0))
	actor = preload("res://tools/enemy/young_volume.gd").new(); viewport.add_child(actor)
	var manifest := {"authoring":"continuous_actor_surfaces_two_bone_ik", "version":2,"canvas":[CELL.x,CELL.y],"foot":[camera.unproject_position(Vector3.ZERO).x,camera.unproject_position(Vector3.ZERO).y],"pixels_per_world":1.5,"world_height":32,"source":"Day_Zero_Enemigo_Joven_4_Vistas.png"}
	for name in ["idle","walk","attack_left","attack_right"]:
		var count := 1 if name == "idle" else (12 if name == "walk" else 16)
		var sheet := Image.create(CELL.x*count,CELL.y*16,false,Image.FORMAT_RGBA8)
		for direction in 16:
			for frame in count:
				var phase := frame/float(count) if name == "walk" else (frame/float(count-1) if count > 1 else 0.0)
				# Runtime contact at 0.5 s matches the peak at frame eight.
				if name.begins_with("attack"): phase = frame/16.0 if frame <= 8 else 0.5+(frame-8)/14.0
				actor.pose("attack" if name.begins_with("attack") else name,phase,direction,name != "attack_right")
				await process_frame; await RenderingServer.frame_post_draw
				var picture := preload("res://scripts/visual_style.gd").outlined(viewport.get_texture().get_image())
				sheet.blit_rect(picture,Rect2i(Vector2i.ZERO,CELL),Vector2i(frame*CELL.x,direction*CELL.y))
		var path: String = OUTPUT+name+".png"
		if sheet.save_png(path) != OK: push_error("Enemy export failed: "+path); quit(1); return
		manifest[name] = {"path":path,"frames":count,"directions":16}
		print("BAKED young ",name,": 16 directions × ",count," frames")
	var file := FileAccess.open(OUTPUT+"manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t")); file.close()
	print("PASS young enemy complete sprite export"); quit()
