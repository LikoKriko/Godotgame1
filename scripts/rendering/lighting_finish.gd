extends RefCounted
## Instance state is separate from the immutable palette resource. Color ambient
## and disabled sky reflections keep Compatibility from updating radiance maps.
const PROFILE=preload("res://data/rendering/lighting_finish_trial.tres")
const SKY_SHADER=preload("res://assets/shaders/lighting_sky.gdshader")
const ENVIRONMENT_PROPERTIES:Array[StringName]=[&"background_mode",&"sky",&"reflected_light_source",&"fog_enabled",&"fog_mode",&"fog_depth_begin",&"fog_depth_end",&"fog_depth_curve",&"fog_density",&"fog_light_color",&"fog_light_energy",&"fog_aerial_perspective",&"fog_sun_scatter"]
var original:Dictionary={}
var original_sun_color:Color
var sky:=Sky.new()
var material:=ShaderMaterial.new()
var active:=false
var uniforms:Dictionary={}
func configure(environment:Environment,sun:DirectionalLight3D) -> void:
 for property in ENVIRONMENT_PROPERTIES:original[property]=environment.get(property)
 original_sun_color=sun.light_color
 material.shader=SKY_SHADER;sky.sky_material=material
 sky.radiance_size=Sky.RADIANCE_SIZE_32;sky.process_mode=Sky.PROCESS_MODE_INCREMENTAL
func sample(daylight:Dictionary,night_background:Color,enabled:bool) -> Dictionary:
 return PROFILE.sample(daylight,night_background) if enabled else {}
func apply(environment:Environment,state:Dictionary,world_radius:float=INF) -> void:
 if state.is_empty():
  if active:
   for property in ENVIRONMENT_PROPERTIES:environment.set(property,original[property])
   active=false
  return
 if not active:
  environment.background_mode=Environment.BG_SKY;environment.sky=sky
  environment.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED
  environment.fog_mode=Environment.FOG_MODE_DEPTH
  environment.fog_depth_begin=PROFILE.haze_begin;environment.fog_depth_curve=1.6
  environment.fog_light_energy=1;environment.fog_aerial_perspective=0;environment.fog_sun_scatter=0
  active=true
 # Keep the authored near zone and opacity; finish the haze within the loaded
 # radius. Re-evaluate even while active so graphics changes apply when paused.
 var haze_end:=maxf(PROFILE.haze_begin+.01,minf(PROFILE.haze_end,world_radius))
 if not is_equal_approx(environment.fog_depth_end,haze_end):environment.fog_depth_end=haze_end
 for uniform in [&"zenith",&"horizon"]:
  if uniforms.get(uniform)!=state[uniform]:material.set_shader_parameter(uniform,state[uniform]);uniforms[uniform]=state[uniform]
 var haze_active:bool=state.haze_opacity>0.00001
 if environment.fog_enabled!=haze_active:environment.fog_enabled=haze_active
 if environment.fog_light_color!=state.haze_color:environment.fog_light_color=state.haze_color
 if not is_equal_approx(environment.fog_density,state.haze_opacity):environment.fog_density=state.haze_opacity
