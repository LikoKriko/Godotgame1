extends "res://scripts/animation/authoring/aren_walk_upper_actor.gd"
const ShortSampler=preload("res://scripts/animation/authoring/aren_short_run_sampler.gd")
func set_style(value:String) -> void:
 super.set_style(value)
 var shared:=AnimationLibrary.new()
 for name in library.get_animation_list():shared.add_animation(name,load(profile.run_cycles[style]) if name==&"run" else library.get_animation(name))
 library=shared;player.remove_animation_library(&"aren");player.add_animation_library(&"aren",library)
 sampler=ShortSampler.new();sampler.native=native
 sampler.steady_angle=deg_to_rad(float(profile.posture[style].steady_deg))
 sampler.arm_phase=profile.walk_arm_phase;sampler.body_parameters=profile.walk_torso[style]
 sampler.run_parameters=profile.run_stride[style]
 sampler.configure(library,native.skeleton);reset_motion()
