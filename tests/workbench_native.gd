extends SceneTree
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func require(ok: bool,message: String):
 checks += 1
 if not ok: failures += 1; push_error(message)
func settle():
 for i in 6: await process_frame
func native_mouse(point: Vector2, pressed: int):
 var args := PackedStringArray([ProjectSettings.globalize_path("res://tests/native_pointer.py"),str(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)),str(roundi(point.x)),str(roundi(point.y)),str(pressed)])
 require(OS.execute("python3",args) == 0,"Native pointer reaches the window"); await settle()
func click(control: Control):
 var point := root.get_final_transform()*control.get_global_transform_with_canvas()*(control.size/2)+Vector2(root.position)
 await native_mouse(point,1); await native_mouse(point,0)
func key(code: Key):
 for pressed in [true,false]:
  var event := InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = pressed
  Input.parse_input_event(event); Input.flush_buffered_events(); await settle()
func run():
 root.size = Vector2i(1280,720)
 var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false)
 game.bag.add(&"basic_workbench",1)
 var item: Dictionary
 for entry in game.bag.slots:
  if entry.get("id") == &"basic_workbench": item = entry; break
 var location: Dictionary = game.bag.location(item.uid)
 game.bag.move_item(location.kind,location.index,&"quick",0); await key(KEY_1)
 var point := Vector2.INF
 for y in range(-80,81,8):
  for x in range(-80,81,8):
   if game.workbenches.can_place(Vector2(x,y)): point = Vector2(x,y); break
  if point.is_finite(): break
 require(point.is_finite(),"Placement fixture has free ground")
 var pointer: Vector2 = root.get_final_transform()*game.get_canvas_transform()*point+Vector2(root.position)
 await native_mouse(pointer,1); await native_mouse(pointer,0)
 require(game.workbenches.placing(),"Actual left click starts the selected table placement")
 await create_timer(1.45).timeout; await settle()
 require(game.styled_hud.placement_bar.visible and game.styled_hud.placement_fill.size.x > 50 and game.styled_hud.placement_fill.size.x < 220,"The pastel-green bar fills while standing still")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/tmp/day-zero-placement-reviewed.png")
 await key(KEY_ESCAPE)
 require(not game.workbenches.placing() and game.bag.count(&"basic_workbench") == 1,"Actual Escape cancels without consuming the table")
 await native_mouse(pointer,1); await native_mouse(pointer,0)
 await create_timer(3.1).timeout; await settle()
 require(game.workbenches.tables.size() == 1 and game.bag.count(&"basic_workbench") == 0,"Actual timer finishes placement and consumes one item")
 var rect: Rect2 = game.workbenches.graphic_rect(point); var aim := Vector2.INF
 for y in range(1,31):
  for x in range(1,int(rect.size.x)):
   var candidate := rect.position+Vector2(x+0.5,y+0.5)
   if preload("res://scripts/workbench_art.gd").contains(candidate,rect) and preload("res://scripts/workbench_art.gd").contains(candidate-Vector2.ONE,rect) and preload("res://scripts/workbench_art.gd").contains(candidate+Vector2.ONE,rect): aim = candidate; break
  if aim.is_finite(): break
 pointer = root.get_final_transform()*game.get_canvas_transform()*aim+Vector2(root.position)
 await native_mouse(pointer,0); await key(KEY_E)
 require(game.workbenches.window.visible and game.is_paused(),"Actual E opens the table over its visible sprite surface")
 var page = game.workbenches.window.page
 game.bag.add(&"palo",2); game.bag.add(&"piedra",1); game.bag.add(&"cuerda",1)
 page.refresh(); await settle(); await click(page.recipe_buttons[&"sword"])
 require(page.selected == &"sword","Native recipe card selects the sword")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/tmp/day-zero-workbench-reviewed.png")
 var old: int = game.bag.count(&"sword")
 await click(page.create_button); require(page.is_crafting(),"Native Crear starts reserved crafting")
 await create_timer(2.1).timeout; await settle()
 require(game.bag.count(&"sword") == old+1,"Native crafting delivers the sword after two seconds")
 await key(KEY_ESCAPE); require(not game.workbenches.window.visible,"Escape closes the workshop")
 game.bag.equipment[&"torso"] = game.bag.make_item(&"burdock_armor",1); game.full_avatar.update_pose(0)
 await settle(); await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/tmp/day-zero-armor-world-reviewed.png")
 print("%s: %d native workbench/input/timer checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures]);quit(1 if failures else 0)
