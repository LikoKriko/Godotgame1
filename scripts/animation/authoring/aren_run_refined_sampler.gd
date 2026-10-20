extends "res://scripts/animation/authoring/aren_short_run_sampler.gd"
const Foot=preload("res://scripts/animation/authoring/aren_run_foot.gd")
var foot_parameters:Dictionary={}
func sample(name:String,time:float) -> Dictionary:
 var result:=super.sample(name,time)
 if name!="run" or foot_parameters.is_empty():return result
 result=Foot.apply(native,result,fposmod(time/clips.run.length,1),run_parameters.support,foot_parameters)
 var ids:Array=native.legs[0].ids;var hip:Vector3=native.posed[ids[0]].origin
 var axis:Vector3=(native.posed[ids[2]].origin-hip).normalized()
 var radial:Vector3=native.posed[ids[1]].origin-hip;radial-=axis*radial.dot(axis)
 knee_poles.run[0]=radial.normalized()
 return result
