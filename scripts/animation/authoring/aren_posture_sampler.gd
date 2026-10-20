extends "res://scripts/animation/authoring/aren_cycle_sampler.gd"
const Posture=preload("res://scripts/animation/authoring/aren_run_posture.gd")
var native:RefCounted
var steady_angle:=0.0
func sample(name:String,time:float) -> Dictionary:
 var result:=super.sample(name,time)
 return Posture.apply(native,result,steady_angle) if name=="run" else result
