extends SceneTree
const Actor = preload("res://tools/continuous_actor.gd")
const Inventory = preload("res://scripts/inventory.gd")
const CELL := Vector2i(192,192)
const OUTPUT := "res://assets/characters/complete/"
var viewport: SubViewport
var camera: Camera3D
var actor: Node3D
var failures := 0
var armor_id: StringName = &""

func _initialize() -> void: call_deferred("run")

func setup() -> void:
	# The export viewport stays 192×192; a small empty window avoids rendering
	# a full-HD background for every authored pose on the cloud CPU renderer.
	root.size = Vector2i(256,256)
	viewport = SubViewport.new()
	viewport.size = CELL
	viewport.transparent_bg = true
	viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 128
	camera.position = Vector3(0,78,200)
	viewport.add_child(camera)
	camera.look_at(Vector3(0,34,0))
	actor = Actor.new()
	viewport.add_child(actor)
	actor.camera_up = camera.global_basis.y

func frame_ready() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func outlined(picture: Image) -> Image:
	return preload("res://scripts/visual_style.gd").outlined(picture)

func protect_body(item: StringName,direction: int) -> void:
	actor.tool_material.set_shader_parameter("protect_body",false)
	actor.body_material.set_shader_parameter("protect_bow_arm",false)
	if item == &"" or sin(direction*TAU/16) > 0.001: return
	actor.show_core_only()
	await frame_ready()
	var mask := ImageTexture.create_from_image(viewport.get_texture().get_image())
	actor.restore_full(item)
	actor.body_material.set_shader_parameter("body_mask",mask)
	actor.body_material.set_shader_parameter("protect_bow_arm",sin(direction*TAU/16) < -0.001)
	actor.tool_material.set_shader_parameter("body_mask",mask)
	actor.tool_material.set_shader_parameter("protect_body",true)

func sheet(item: StringName,family: StringName,state: StringName,count: int,directions: int,stop_frame: int = -1, from_start: bool = false) -> Dictionary:
	var result := Image.create(CELL.x*count,CELL.y*directions,false,Image.FORMAT_RGBA8)
	var grip_error := 0.0
	var anchors := []
	for direction in directions:
		var row := []
		for frame in count:
			var combined := String(state).begins_with("equip_") or state == &"pickup_walk"
			var pose_frame := frame/12 if combined else frame
			var phase := frame/float(count) if state in [&"walk",&"run",&"crouch_walk"] else (frame/float(count-1) if count > 1 else 0.0)
			if combined: phase = pose_frame/5.0
			if state == &"action": phase = frame/16.0 if frame <= 8 else 0.5+(frame-8)/14.0
			actor.build(item,family,state,phase,direction*(16/directions),(frame%12)/12.0 if combined else (0.0 if from_start else (stop_frame/12.0 if stop_frame >= 0 else 0.20)),smoothstep(0,1,stop_frame/5.0) if from_start else 1.0)
			await protect_body(item,direction*(16/directions))
			var grip: Vector3 = actor.last_pose["grip"]
			var yaw := PI/2-direction*(16.0/directions)*TAU/16
			var basis := Basis(Vector3.UP,yaw)
			var base: Vector3 = actor.last_pose["hands"][1]
			var tip := base+base.direction_to(actor.last_pose["hands"][0]+Vector3(0,1,0))*24
			var point := camera.unproject_position(basis*tip) if family == &"bow" else Vector2.ZERO
			if family == &"bow" and state == &"action" and frame == 8:
				row.append(snappedf(point.x,0.001))
				row.append(snappedf(point.y,0.001))
			grip_error = maxf(grip_error,actor.grip_error)
			await frame_ready()
			var picture := outlined(viewport.get_texture().get_image())
			picture.convert(Image.FORMAT_RGBA8)
			result.blit_rect(picture,Rect2i(Vector2i.ZERO,CELL),Vector2i(frame*CELL.x,direction*CELL.y))
		if not row.is_empty(): anchors.append(row)
	var id := "bare" if item == &"" else String(item)
	if armor_id != &"": id = String(armor_id)+"__"+id
	var suffix := ("_start_%02d" if from_start else "_%02d") % stop_frame if stop_frame >= 0 else ""
	var path := OUTPUT+id+"_"+String(state)+suffix+".png"
	var error := OK
	var paths := []
	var combined := String(state).begins_with("equip_") or state == &"pickup_walk"
	if combined:
		# Six equip stages, each with twelve gait frames. Every texture remains
		# below 4096 pixels instead of a 13824-pixel-wide GPU allocation.
		for stage in 6:
			var part_path := path.trim_suffix(".png")+"_%02d.png" % stage
			var part := result.get_region(Rect2i(stage*12*CELL.x,0,12*CELL.x,directions*CELL.y))
			var written := part.save_png(part_path)
			if written != OK: error = written
			paths.append(part_path)
		path = paths[0]
	else: error = result.save_png(path)
	if error != OK or grip_error > 0.04:
		failures += 1
		push_error("Export %s: write=%s, grip_error=%s" % [path,error,grip_error])
	print("BAKED %s: %d directions × %d frames; grip error %.5f" % [path,directions,count,grip_error])
	var data := {"path":path,"frames":12 if combined else count,"directions":directions,"grip_error":snappedf(grip_error,0.00001)}
	if combined: data["equip_frames"] = 6; data["gait_frames"] = 12; data["paths"] = paths
	if not anchors.is_empty(): data["release_anchors"] = anchors
	if armor_id == &"" and item == &"" and state == &"idle": data["body_height"] = result.get_region(Rect2i(0,4*CELL.y,CELL.x,CELL.y)).get_used_rect().size.y
	return data

func run() -> void:
	setup()
	await frame_ready()
	var arguments := OS.get_cmdline_user_args()
	if "--armor" in arguments:
		armor_id = StringName(arguments[arguments.find("--armor")+1])
		actor.armor_id = armor_id
	if "--probe" in arguments:
		var contact := Image.create(CELL.x*8,CELL.y*4,false,Image.FORMAT_RGBA8)
		for row in 4:
			for column in 8:
				var item: StringName = [&"axe",&"pickaxe",&"sword",&"bow"][row]
				actor.build(item,item,&"action",0.25 if column%2 == 0 else 0.5,(column/2)*4)
				await protect_body(item,(column/2)*4)
				await frame_ready()
				contact.blit_rect(outlined(viewport.get_texture().get_image()),Rect2i(Vector2i.ZERO,CELL),Vector2i(column*CELL.x,row*CELL.y))
		contact.save_png("/tmp/continuous-body-probe.png")
		quit(); return
	var items: Array[StringName] = [&"",&"axe",&"pickaxe",&"sword",&"bow",&"bottle_empty",&"bottle_full"]
	if "--item" in arguments:
		var index := arguments.find("--item")
		items = [StringName(arguments[index+1])]
	if "--items" in arguments:
		items.clear()
		for id in arguments[arguments.find("--items")+1].split(","): items.append(StringName(id))
	var foot := camera.unproject_position(Vector3.ZERO)
	var manifest := {"version":2,"canvas":[CELL.x,CELL.y],"foot":[foot.x,foot.y],"world_span":128.0,"items":{}}
	var path := OUTPUT+"manifest.json"
	if FileAccess.file_exists(path):
		var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		manifest["items"] = previous["items"]
		manifest["pixels_per_world"] = previous.get("pixels_per_world",1.0)
	var selected_clips := PackedStringArray()
	if "--clips" in arguments:
		selected_clips = arguments[arguments.find("--clips")+1].split(",")
	for item in items:
		var family: StringName = Inventory.DEFINITIONS.get(item,{}).get("category",&"")
		if String(item).begins_with("bottle_"): family = &"bottle"
		var clips := {}
		var key := "bare" if item == &"" else String(item)
		if armor_id != &"": key = String(armor_id)+"__"+key
		if not selected_clips.is_empty():
			clips = manifest["items"][key]["clips"].duplicate(true)
			for name in selected_clips:
				if name not in ["action","pickup","pickup_walk","jump","crouch","slide","slide_jump","crouch_walk","equip_walk","equip_run","equip_crouch_walk","crouch_equip"]:
					push_error("Partial export currently supports jump,crouch,slide,crouch_walk only")
					quit(1); return
				clips[name] = await sheet(item,family,StringName(name),72 if name.begins_with("equip_") or name == "pickup_walk" else (16 if name == "action" else (12 if name == "crouch_walk" else 6)),16 if name in ["crouch_equip","action"] else 8)
			manifest["items"][key]["clips"] = clips
			var partial := FileAccess.open(path,FileAccess.WRITE)
			partial.store_string(JSON.stringify(manifest,"\t"))
			partial.close()
			continue
		clips["idle"] = await sheet(item,family,&"idle",1,16)
		if armor_id == &"" and item == &"": manifest["pixels_per_world"] = clips["idle"]["body_height"]/64.0
		clips["walk"] = await sheet(item,family,&"walk",12,8)
		clips["crouch_walk"] = await sheet(item,family,&"crouch_walk",12,8)
		clips["run"] = await sheet(item,family,&"run",12,8)
		clips["start_run"] = await sheet(item,family,&"start_run",6,8)
		for source in 12:
			clips["stop_run_%02d" % source] = await sheet(item,family,&"stop_run",6,8,source)
		for source in 6:
			clips["stop_run_start_%02d" % source] = await sheet(item,family,&"stop_run",6,8,source,true)
		clips["start"] = await sheet(item,family,&"start",6,8)
		for start_frame in 12:
			clips["stop_%02d" % start_frame] = await sheet(item,family,&"stop",6,8,start_frame)
		for start_frame in 6:
			clips["stop_start_%02d" % start_frame] = await sheet(item,family,&"stop",6,8,start_frame,true)
		clips["action"] = await sheet(item,family,&"action",16,16)
		if item == &"":
			clips["pickup"] = await sheet(item,family,&"pickup",6,8)
			clips["pickup_walk"] = await sheet(item,family,&"pickup_walk",72,8)
		if item != &"":
			clips["equip"] = await sheet(item,family,&"equip",6,16)
			clips["crouch_equip"] = await sheet(item,family,&"crouch_equip",6,16)
		for state in [&"jump",&"crouch",&"slide",&"slide_jump"]:
			clips[state] = await sheet(item,family,state,6,8)
		if item != &"":
			for state in [&"equip_walk",&"equip_run",&"equip_crouch_walk"]:
				clips[state] = await sheet(item,family,state,72,8)
		manifest["items"][key] = {"category":String(family),"armor":String(armor_id),"clips":clips}
		var progress := FileAccess.open(path,FileAccess.WRITE)
		progress.store_string(JSON.stringify(manifest,"\t"))
		progress.close()
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t"))
	file.close()
	actor.free()
	viewport.free()
	print("%s complete sprite export" % ("PASS" if failures == 0 else "FAIL"))
	quit(1 if failures else 0)
