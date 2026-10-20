extends "res://scripts/animation/authoring/aren_run_balanced_sampler.gd"
## Exact per-evaluation reuse for the launch chest pass and final pose pass.
## Samples at different times are never shared or quantized.
var source:RefCounted
var reuse:=false
var samples:Dictionary={}
const PARAMETERS=["native","steady_angle","arm_phase","body_parameters","run_parameters","foot_parameters","left_phase_offset"]
const BINDINGS=["clips","tracks","skeleton","foot_chains","arm_bones","knee_poles","walk_reference"]

func _init(original:RefCounted) -> void:
 source=original
 sync_source()

func sync_source() -> void:
 for key in PARAMETERS+BINDINGS:set(key,source.get(key))

func configure(library:AnimationLibrary,rig:Skeleton3D) -> void:
 for key in PARAMETERS:source.set(key,get(key))
 source.configure(library,rig)
 sync_source()
 samples.clear()

func begin_evaluation(enabled:bool) -> void:
 reuse=enabled;samples.clear()

func end_evaluation() -> void:
 reuse=false;samples.clear()

func sample(name:String,time:float) -> Dictionary:
 if not reuse:return source.sample(name,time)
 if samples.has(name) and samples[name].time==time:
  var cached:Dictionary=samples[name]
  # Procedural walk/run sampling also leaves the native rig posed. Restore
  # that side effect, and only this clip's poles, just as a fresh call does.
  if name!="idle":native.posed.assign(cached.posed)
  knee_poles[name]=cached.poles.duplicate()
  return cached.result
 var result:Dictionary=source.sample(name,time)
 samples[name]={"time":time,"result":result,"poles":knee_poles[name].duplicate(),"posed":native.posed.duplicate() if name!="idle" else []}
 return result
