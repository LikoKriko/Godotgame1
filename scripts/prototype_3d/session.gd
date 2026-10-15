extends Node
## Owns the title screen and one live 3D session; never touches the 2D save.
signal session_ready(world:Node3D)
const Save=preload("res://scripts/prototype_3d/save_game.gd")
var settings=preload("res://scripts/game_settings.gd").new()
var menu:Control
var game:Node3D
var loading_screen:CanvasLayer
var loading_busy:=false
var save_path:=Save.PATH
func _ready() -> void:
 settings.load_settings()
 preload("res://scripts/prototype_3d/settings_panel.gd").apply_runtime(settings,get_viewport())
 var layer:=CanvasLayer.new();layer.layer=100;add_child(layer)
 menu=preload("res://scripts/prototype_3d/main_menu.gd").new();layer.add_child(menu);menu.configure(settings)
 menu.play_requested.connect(continue_game);menu.new_game_requested.connect(new_game)
 loading_screen=preload("res://scripts/loading_screen.gd").new();add_child(loading_screen)
 refresh_saved_available();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func refresh_saved_available() -> void:
 var result:=Save.read_result(save_path);menu.set_saved_available(result.ok)
 if not result.ok and (FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path+".bak")):menu.message.text=result.message
func continue_game() -> void:
 if loading_busy:return
 var result:=Save.read_result(save_path)
 if not result.ok:menu.message.text=result.message;menu.set_saved_available(false);return
 await build_game(result.state)
 if not result.message.is_empty() and is_instance_valid(game):game.status.text=result.message
func new_game() -> void:
 if loading_busy:return
 await build_game({})
func build_game(state:Dictionary) -> void:
 loading_busy=true;menu.hide();loading_screen.begin(not state.is_empty());Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 discard_game()
 await get_tree().process_frame
 if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
 game=preload("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();game.initial_state=state.duplicate(true);game.save_path=save_path;game.settings=settings
 game.loading_changed.connect(loading_screen.set_progress)
 game.world_ready.connect(finish_loading)
 game.load_failed.connect(load_error)
 game.main_menu_requested.connect(return_to_title)
 add_child(game)
func finish_loading() -> void:
 game.paused=true
 loading_screen.set_progress(1)
 await get_tree().process_frame
 if not is_instance_valid(game):return
 loading_screen.hide();loading_busy=false;game.resume_world();session_ready.emit(game)
func load_error(message:String) -> void:
 call_deferred("show_load_error",message)
func show_load_error(message:String) -> void:
 discard_game();loading_busy=false;loading_screen.hide();menu.show();refresh_saved_available();menu.message.text=message;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func return_to_title() -> void:
 if loading_busy:return
 call_deferred("show_title")
func show_title() -> void:
 discard_game();menu.set_resume(false);refresh_saved_available();menu.show();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func discard_game() -> void:
 if not is_instance_valid(game):game=null;return
 game.paused=true;game.process_mode=Node.PROCESS_MODE_DISABLED
 # Return any reserved crafting inputs before releasing the active session.
 game.inventory_panel.creation_page.cancel_creation();game.workbenches.window.page.cancel_creation()
 remove_child(game);game.queue_free();game=null
