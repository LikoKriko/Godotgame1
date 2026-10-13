extends SceneTree
var failures := 0
func require(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var World = preload("res://scripts/test_world.gd")
	for seed in [73129,42,1937,81280]:
		var world = World.new()
		world.generate(seed)
		require(world.grass_tufts.size() == roundi(world.previous_grass_count*1.35),"Cover contains exactly 35 percent more groups than the previous seeded map")
		var variants := {}
		require(world.grass_tufts.size() > 2500,"Uniform cover populates the whole small map")
		require(not world.props.values().has(0) and not world.props.values().has(3),"Only natural objects remain in the woodland")
		for tuft in world.grass_tufts:
			variants[tuft["variant"]] = true
			require(world.grass_allowed(tuft["position"],world.grass_padding(tuft["width"],tuft["variant"])),"Grass stays outside trails, stone and puddle boundaries")
		require(variants.size() == 12,"Every one of twelve grass groups occurs")
		var again = World.new()
		again.generate(seed)
		require(again.grass_tufts == world.grass_tufts and again.dirt_patches == world.dirt_patches,"Ground cover is reproducible from map seed")
	print("%s: ground cover across four seeds: twelve groups, clear paths, puddles and stone" % ["PASS" if failures == 0 else "FAIL"])
	quit(0 if failures == 0 else 1)
