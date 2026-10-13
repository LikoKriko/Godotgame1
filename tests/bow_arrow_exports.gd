extends "res://tools/bake_complete_sprites.gd"
var checks := 0

func require(value: bool,message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func distance(a: Color,b: Color) -> float:
	return absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)

func run() -> void:
	setup(); await frame_ready()
	for armor in [&"",&"burdock_armor"]:
		actor.armor_id = armor
		var key := "bow" if armor == &"" else String(armor)+"__bow"
		for state in [&"walk",&"run",&"crouch_walk"]:
			var exported := Image.load_from_file(ProjectSettings.globalize_path(OUTPUT+key+"_"+String(state)+".png"))
			for direction in [0,8,12]:
				for index in [0,3,6,9]:
					var phase: float = index/12.0
					actor.nocked_arrow_enabled = true
					actor.build(&"bow",&"bow",state,phase,direction)
					await protect_body(&"bow",direction); await frame_ready()
					var arrow: Image = viewport.get_texture().get_image()
					actor.nocked_arrow_enabled = false
					actor.build(&"bow",&"bow",state,phase,direction)
					await protect_body(&"bow",direction); await frame_ready()
					var empty: Image = viewport.get_texture().get_image()
					var visible := 0
					var preserved := 0
					for y in CELL.y:
						for x in CELL.x:
							var pixel := arrow.get_pixel(x,y)
							if pixel.a > 0.99 and distance(pixel,empty.get_pixel(x,y)) > 0.08:
								visible += 1
								if distance(pixel,exported.get_pixel(index*CELL.x+x,(direction/2)*CELL.y+y)) < 0.08:
									preserved += 1
					var pose := "%s/%s/%d/%d" % [key,state,direction,index]
					require(visible > 0,"A nocked arrow remains visible while moving: "+pose)
					require(preserved >= visible*0.9,"The shipped sprite retains visible arrow pixels: "+pose)
	print("%s: %d moving arrow export checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(1 if failures else 0)
