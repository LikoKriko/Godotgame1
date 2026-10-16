extends SceneTree
const Settings=preload("res://scripts/game_settings.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var existed:=FileAccess.file_exists(Settings.PATH)
 var previous:PackedByteArray=FileAccess.get_file_as_bytes(Settings.PATH) if existed else PackedByteArray()
 require(Settings.DEFAULTS.world_generation==200,"New installations default to two hundred metres")
 for value in [100,200,400,300,-1,0,100000]:
  var config:=ConfigFile.new();config.set_value("settings","world_generation",value);config.save(Settings.PATH)
  var settings:=Settings.new();settings.load_settings()
  require(settings.values.world_generation==(value if value in [100,200,400] else 200),"Only supported generation distances can be loaded: "+str(value))
 var config:=ConfigFile.new();config.set_value("settings","fps",60);config.save(Settings.PATH)
 var settings:=Settings.new();settings.load_settings()
 require(settings.values.world_generation==200,"Existing settings files without the new field migrate to the default")
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();game.use_test_layout=true;root.add_child(game);game.paused=true
 var control:OptionButton=game.settings_panel.find_child("WorldGeneration",true,false)
 require(control!=null and control.item_count==3,"Graphics page presents exactly three generation choices")
 require(control.get_item_text(0)=="100 metros" and control.get_item_text(1)=="200 metros (base)" and control.get_item_text(2)=="400 metros","Graphics captions match the requested distances")
 for index in 3:
  control.select(index);control.item_selected.emit(index)
  var loaded:=Settings.new();loaded.load_settings()
  require(loaded.values.world_generation==[100,200,400][index],"Selecting the option persists it to the real settings file")
 game.free()
 if existed:
  var file:=FileAccess.open(Settings.PATH,FileAccess.WRITE);file.store_buffer(previous);file.close()
 else:DirAccess.remove_absolute(Settings.PATH)
 print("%s: %d generation settings, persistence, migration and graphics-control checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
