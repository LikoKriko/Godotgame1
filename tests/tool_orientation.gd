extends SceneTree
var failures := 0
var checks := 0
func _initialize(): call_deferred("run")
func check(condition: bool,message: String):
	checks += 1
	if not condition: failures += 1; push_error(message)
func run():
	var actor = preload("res://tools/continuous_actor.gd").new(); root.add_child(actor)
	for item in [&"axe",&"pickaxe"]:
		for direction in 16:
			var previous := Vector3.ZERO
			var idle_axis := Vector3.ZERO
			actor.build(item,item,&"idle",0,direction)
			idle_axis = actor.tool_cutting_axis
			for frame in 33:
				var phase := frame/32.0
				actor.build(item,item,&"action",phase,direction)
				check(actor.grip_error < 0.04,"Both hands remain on the same rigid handle")
				check(actor.tool_tip.is_finite() and actor.tool_cutting_axis.is_normalized(),"Every cutting tip and blade axis is finite")
				if frame > 0: check(previous.dot(actor.tool_cutting_axis) > 0.5,"No cutting-face inversion between consecutive action poses")
				if frame in [0,32]: check(idle_axis.is_equal_approx(actor.tool_cutting_axis),"Rest, first and recovered cutting faces share the same orientation")
				previous = actor.tool_cutting_axis
	actor.free(); print("%s: %d tool orientation checks, %d failures" % ["PASS" if not failures else "FAIL",checks,failures]); quit(1 if failures else 0)
