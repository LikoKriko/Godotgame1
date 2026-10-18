extends SceneTree
## Integration: existing preferences, live A/B switch, original light restoration
## and preservation of the authoritative clock/lighting during the trial.
const Settings=preload("res://scripts/game_settings.gd")
const Profile=preload("res://scripts/rendering/sun_shadow_profile.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var existed:=FileAccess.file_exists(Settings.PATH)
 var previous:PackedByteArray=FileAccess.get_file_as_bytes(Settings.PATH) if existed else PackedByteArray()
 var config:=ConfigFile.new();config.set_value("settings","master",.4);config.save(Settings.PATH)
 var old:=Settings.new();old.load_settings()
 require(old.values.shadow_trial and old.values.moon_light_trial and old.values.master==.4,"Existing preferences acquire the trial without losing other settings")
 var world=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();world.use_test_layout=true;root.add_child(world);world.paused=true
 var moon:DirectionalLight3D=world.moon_light
 var moon_button:CheckButton=world.settings_panel.find_child("MoonLightTrial",true,false)
 require(moon_button!=null and moon_button.button_pressed,"Graphics page exposes the enabled lunar trial")
 var light:DirectionalLight3D=world.main_sun
 var button:CheckButton=world.settings_panel.find_child("ShadowTrial",true,false)
 require(button!=null and button.button_pressed,"Graphics page exposes the enabled trial")
 require(light.directional_shadow_max_distance==60 and light.directional_shadow_blend_splits,"Trial concentrates nearby detail and blends its cascades")
 require(light.shadow_bias<world.original_shadows.shadow_bias and light.shadow_normal_bias<world.original_shadows.shadow_normal_bias,"Trial reduces excessive separation from casters")
 var trial:Dictionary={}
 for property in Profile.PROPERTIES:trial[property]=light.get(property)
 var seed:int=world.world_seed;var day:int=world.day_cycle.day
 for hour in [0.,6.,8.,13.,19.,20.,23.9]:
  world.day_cycle.hour=hour;world.refresh_daylight()
  var orientation:Vector3=light.rotation;var energy:float=light.light_energy
  var ambient:Color=world.world_ambient.ambient_light_color
  button.button_pressed=false
  for property in Profile.PROPERTIES:require(light.get(property)==world.original_shadows.get(property),"Disabling restores the original sun: "+str(property))
  var loaded:=Settings.new();loaded.load_settings();require(not loaded.values.shadow_trial,"Trial can be disabled persistently from graphics")
  world.refresh_daylight()
  require(light.rotation.is_equal_approx(orientation) and light.light_energy==energy and world.world_ambient.ambient_light_color==ambient,"A/B comparison keeps the same hour and illumination")
  button.button_pressed=true;world.refresh_daylight()
  for property in Profile.PROPERTIES:require(light.get(property)==trial[property],"Daylight updates retain the trial profile: "+str(property))
  require(world.day_cycle.hour==hour and world.day_cycle.day==day and world.world_seed==seed,"Switching shadows preserves the clock and world")
 for hour in [0.,1.,5.,6.,8.,13.,19.,20.,21.,23.999]:
  world.day_cycle.hour=hour;world.refresh_daylight()
  var night:bool=hour<6 or hour>20
  require(moon.visible==night and moon.shadow_enabled==night,"Lunar shadows only load at night: "+str(hour))
  require(moon.light_energy>=0 and moon.light_energy<=0.16,"Moon remains faint: "+str(hour))
  require(moon.shadow_opacity<light.shadow_opacity*0.25,"Moon shadows are much fainter than sunlight")
  var solar_energy:float=light.light_energy;var solar_rotation:Vector3=light.rotation
  var ambient:Color=world.world_ambient.ambient_light_color
  moon_button.button_pressed=false
  require(not moon.visible and not moon.shadow_enabled and moon.light_energy==0,"Switch completely disables the lunar light and shadows")
  require(light.light_energy==solar_energy and light.rotation.is_equal_approx(solar_rotation) and world.world_ambient.ambient_light_color==ambient,"Lunar comparison preserves the sun and ambient light")
  var preference:=Settings.new();preference.load_settings();require(not preference.values.moon_light_trial,"Lunar preference is saved")
  moon_button.button_pressed=true
 world.day_cycle.hour=23.999;world.refresh_daylight();var before:Vector3=moon.rotation
 world.day_cycle.hour=0.001;world.refresh_daylight()
 require(before.distance_to(moon.rotation)<0.01,"Moon follows continuously across midnight")
 world.day_cycle.hour=13;world.refresh_daylight()
 require(not moon.shadow_enabled,"Daytime avoids an extra lunar shadow pass")
 var loaded:=Settings.new();loaded.load_settings();require(loaded.values.moon_light_trial and loaded.values.shadow_trial and loaded.values.master==.4,"Enabled trial and unrelated preferences survive reload")
 require(light.shadow_enabled and RenderingServer.get_current_rendering_method()=="gl_compatibility","Real sun shadows keep the existing Compatibility renderer")
 world.original_shadows.apply(light);world.free();await process_frame
 if existed:
  var file:=FileAccess.open(Settings.PATH,FileAccess.WRITE);file.store_buffer(previous);file.close()
 else:DirAccess.remove_absolute(Settings.PATH)
 print("%s: %d shadow trial, live comparison, persistence and daylight checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
