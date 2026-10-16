extends SceneTree
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func require(value: bool,message: String):
 checks += 1
 if not value: failures += 1; push_error(message)
func settle():
 for i in 3: await process_frame
func pointer(control, local: Vector2, pressed: int = -1):
 var transform: Transform2D = control.get_global_transform_with_canvas() if control is Control else Transform2D.IDENTITY
 var p: Vector2 = root.get_final_transform()*transform*local+Vector2(root.position)
 var args := PackedStringArray([ProjectSettings.globalize_path("res://tests/native_pointer.py"),str(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)),str(roundi(p.x)),str(roundi(p.y))])
 if pressed >= 0: args.append(str(pressed))
 require(OS.execute("python3",args) == 0,"Native drag event delivered")
 await settle()
func drag(from: Control,to: Control):
 await pointer(from,from.size/2,1)
 var begin: Vector2 = root.get_final_transform()*from.get_global_transform_with_canvas()*(from.size/2)
 var end: Vector2 = root.get_final_transform()*to.get_global_transform_with_canvas()*(to.size/2)
 for i in range(1,9):
  var p := begin.lerp(end,i/8.0)
  await pointer(root,root.get_final_transform().affine_inverse()*p)
 await pointer(to,to.size/2,0)
func shift_click(control: Control):
 await pointer(control,control.size/2)
 for pressed in [true,false]:
  var e := InputEventMouseButton.new()
  e.position = root.get_final_transform()*control.get_global_transform_with_canvas()*(control.size/2)
  e.global_position = e.position; e.button_index = MOUSE_BUTTON_LEFT; e.pressed = pressed; e.shift_pressed = true
  Input.parse_input_event(e); Input.flush_buffered_events(); await settle()
func run():
 if DisplayServer.get_name() != "X11":quit(1);return
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();game.use_test_layout=true;root.add_child(game)
 root.position=Vector2i.ZERO;game.toggle_inventory(0);await settle()
 var ui=game.inventory_panel;var uid:int=game.bag.slots[0].uid
 await drag(ui.backpack_buttons[0],ui.quick_buttons[1])
 require(game.bag.slots[0].is_empty() and game.bag.quick_slots[1].get("uid")==uid,"Native drag follows scaled 3D inventory coordinates")
 await shift_click(ui.quick_buttons[1])
 require(game.bag.quick_slots[1].is_empty() and game.bag.location(uid).kind==&"bag","Shift click returns physical quick storage")
 await pointer(ui.navigation.buttons[1],ui.navigation.buttons[1].size/2,1)
 await pointer(ui.navigation.buttons[1],ui.navigation.buttons[1].size/2,0)
 require(ui.sections[1].visible,"Visible creation tab receives native click at its centre")
 game.inventory_panel.hide();await settle()
 require(not game.paused and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Closing inventory restores capture without a native popup")
 game.free();print("%s: %d native 3D interface checks, %d failures"%["PASS" if failures==0 else "FAIL",checks,failures]);quit(1 if failures else 0)
