extends "res://scripts/animation/authoring/aren_coordination_actor.gd"
const UpperSampler=preload("res://scripts/animation/authoring/aren_walk_upper_sampler.gd")
func set_style(value:String) -> void:
 super.set_style(value)
 sampler=UpperSampler.new();sampler.native=native
 sampler.steady_angle=deg_to_rad(float(profile.posture[style].steady_deg))
 sampler.arm_phase=profile.walk_arm_phase;sampler.body_parameters=profile.walk_torso[style]
 sampler.configure(library,native.skeleton);reset_motion()
