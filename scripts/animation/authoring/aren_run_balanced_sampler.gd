extends "res://scripts/animation/authoring/aren_run_refined_sampler.gd"
const LeftFoot=preload("res://scripts/animation/authoring/aren_run_left_foot.gd")
var left_phase_offset:=.5
func sample(name:String,time:float) -> Dictionary:
 var result:=super.sample(name,time)
 if name!="run" or foot_parameters.is_empty():return result
 var phase:float=fposmod(time/clips.run.length+left_phase_offset,1)
 result=LeftFoot.apply_left(native,result,phase,run_parameters.support,foot_parameters)
 var ids:Array=native.legs[1].ids;var hip:Vector3=native.posed[ids[0]].origin
 var axis:Vector3=(native.posed[ids[2]].origin-hip).normalized()
 var radial:Vector3=native.posed[ids[1]].origin-hip;radial-=axis*radial.dot(axis)
 knee_poles.run[1]=radial.normalized()
 return result
