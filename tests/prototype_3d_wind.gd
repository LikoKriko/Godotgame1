extends SceneTree
const Settings=preload("res://scripts/game_settings.gd")
const Profile=preload("res://data/weather/soft_north_wind.tres")
var checks:=0;var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var existed:=FileAccess.file_exists(Settings.PATH)
 var previous:PackedByteArray=FileAccess.get_file_as_bytes(Settings.PATH) if existed else PackedByteArray()
 var config:=ConfigFile.new();config.set_value("settings","master",.4);config.save(Settings.PATH)
 var migrated:=Settings.new();migrated.load_settings()
 require(migrated.values.wind_trial and migrated.values.master==.4,"Existing preferences enable soft wind without losing other choices")
 var world=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();world.use_test_layout=true;root.add_child(world);world.paused=true
 var wind=world.wind;var particles:CPUParticles3D=wind.particles
 var source_mesh:Mesh=world.player.model.mesh_node.mesh
 var source_bones:int=world.player.model.native.skeleton.get_bone_count()
 var button:CheckButton=world.settings_panel.find_child("WindTrial",true,false)
 require(button!=null and button.button_pressed,"Graphics offers the enabled wind comparison")
 require(Profile.direction==Vector3.FORWARD,"North is negative world Z, the top of the map")
 require(Profile.visible_radius*2==20 and particles.emission_ring_radius==10,"Visible gusts occupy twenty metres in diameter, not twenty in radius")
 require(particles.amount<=18 and particles.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"One small particle pool casts no shadows")
 require(not particles.local_coords and particles.spread==0 and particles.gravity==Vector3.ZERO,"Streaks drift north in world space instead of following the camera")
 require(Profile.opacity<=.02 and Profile.response_amplitude<=.015,"Visibility and future tip response remain very subtle")
 for time in [0.,.5,2.,7.,19.,83.]:
  for point in [Vector3.ZERO,Vector3(4,2,-7),Vector3(-230,1,82)]:
   var velocity:Vector3=wind.sample_velocity(point)
   require(velocity.x==0 and velocity.y==0 and velocity.z<0,"Wind always travels north")
   require(velocity.length()>=.5499 and velocity.length()<=.7501,"Soft gusts stay within the configured speed range")
   var carried:Vector3=point+Profile.direction*4
   require(is_equal_approx(Profile.gust_at(point,time),Profile.gust_at(carried,time+4/Profile.gust_wavelength*Profile.gust_period)),"Gust envelopes propagate towards north")
  wind.elapsed=time
 var before:float=wind.elapsed;wind._process(.5)
 require(wind.elapsed==before and particles.speed_scale==0,"Pause freezes the field clock and its visual pool")
 world.paused=false
 world.player.position+=Vector3(100,0,-200);wind._process(.5)
 require(wind.global_position==world.player.global_position,"Visibility region follows the observer after teleporting")
 require(wind.material.get_shader_parameter("observer")==Vector2(world.player.global_position.x,world.player.global_position.z),"Shader clips around the same observer as the emission region")
 var parameters:Dictionary=wind.shader_inputs(world.player.global_position)
 require(parameters.wind_direction==Vector3.FORWARD and parameters.wind_displacement>0 and parameters.wind_displacement<=.015,"Hair, leaf and cloth consumers receive the same field and small amplitude")
 var seed:int=world.world_seed;var hour:float=world.day_cycle.hour
 button.button_pressed=false;var stopped:float=wind.elapsed;wind._process(10)
 require(not particles.visible and wind.elapsed==stopped and wind.sample_velocity(Vector3.ZERO)==Vector3.ZERO,"Disabling wind immediately hides gusts and stops its field")
 var saved:=Settings.new();saved.load_settings();require(not saved.values.wind_trial and saved.values.master==.4,"Wind preference persists without changing unrelated settings")
 button.button_pressed=true
 require(wind.enabled and world.world_seed==seed and world.day_cycle.hour==hour,"Re-enabling wind preserves world generation and the clock")
 require(world.player.model.mesh_node.mesh==source_mesh and world.player.model.native.skeleton.get_bone_count()==source_bones,"Wind preserves the unprepared character mesh and skeleton")
 world.original_shadows.apply(world.main_sun);world.free();await process_frame
 if existed:
  var file:=FileAccess.open(Settings.PATH,FileAccess.WRITE);file.store_buffer(previous);file.close()
 else:DirAccess.remove_absolute(Settings.PATH)
 print("%s: %d soft north wind, gust radius, pause and preference checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
