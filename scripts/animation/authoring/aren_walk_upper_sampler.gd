extends "res://scripts/animation/authoring/aren_coordination_sampler.gd"
const UpperBody=preload("res://scripts/animation/authoring/aren_walk_upper_body.gd")
const TorsoFlow=preload("res://scripts/animation/authoring/aren_torso_flow.gd")
var body_parameters:Dictionary={}
var walk_reference:Dictionary={}
func configure(library:AnimationLibrary,rig:Skeleton3D) -> void:
 super.configure(library,rig)
 var frames:Array=[]
 for frame in 61:
  var sampled:=super.sample("walk",frame/60.0*clips.walk.length)
  UpperBody.restore_sample(native,sampled);frames.append(TorsoFlow.capture(native))
 walk_reference=TorsoFlow.summarize(frames)
func sample(name:String,time:float) -> Dictionary:
 var result:=super.sample(name,time)
 return UpperBody.apply(native,result,fposmod(time/clips.walk.length,1),body_parameters,walk_reference) if name=="walk" else result
