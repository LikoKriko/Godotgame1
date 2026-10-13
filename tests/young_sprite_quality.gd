extends SceneTree
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func require(condition: bool,message: String) -> void:
	checks += 1
	if not condition: failures += 1; push_error(message)
func run():
	var rig = preload("res://tools/enemy/young_volume.gd").new(); root.add_child(rig)
	for direction in 16:
		for state in ["idle","walk","attack"]:
			for frame in (12 if state == "walk" else 16):
				for left in [true,false]:
					rig.pose(state,frame/float(12 if state == "walk" else 15),direction,left)
					for index in 4:
						var expected := Vector2(4.4,4.2) if index%2 == 0 else Vector2(6.3,6.6)
						require(rig.limb_lengths[index].is_equal_approx(expected),"Continuous limbs preserve both bone lengths")
	var idle := Image.load_from_file("res://assets/enemies/first/idle.png")
	var enter := Image.load_from_file("res://assets/enemies/first/enter_left.png")
	var lower := Image.load_from_file("res://assets/enemies/first/lower.png")
	var directions := {}
	for direction in 16:
		var rest := idle.get_region(Rect2i(0,direction*96,96,96))
		directions[hash(rest.get_data())] = true
		for clip in ["walk","attack_left","attack_right"]:
			var image := Image.load_from_file("res://assets/enemies/first/"+clip+".png")
			var count := 12 if clip == "walk" else 16
			var poses := {}
			for frame in count:
				var picture := image.get_region(Rect2i(frame*96,direction*96,96,96))
				var bounds := picture.get_used_rect()
				require(bounds.position.x >= 3 and bounds.position.y >= 3 and bounds.end.x < 93 and bounds.end.y < 93,"No body, fist or toes clipped by the export cell")
				require(bounds.size.y >= 28 and bounds.size.y <= 58,"Young creature keeps its compact 32-unit height")
				poses[hash(picture.get_data())] = true
				if clip.begins_with("attack") and frame == 15:
					require(picture.get_data() == image.get_region(Rect2i(0,direction*96,96,96)).get_data(),"Repeated punches recover in the exact standing guard")
			require(poses.size() >= 8,"Walk/punch contains distinct full-body poses in every direction")
		var entering := enter.get_region(Rect2i(0,direction*96,96,96))
		var lowered := lower.get_region(Rect2i(5*96,direction*96,96,96))
		require(entering.get_data() == rest.get_data() and lowered.get_data() == rest.get_data(),"Entering and lowering connect exactly with the four-legged idle pose")
	require(directions.size() == 16,"All sixteen exported orientations have distinct complete drawings")
	rig.free(); print("%s: %d young sprite quality checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures]); quit(1 if failures else 0)
