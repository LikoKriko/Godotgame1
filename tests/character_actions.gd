extends SceneTree
const Rig = preload("res://scripts/arm_rig.gd")
const Motion = preload("res://scripts/turn_motion.gd")
const Frames = preload("res://scripts/survivor_frames.gd")
const Tools = preload("res://scripts/tool_sprites.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run_checks")
func require(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
func run_checks() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	var origin := Vector2(1024,-400)
	for i in 8:
		var facing: StringName = Motion.FACINGS[i]
		var aim := origin+Vector2.from_angle(i*PI/4)*100
		for item in [&"",&"axe",&"pickaxe"]:
			var previous: Array[Vector2] = []
			var first_hand := Vector2.ZERO
			var first_tip := Vector2.ZERO
			for step in 121:
				var pose: Dictionary = game.arm_rig.animate(origin,aim,item,step/120.0)
				var active: int = pose["index"]
				for j in 2:
					var limb = game.arm_rig.layers[j]
					var expected: Vector2 = origin+Rig.ANCHORS[facing][j]
					require(limb.to_global(limb.shoulder).is_equal_approx(expected),"Shoulders remain pinned to body, including far from the world origin")
					require(limb.upper.texture == Frames.IDLE_SHEET and limb.lower.texture == Frames.IDLE_SHEET,"Both segments retain the character's exact skin atlas")
					require(limb.upper.color == Color.WHITE and limb.lower.color == Color.WHITE,"Arms do not introduce an independent skin tint")
					require(limb.z_index <= game.character.z_index,"Foreground foliage affects body and arms together")
					require(limb.shoulder.distance_to(limb.elbow) <= Rig.UPPER+0.001 and limb.elbow.distance_to(limb.hand) <= Rig.FOREARM+0.001,"Projected arms never exceed their physical bone lengths")
					if not previous.is_empty():
						require(previous[j].distance_to(limb.elbow) < 2.5,"Elbows move continuously: %s %s step=%d limb=%d delta=%.3f" % [facing,item,step,j,previous[j].distance_to(limb.elbow)])
				if step == 0:
					first_hand = game.arm_rig.layers[active].hand
					first_tip = game.arm_rig.layers[active].tip
				elif step == 120:
					require(first_hand.is_equal_approx(game.arm_rig.layers[active].hand) and first_tip.is_equal_approx(game.arm_rig.layers[active].tip),"Completed strikes return to the exact initial hand/tool pose")
				previous = [game.arm_rig.layers[0].elbow,game.arm_rig.layers[1].elbow]
		var axe_pose: Dictionary = game.arm_rig.animate(origin,aim,&"axe",0.22)
		var axe_hand: Vector2 = game.arm_rig.layers[axe_pose["index"]].hand
		var windup_tip: Vector2 = game.arm_rig.layers[axe_pose["index"]].tip
		var pick_pose: Dictionary = game.arm_rig.animate(origin,aim,&"pickaxe",0.22)
		require(axe_hand.distance_to(game.arm_rig.layers[pick_pose["index"]].hand) > 3 or windup_tip.distance_to(game.arm_rig.layers[pick_pose["index"]].tip) > 6,"Axe and pickaxe have different anatomical wind-ups")
		game.arm_rig.equip(origin,facing,&"axe",0.5,Rig.idle_hand(facing))
		var equipped_arm := 0 if facing in [&"left",&"up_left",&"down_left"] else 1
		var axe_tip: Vector2 = game.arm_rig.layers[equipped_arm].tip
		var axe_equip_hand: Vector2 = game.arm_rig.layers[equipped_arm].hand
		game.arm_rig.equip(origin,facing,&"pickaxe",0.5,Rig.idle_hand(facing))
		require(axe_tip.distance_to(game.arm_rig.layers[equipped_arm].tip) > 5 or axe_equip_hand.distance_to(game.arm_rig.layers[equipped_arm].hand) > 5,"Equipping each tool uses a distinct gesture")
	for id in [&"axe",&"pickaxe"]:
		var data: Dictionary = Tools.DATA[id]
		var pixel: Color = Tools.SHEET.get_image().get_pixelv(data["contact"])
		require(pixel.a > 0.6 and pixel.r > 0.2,"Tool contact is on its actual stone head, not empty atlas space")
	game.arm_rig.hide()
	game.restart()
	game.bag.select_tool(&"pickaxe")
	game._process(0.1)
	require(game.equipping and game.arm_rig.visible,"Changing held item begins an equip animation in gameplay")
	game.inventory_panel.show()
	var elapsed: float = game.equip_elapsed
	game._process(1)
	require(game.equip_elapsed == elapsed,"Inventory pauses equip gestures")
	game.inventory_panel.hide()
	for i in 5:
		game._process(0.1)
	require(not game.equipping and game.held_tool.visible and not game.arm_rig.visible,"Equip finishes with the sprite visibly held in the hand")
	game.bag.unequip(&"hands")
	game._process(0.1)
	require(not game.held_tool.visible and not game.arm_rig.visible,"Unequipping removes the visible tool")
	print("%s: %d character action checks, %d failures: original skin, stable shoulders, smooth elbows, distinct gestures and visible equipment" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(0 if failures == 0 else 1)
