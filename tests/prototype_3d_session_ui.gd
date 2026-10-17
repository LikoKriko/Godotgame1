extends SceneTree
var failures:=0
var checks:=0
var path:="/tmp/day-zero-native-session.save"
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func frame():
 await process_frame;await RenderingServer.frame_post_draw
func shot(_path_value):
 for i in 3:await frame()
 # The named checkpoints only wait for a rendered frame; no screenshots are exported.
func click(button:Control):
 await frame();await frame()
 var pos:Vector2=button.get_global_rect().get_center();root.warp_mouse(pos)
 await frame()
 var down:=InputEventMouseButton.new();down.position=pos;down.global_position=pos;down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;Input.parse_input_event(down)
 await frame()
 down=down.duplicate();down.pressed=false;Input.parse_input_event(down)
 await frame()
func wait_loaded(app):
 var limit:=Time.get_ticks_msec()+60000
 while app.loading_busy and Time.get_ticks_msec()<limit:await frame()
 require(not app.loading_busy and is_instance_valid(app.game),"Native world finished loading")
func run():
 if DisplayServer.get_name()=="headless":print("SKIP: requires a native display for actual mouse input");quit();return
 root.size=Vector2i(1280,720)
 for suffix in ["",".bak",".tmp"]:
  if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
 var app=load("res://scenes/prototype_3d/day_zero.tscn").instantiate();app.save_path=path;root.add_child(app)
 var original:Dictionary=app.settings.values.duplicate(true);var window_size:=root.size;var scale_mode:=root.content_scale_mode
 await shot("/tmp/day-zero-main-menu-3d.png")
 await click(app.menu.settings_button)
 require(is_instance_valid(app.menu.settings_panel),"Native pointer activates title settings at its visible button")
 var panel=app.menu.settings_panel;panel.tabs.current_tab=1
 var fps=panel.find_child("FPS",true,false);await click(fps)
 require(fps.get_popup().visible,"FPS list is visible inside the game window")
 await shot("/tmp/day-zero-3d-settings-fps.png")
 fps.get_popup().hide();fps.select(2);fps.item_selected.emit(2)
 require(Engine.max_fps==120 and root.size==window_size and root.content_scale_mode==scale_mode,"Graphics applies FPS without resizing the viewport or cursor coordinates")
 var aa=panel.find_child("MSAA",true,false);aa.select(1);aa.item_selected.emit(1)
 require(root.msaa_3d==Viewport.MSAA_2X and root.size==window_size,"3D antialiasing applies without changing input coordinates")
 # Keep the native UI/save round-trip bounded on software renderers. Full
 # generation at 200/400 m is covered independently by the streaming suite.
 var generation=panel.find_child("WorldGeneration",true,false)
 generation.select(0);generation.item_selected.emit(0)
 require(app.settings.values.world_generation==100,"World generation applies 100 m from the actual graphics selector")
 panel.tabs.current_tab=2;var volume=panel.find_child("master",true,false);volume.value=0.25
 require(absf(AudioServer.get_bus_volume_db(0)-linear_to_db(0.25))<0.01,"Audio slider updates the actual master bus")
 panel.tabs.current_tab=0;panel.hud_slider.value=3;panel.auto_run.button_pressed=true
 require(app.settings.values.hud_size==3 and app.settings.values.auto_run,"HUD and automatic running apply from main settings")
 app.menu.close_settings();await frame()
 await click(app.menu.new_game_button);await wait_loaded(app)
 if not is_instance_valid(app.game):app.free();quit(1);return
 var game=app.game;game.player.equip_elapsed=-1;game.toggle_pause()
 await click(game.save_button)
 require(FileAccess.file_exists(path),"Native pointer activates manual save in pause")
 await shot("/tmp/day-zero-3d-pause-save.png")
 await click(game.return_button)
 for i in 3:await frame()
 require(app.game==null and app.menu.can_continue,"Native return-to-title button releases world and exposes Continue")
 await click(app.menu.continue_button);await wait_loaded(app)
 require(is_instance_valid(app.game),"Native Continue loads a saved 3D session")
 app.settings.values=original;preload("res://scripts/prototype_3d/settings_panel.gd").apply_runtime(app.settings,root);app.settings.save_settings()
 app.free();await frame()
 for suffix in ["",".bak",".tmp"]:
  if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
 print("%s: %d native menu, settings, save/load and cursor checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
