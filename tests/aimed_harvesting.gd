extends SceneTree
const Rig = preload("res://scripts/arm_rig.gd")
const Aim = preload("res://tests/aim_fixture.gd")
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
	# The two rigid arm segments retain their length in every direction,
	# throughout wind-up, contact and recovery, for every equipped item.
	for item in Rig.TOOL_LENGTHS:
		for i in 8:
			for distance in [1.0, 25.0, 60.0, 1000.0]:
				var aim: Vector2 = Vector2.from_angle(i*TAU/8)*distance
				var pose := Rig.contact(Vector2.ZERO,aim,item)
				for phase in [0.0,0.15,0.35,0.5,0.8,1.0]:
					game.arm_rig.animate(Vector2.ZERO,aim,item,phase)
					for limb in game.arm_rig.layers:
						require(is_equal_approx(limb.shoulder.distance_to(limb.elbow),Rig.UPPER),"Upper arm never stretches")
						require(is_equal_approx(limb.elbow.distance_to(limb.hand),Rig.FOREARM),"Forearm never stretches")
					if phase == 0.5:
						require(game.arm_rig.layers[pose["index"]].tip.is_equal_approx(pose["tip"]),"Visible contact and logical tip coincide")
				if distance == 1000:
					require(not pose["reachable"],"Far cursor remains out of anatomical reach")
					var beyond: Dictionary = Rig.contact(Vector2.ZERO,pose["tip"]+pose["direction"]*0.25,item)
					if beyond["facing"] == pose["facing"] and beyond["index"] == pose["index"]:
						require(not beyond["reachable"],"Even a cursor just beyond the same shoulder limit cannot extend natural reach")
	game.arm_rig.hide()
	var world = game.world
	require(world.saplings.size() == 20,"Twenty young hand-harvestable trees")
	require(world.grass_tufts.size() > 300,"Natural grass populates the ground")
	require(world.puddles.size() >= 3 and world.puddles.size() <= 5,"Puddles remain rare")
	for puddle in world.puddles:
		for other in world.puddles:
			if other != puddle:
				require(puddle["position"].distance_to(other["position"]) >= 600,"Puddles are widely spaced")
	for cell in world.props:
		var record: Dictionary = game.world_view.hit_meshes.targets[cell]
		require(record["area"].get_child_count() > 0,"Each prop has an impact silhouette mesh")
		var bitmap: BitMap = record["bitmap"]
		require(bitmap.get_size() == Vector2i(record["texture_size"]),"Hit mask matches cropped texture size")
		# Locate both a solid texel and a transparent texel, then exercise the
		# world-to-local transform, rather than accepting the bounding rectangle.
		var transparent := false
		var solid := false
		for y in range(0,bitmap.get_size().y,9):
			for x in range(0,bitmap.get_size().x,9):
				var pixel := Vector2i(x,y)
				var point: Vector2 = record["area"].global_transform*Vector2(x+0.5,y+0.5)
				if bitmap.get_bitv(pixel) and not solid:
					require(game.world_view.hit_meshes.contains(cell,point),"Opaque texel is hittable")
					solid = true
				elif not bitmap.get_bitv(pixel) and not transparent:
					require(not game.world_view.hit_meshes.contains(cell,point),"Transparent texel is not hittable")
					transparent = true
				if transparent and solid:
					break
			if transparent and solid:
				break
		require(solid and transparent,"Silhouette fixture contains both opaque and empty pixels")
	var tree := Vector2i(-4,-3)
	var aim: Vector2 = Aim.approach(game,tree,&"axe")
	var initial_hp: int = game.resources.nodes[tree]["remaining"]
	var mesh: Area2D = game.world_view.hit_meshes.targets[tree]["area"]
	var rest := mesh.transform
	game.start_work(aim)
	game.advance_work(game.work_duration*0.49)
	require(game.resources.nodes[tree]["remaining"] == initial_hp,"Wind-up causes no early damage")
	game.advance_work(game.work_duration*0.02,Vector2.ZERO)
	game.advance_work(game.work_duration)
	require(game.resources.nodes[tree]["remaining"] == initial_hp,"Moving the live cursor away makes the strike miss")
	require(game.world_view.impulses.is_empty() and game.world_view.particles.is_empty(),"Miss produces no object movement or debris")
	require(mesh.transform == rest and game.bag.equipment[&"hands"]["uses"] == 30,"Miss preserves mesh and durability")
	game.player = Vector2.ZERO
	game.start_work(aim)
	game.advance_work(game.work_duration)
	require(game.resources.nodes[tree]["remaining"] == initial_hp,"Cursor over a distant tree cannot damage it")
	require(game.world_view.impulses.is_empty(),"Out-of-reach strike leaves target still")
	game.player = aim+Vector2(-54.75,25)
	game.start_work(aim)
	game.advance_work(game.work_duration)
	require(game.resources.nodes[tree]["remaining"] == initial_hp,"Cursor just beyond tool tip cannot damage the tree")
	require(game.world_view.impulses.is_empty(),"A near miss also leaves the object still")
	aim = Aim.approach(game,tree,&"axe")
	game.start_work(aim)
	game.advance_work(game.work_duration*0.5)
	require(game.resources.nodes[tree]["remaining"] == initial_hp-1,"Reachable aimed contact deals one hit")
	require(game.impact_position.is_equal_approx(aim),"Impact occurs at the cursor")
	require(game.bag.equipment[&"hands"]["uses"] == 29,"One valid hit consumes one use")
	game.world_view.update_trees(game.player,0.03)
	require(mesh.transform != rest,"A landed hit visibly moves the tree")
	var sprite: Sprite2D = game.world_view.tree_sprites[tree]
	require(mesh.transform == sprite.transform,"Impact mesh follows animated silhouette")
	game.world_view.update_trees(game.player,0.3)
	require(mesh.transform.is_equal_approx(rest),"Tree returns to rest after contact")
	require(game.world_view.impulses.is_empty() and game.world_view.particles.is_empty(),"Impact effects expire completely")
	game.cancel_work()
	# Equipment changes during wind-up cannot cause a stale-tool impact.
	game.start_work(aim)
	game.bag.select_tool(&"pickaxe")
	game.advance_work(game.work_duration)
	require(not game.working and game.resources.nodes[tree]["remaining"] == initial_hp-1,"Changing held item cancels pending strike")
	var sapling: Vector2i = world.saplings.keys()[0]
	aim = Aim.approach(game,sapling,&"")
	for i in 2:
		require(game.start_work(aim) and game.arm_rig.visible,"Bare hands animate at a young tree")
		game.advance_work(game.work_duration)
		game.world_view.update_trees(game.player,0.3)
	require(game.bag.count(&"fibra") == 3,"Hand-harvesting awards three plant fibers")
	require(not world.props.has(sapling) and not game.world_view.hit_meshes.targets.has(sapling),"Destroyed sapling removes impact and movement collision")
	require(not game.arm_rig.visible and str(game.character.animation).begins_with("idle_"),"Strike recovers to ordinary idle")
	var grass: Array = world.grass_tufts.duplicate(true)
	var puddles: Array = world.puddles.duplicate(true)
	game.restart()
	require(world.grass_tufts == grass and world.puddles == puddles,"Same seed reproduces natural ground details")
	require(world.saplings.has(sapling) and game.bag.count(&"fibra") == 0,"Reset restores young trees and clears fiber")
	print("%s: %d aimed-harvesting checks, %d failures: silhouettes, live cursor, anatomical reach, misses, impacts, fiber, decoration and reset" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(0 if failures == 0 else 1)
