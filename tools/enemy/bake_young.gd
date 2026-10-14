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
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT+"manifest.json")) if FileAccess.file_exists(OUTPUT+"manifest.json") else {}
	manifest.merge({"authoring":"continuous_actor_surfaces_two_bone_ik", "locomotion":"four_leg_walk_run_seated_rest_tree_feeding_standing_punch", "version":4,"canvas":[CELL.x,CELL.y],"foot":[camera.unproject_position(Vector3.ZERO).x,camera.unproject_position(Vector3.ZERO).y],"pixels_per_world":1.5,"world_height":32,"source":"Day_Zero_Enemigo_Joven_4_Vistas.png"},true)
	var states := ["idle","walk","run","sit","sit_down","sit_up","feed","attack_left","attack_right","enter_left","enter_right","lower","stun_fall","stun_fall_left","stun_fall_right","stun_hold","stun_rise"]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--states="): states = Array(argument.trim_prefix("--states=").split(","))
	for name in states:
		var count := 1 if name in ["idle","stun_hold"] else (4 if name == "sit" else (8 if name == "feed" else (12 if name in ["walk","run"] else (6 if name in ["lower","sit_down","sit_up"] or name.begins_with("stun_") else 16))))
		var tops := []
		var sheet := Image.create(CELL.x*count,CELL.y*16,false,Image.FORMAT_RGBA8)
		for direction in 16:
			var row := []
			tops.append(row)
			for frame in count:
				var phase := frame/float(count) if name in ["walk","run","sit","feed"] else (frame/float(count-1) if count > 1 else 0.0)
				# Runtime contact at 0.5 s matches the peak at frame eight.
				if name.begins_with("attack") or name.begins_with("enter"): phase = frame/16.0 if frame <= 8 else 0.5+(frame-8)/14.0
				actor.pose("enter_attack" if name.begins_with("enter") else ("attack" if name.begins_with("attack") else name),phase,direction,not name.ends_with("right"))
				await process_frame; await RenderingServer.frame_post_draw
				var picture := preload("res://scripts/visual_style.gd").outlined(viewport.get_texture().get_image())
				row.append(picture.get_used_rect().position.y)
				sheet.blit_rect(picture,Rect2i(Vector2i.ZERO,CELL),Vector2i(frame*CELL.x,direction*CELL.y))
		var path: String = OUTPUT+name+".png"
		if sheet.save_png(path) != OK: push_error("Enemy export failed: "+path); quit(1); return
		manifest[name] = {"path":path,"frames":count,"directions":16,"tops":tops}
		print("BAKED young ",name,": 16 directions × ",count," frames")
	var file := FileAccess.open(OUTPUT+"manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t")); file.close()
	print("PASS young enemy complete sprite export"); quit()
