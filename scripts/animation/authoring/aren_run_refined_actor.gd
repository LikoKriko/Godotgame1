extends "res://scripts/animation/authoring/aren_walk_launch_actor.gd"
const RefinedSampler=preload("res://scripts/animation/authoring/aren_run_refined_sampler.gd")
func set_style(value:String) -> void:
 super.set_style(value)
 sampler=RefinedSampler.new();sampler.native=native
 sampler.steady_angle=deg_to_rad(float(profile.posture[style].steady_deg))
 sampler.arm_phase=profile.walk_arm_phase;sampler.body_parameters=profile.walk_torso[style]
 sampler.run_parameters=profile.run_stride[style]
 sampler.foot_parameters=profile.run_refinement.feet[style]
 sampler.configure(library,native.skeleton);reset_motion()
