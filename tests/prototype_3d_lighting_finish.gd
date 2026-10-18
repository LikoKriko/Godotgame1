extends SceneTree
## Live comparison, original environment restoration, clock continuity and a
## separate background material per world; no extra lighting/shadow instances.
const Settings=preload("res://scripts/game_settings.gd")
var failures:=0;var checks:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var existed:=FileAccess.file_exists(Settings.PATH)
 var previous:PackedByteArray=FileAccess.get_file_as_bytes(Settings.PATH) if existed else PackedByteArray()
 var config:=ConfigFile.new();config.set_value("settings","master",.4);config.save(Settings.PATH)
 var migrated:=Settings.new();migrated.load_settings()
 require(migrated.values.lighting_finish_trial and migrated.values.master==.4,"Old preferences acquire the finish without losing unrelated choices")
 var world=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();world.use_test_layout=true;root.add_child(world);world.paused=true
 var button:CheckButton=world.settings_panel.find_child("LightingFinishTrial",true,false)
 var environment:Environment=world.world_ambient
 var finish=world.lighting_finish
 require(button!=null and button.button_pressed,"Graphics exposes the enabled finish comparison")
 require(world.get_children().filter(func(node):return node is DirectionalLight3D).size()==2,"Finish adds no directional lights")
 var peak:=0.0
 for hour in [0.,5.999,6.,6.001,8.,13.,19.,19.999,20.,20.001,23.999]:
  world.day_cycle.hour=hour;world.refresh_daylight()
  var solar:bool=world.main_sun.visible;var lunar:bool=world.moon_light.visible
  var sun_rotation:Vector3=world.main_sun.rotation;var moon_energy:float=world.moon_light.light_energy
  require(environment.background_mode==Environment.BG_SKY and environment.sky==finish.sky,"Finish supplies the shared clock's gradient sky")
  require(environment.ambient_light_source==Environment.AMBIENT_SOURCE_COLOR and environment.reflected_light_source==Environment.REFLECTION_SOURCE_DISABLED,"Background does not request sky lighting or radiance reflections")
  require(environment.fog_mode==Environment.FOG_MODE_DEPTH and environment.fog_depth_begin>=35 and environment.fog_density<=.121,"Haze preserves nearby detail and remains subtle")
  require(not environment.volumetric_fog_enabled and not environment.ssao_enabled and not environment.glow_enabled,"Finish needs no volumetric or screen-space effects")
  if hour<6 or hour>=20:require(not environment.fog_enabled,"Nighttime avoids a zero-opacity fog evaluation")
  peak=maxf(peak,world.main_sun.light_energy)
  button.button_pressed=false
  for property in finish.ENVIRONMENT_PROPERTIES:require(environment.get(property)==finish.original[property],"Disabling restores the prior environment: "+str(property))
  require(world.main_sun.light_color==finish.original_sun_color,"Disabling restores the original solar tint")
  require(world.main_sun.visible==solar and world.moon_light.visible==lunar and world.moon_light.light_energy==moon_energy and world.main_sun.rotation==sun_rotation,"Comparison keeps sun/moon motion and the active shadow caster")
  if hour==13:require(is_equal_approx(world.main_sun.light_energy,1.2),"Legacy midday brightness is available for comparison")
  var saved:=Settings.new();saved.load_settings();require(not saved.values.lighting_finish_trial,"Disabled finish persists through preferences")
  button.button_pressed=true
  require(world.day_cycle.hour==hour and environment.sky==finish.sky,"Comparison preserves the authoritative clock")
 require(peak<1.1 and peak>1,"Midday sunlight retains detail with moderated intensity")
 world.day_cycle.hour=13;world.refresh_daylight()
 require(environment.ambient_light_color.b>environment.ambient_light_color.r,"Soft cool fill separates shaded forms from warm sunlight")
 var other=preload("res://scripts/rendering/lighting_finish.gd").new()
 require(other.material!=finish.material and other.sky!=finish.sky,"Worlds never share mutable sky uniforms")
 var saved:=Settings.new();saved.load_settings();require(saved.values.lighting_finish_trial and saved.values.master==.4,"Enabled finish and unrelated preferences survive reload")
 world.original_shadows.apply(world.main_sun);world.free();await process_frame
 if existed:
  var file:=FileAccess.open(Settings.PATH,FileAccess.WRITE);file.store_buffer(previous);file.close()
 else:DirAccess.remove_absolute(Settings.PATH)
 print("%s: %d lighting finish, clock, restoration and graphics preference checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
