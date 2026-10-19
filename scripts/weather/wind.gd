extends Node3D
## One small world-space particle pool, independent of source meshes and rigs.
## Pausing freezes both the visual pool and the clock exposed to consumers.
const PROFILE=preload("res://data/weather/soft_north_wind.tres")
var game
var enabled:=true
var elapsed:=0.0
var particles:=CPUParticles3D.new()
var material:=ShaderMaterial.new()
var observer:=Vector3.ZERO
func configure(owner_game) -> void:
 game=owner_game;name="WorldWind";global_basis=Basis.IDENTITY
 material.shader=preload("res://assets/shaders/wind_streak.gdshader")
 for parameter in [&"visible_radius",&"streak_length",&"streak_width",&"opacity",&"tint"]:material.set_shader_parameter(parameter,PROFILE.get(parameter))
 material.set_shader_parameter("wind_direction",PROFILE.direction.normalized())
 particles.name="FaintGusts";particles.amount=PROFILE.particle_count
 particles.lifetime=PROFILE.particle_lifetime;particles.local_coords=false
 particles.emission_shape=CPUParticles3D.EMISSION_SHAPE_RING
 particles.emission_ring_axis=Vector3.UP;particles.emission_ring_radius=PROFILE.visible_radius
 particles.emission_ring_inner_radius=0;particles.emission_ring_height=1.2
 particles.direction=PROFILE.direction.normalized();particles.spread=0;particles.gravity=Vector3.ZERO
 particles.initial_velocity_min=PROFILE.base_speed;particles.initial_velocity_max=PROFILE.base_speed+PROFILE.gust_speed
 particles.randomness=0.6;particles.lifetime_randomness=0.2
 particles.fixed_fps=30;particles.fract_delta=true
 particles.use_fixed_seed=true;particles.seed=game.world_seed+347
 particles.mesh=QuadMesh.new();particles.material_override=material
 particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var ramp:=Gradient.new();ramp.offsets=PackedFloat32Array([0,0.2,0.75,1])
 ramp.colors=PackedColorArray([Color(1,1,1,0),Color.WHITE,Color.WHITE,Color(1,1,1,0)])
 particles.color_ramp=ramp
 var reach:float=PROFILE.visible_radius+(PROFILE.base_speed+PROFILE.gust_speed)*PROFILE.particle_lifetime+PROFILE.streak_length
 particles.visibility_aabb=AABB(Vector3(-reach,-2,-reach),Vector3(reach*2,4,reach*2))
 add_child(particles);particles.position.y=1.0
 observer=game.player.global_position;global_position=observer
 material.set_shader_parameter("observer",Vector2(observer.x,observer.z))
 set_enabled(game.settings.values.wind_trial)
func set_enabled(value:bool) -> void:
 enabled=value;particles.visible=value and not game.loading_state
 particles.speed_scale=1 if value and not game.paused and not game.loading_state else 0
func sample_velocity(position:Vector3) -> Vector3:
 return PROFILE.velocity_at(position,elapsed) if enabled else Vector3.ZERO
func shader_inputs(position:Vector3) -> Dictionary:
 var velocity:=sample_velocity(position)
 var strength:float=velocity.length()/(PROFILE.base_speed+PROFILE.gust_speed)
 return {"wind_direction":PROFILE.direction.normalized(),"wind_velocity":velocity,"wind_strength":strength,"wind_time":elapsed,"wind_displacement":PROFILE.response_amplitude*strength}
func _process(delta:float) -> void:
 if game==null or not is_instance_valid(game.player):return
 var playing:bool=enabled and not game.paused and not game.loading_state
 var visible_now:bool=enabled and not game.loading_state
 if particles.visible!=visible_now:particles.visible=visible_now
 var speed:float=1 if playing else 0
 if particles.speed_scale!=speed:particles.speed_scale=speed
 if not playing:return
 elapsed+=maxf(0,delta)
 var next_observer:Vector3=game.player.global_position
 var old_horizontal:=Vector2(observer.x,observer.z)
 var new_horizontal:=Vector2(next_observer.x,next_observer.z)
 if old_horizontal.distance_squared_to(new_horizontal)>PROFILE.visible_radius*PROFILE.visible_radius:particles.restart(true)
 if observer!=next_observer:observer=next_observer;global_position=observer
 if old_horizontal!=new_horizontal:material.set_shader_parameter("observer",new_horizontal)
 var illumination:float=clampf(maxf(game.main_sun.light_energy/1.2,game.moon_light.light_energy*1.5),0.1,1.0)
 material.set_shader_parameter("visibility_weight",illumination*(0.65+0.35*PROFILE.gust_at(observer,elapsed)))
