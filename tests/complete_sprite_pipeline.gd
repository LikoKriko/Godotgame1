extends SceneTree
const Pose = preload("res://scripts/continuous_body_pose.gd")
const Clips = preload("res://scripts/complete_sprite_clips.gd")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func require(condition: bool,message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
func frame(picture: Image,column: int,row: int) -> Image:
	return picture.get_region(Rect2i(column*192,row*192,192,192))
func same(a: Image,b: Image) -> bool:
	return a.get_data() == b.get_data()
func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/complete/manifest.json"))
	for item in manifest["items"]:
		var clips: Dictionary = manifest["items"][item]["clips"]
		require(clips["walk"]["frames"] == 12 and clips["walk"]["directions"] == 8,"Walk has 12 full frames in eight directions")
		require(clips["action"]["frames"] == 16 and clips["action"]["directions"] == 16,"Action has 16 full frames in sixteen directions")
		for name in clips:
			var data: Dictionary = clips[name]
			var picture := Image.load_from_file(ProjectSettings.globalize_path(data["path"]))
			require(picture != null and picture.get_size() == Vector2i(192*int(data["frames"]),192*int(data["directions"])),"Export dimensions: "+String(item)+"/"+String(name))
			require(data["grip_error"] <= 0.04,"Both grips stay on the actual tool")
		for name in [&"equip_walk",&"equip_run",&"equip_crouch_walk"]:
			if not clips.has(name): continue
			var data: Dictionary = clips[name]
			require(data.equip_frames == 6 and data.gait_frames == 12 and data.paths.size() == 6,"Moving equipment retains six drawing stages and twelve stride phases")
			for path in data.paths:
				var sheet := Image.load_from_file(ProjectSettings.globalize_path(path))
				require(sheet.get_size() == Vector2i(2304,1536),"Equipment texture remains below common GPU size limits")
			var end := Image.load_from_file(ProjectSettings.globalize_path(data.paths[5]))
			var moving := Image.load_from_file(ProjectSettings.globalize_path(clips[String(name).trim_prefix("equip_")].path))
			for row in 8:
				for column in 12:
					require(same(frame(end,column,row),frame(moving,column,row)),"Drawing ends at the exact corresponding moving pose")
		var walk := Image.load_from_file(ProjectSettings.globalize_path(clips["walk"]["path"]))
		var start := Image.load_from_file(ProjectSettings.globalize_path(clips["start"]["path"]))
		var idle := Image.load_from_file(ProjectSettings.globalize_path(clips["idle"]["path"]))
		var action := Image.load_from_file(ProjectSettings.globalize_path(clips["action"]["path"]))
		for row in 8:
			require(not same(frame(walk,0,row),frame(walk,6,row)),"Opposite half strides have visibly different poses")
			for source in 12:
				var stop := Image.load_from_file(ProjectSettings.globalize_path(clips["stop_%02d" % source]["path"]))
				require(same(frame(stop,0,row),frame(walk,source,row)),"Stop starts from the exact displayed stride")
				require(same(frame(stop,5,row),frame(idle,0,row*2)),"Stop finishes at the exact idle pose")
			for source in 6:
				var stop := Image.load_from_file(ProjectSettings.globalize_path(clips["stop_start_%02d" % source]["path"]))
				require(same(frame(stop,0,row),frame(start,source,row)),"Early release preserves the partial starting stride")
		var crouched := Image.load_from_file(ProjectSettings.globalize_path(clips["crouch_walk"]["path"]))
		require(clips["crouch_walk"]["frames"] == 12 and clips["crouch_walk"]["directions"] == 8,"Crouched walking has twelve full frames in each direction")
		for row in 8:
			require(not same(frame(crouched,0,row),frame(crouched,6,row)),"Crouched walking alternates distinct half strides")
		var run_image := Image.load_from_file(ProjectSettings.globalize_path(clips["run"]["path"]))
		var run_start := Image.load_from_file(ProjectSettings.globalize_path(clips["start_run"]["path"]))
		require(clips["run"]["frames"] == 12 and not same(frame(run_image,3,0),frame(walk,3,0)),"Run has twelve distinct running poses, not accelerated walk frames")
		for row in 8:
			for source in 12:
				var stop := Image.load_from_file(ProjectSettings.globalize_path(clips["stop_run_%02d" % source]["path"]))
				require(same(frame(stop,0,row),frame(run_image,source,row)),"Running stop begins at the displayed running stride")
				require(same(frame(stop,5,row),frame(idle,0,row*2)),"Running stop resolves to idle")
			for source in 6:
				var stop := Image.load_from_file(ProjectSettings.globalize_path(clips["stop_run_start_%02d" % source]["path"]))
				require(same(frame(stop,0,row),frame(run_start,source,row)),"Early running release retains its partial starting stride")
		for row in 16:
			require(same(frame(action,0,row),frame(idle,0,row)) and same(frame(action,15,row),frame(idle,0,row)),"Action returns to its own ready pose")
	for i in 12:
		var pose := Pose.sample(&"",&"walk",i/12.0)
		for leg in pose["legs"]:
			require(is_equal_approx(leg["root"].distance_to(leg["joint"]),Pose.THIGH) and is_equal_approx(leg["joint"].distance_to(leg["end"]),Pose.SHIN),"Leg bones retain their lengths throughout the stride")
	for i in 12:
		var crouch := Pose.sample(&"",&"crouch_walk",i/12.0)
		var upright := Pose.sample(&"",&"walk",i/12.0)
		require(is_equal_approx(upright.body.origin.y-crouch.body.origin.y,6),"Crouched walking stays lowered throughout its gait")
		for leg in crouch.legs:
			require(is_equal_approx(leg.root.distance_to(leg.joint),Pose.THIGH) and is_equal_approx(leg.joint.distance_to(leg.end),Pose.SHIN),"Bent legs stay joined and keep their anatomical lengths")
	var before := Pose.sample(&"",&"walk",0)
	var after := Pose.sample(&"",&"walk",0.5)
	require(before["legs"][0]["end"].z > before["legs"][1]["end"].z and after["legs"][0]["end"].z < after["legs"][1]["end"].z,"Legs pass each other instead of translating together")
	print("%s: %d complete-sprite export checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(1 if failures else 0)
