extends "res://scripts/animation/authoring/aren_walk_upper_sampler.gd"
const ShortRun=preload("res://scripts/animation/authoring/aren_short_run.gd")
var run_parameters:Dictionary={}
func sample(name:String,time:float) -> Dictionary:
 var result:=super.sample(name,time)
 if name!="run":return result
 result=ShortRun.apply(native,result,fposmod(time/clips.run.length,1),run_parameters)
 var poles:Array[Vector3]=[]
 for leg in native.legs:
  var ids:Array=leg.ids;var hip:Vector3=native.posed[ids[0]].origin
  var axis:Vector3=(native.posed[ids[2]].origin-hip).normalized()
  var radial:Vector3=native.posed[ids[1]].origin-hip;radial-=axis*radial.dot(axis)
  poles.append(radial.normalized())
 knee_poles.run=poles
 return result
