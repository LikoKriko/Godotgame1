extends SceneTree
## Median of five alternating 3000-call samples; preparation is measured separately.
const Motion=preload("res://scripts/prototype_3d/young_pose.gd")
func _initialize():call_deferred("run")
func run():
 var actor=load("res://scripts/prototype_3d/young_model.gd").new();root.add_child(actor)
 var report:Dictionary={};var cold:Dictionary={}
 for state:StringName in Motion.CACHED_STATES:
  var ticks:=Time.get_ticks_usec();Motion.prepare_clip(state)
  cold[state]={"ms":(Time.get_ticks_usec()-ticks)/1000.0,"keys":Motion.clip_keys[state].times.size()}
 for delta in [0.0,1.0/60]:
  var rows:Dictionary={}
  for state:StringName in Motion.CACHED_STATES+[&"idle",&"attack"]:
   var samples:Dictionary={false:[],true:[]}
   for repeat in 5:
    for cached in ([false,true] if repeat%2==0 else [true,false]):
     Motion.use_keyframes=cached;actor.use_bind_frame_cache=cached;actor.animate(state,.17,true,delta)
     var ticks:=Time.get_ticks_usec()
     for i in 3000:actor.animate(state,fposmod(i*.01371,1),true,delta)
     samples[cached].append((Time.get_ticks_usec()-ticks)/3000.0)
   samples[false].sort();samples[true].sort()
   rows[state]={"before_us":samples[false][2],"after_us":samples[true][2],"reduction_percent":100*(1-samples[true][2]/samples[false][2])}
  report[str(delta)]=rows
 Motion.use_keyframes=true
 report.cold_preparation=cold
 var args:=OS.get_cmdline_user_args();var path:String=args[0] if not args.is_empty() else "res://work/enemy-animation-timing.json"
 var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print(report);actor.free();quit()
