extends SceneTree
var failures := 0
var checks := 0
func _initialize(): call_deferred("run")
func require(ok: bool,message: String):
 checks += 1
 if not ok: failures += 1; push_error(message)
func run():
 var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false)
 game.player = Vector2(31.234,47.897)
 game.gameplay_settings.values["sharp_camera"] = false; game.update_camera_position()
 require(game.camera.position == game.player,"Continuous camera remains the default behavior")
 game.gameplay_settings.values["sharp_camera"] = true
 for zoom in [1.0,1.95,2.6]:
  game.camera.zoom = Vector2.ONE*zoom; game.update_camera_position()
  var pixels: Vector2 = game.camera.zoom*game.get_viewport().get_final_transform().get_scale().abs()
  var camera_pixels: Vector2 = game.camera.position*pixels
  require(camera_pixels.is_equal_approx(camera_pixels.round()),"Sharp camera lands on physical pixels at every zoom")
  require(game.player == Vector2(31.234,47.897),"Camera snapping never changes player physics")
 var panel = preload("res://scripts/settings_panel.gd").new(); root.add_child(panel); panel.configure(game.gameplay_settings)
 var control: CheckButton = panel.find_child("SharpCamera",true,false)
 require(control != null and control.button_pressed,"Graphics contains the saved sharp-camera setting")
 control.button_pressed = false
 require(not panel.pending.sharp_camera and game.gameplay_settings.values.sharp_camera,"Pending camera changes wait for Apply")
 print("%s: %d camera checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures]); game.free(); panel.free(); quit(1 if failures else 0)
