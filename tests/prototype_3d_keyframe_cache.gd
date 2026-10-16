extends SceneTree
const Motion=preload("res://scripts/prototype_3d/young_pose.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var peak:=0.0
 for state:StringName in Motion.CACHED_STATES:
  for i in 1001:
   var phase:float=i/1000.0
   var exact:Dictionary=Motion.sample_exact(state,phase)
   var cached:Dictionary=Motion.sample(state,phase)
   require(cached.state==state and cached.phase==phase,"Keyframes preserve the state and action clock")
   for kind in ["legs","arms"]:
    for side in 2:
     var chain:Dictionary=cached[kind][side]
     require(absf(chain.root.distance_to(chain.joint)-(Motion.LEG_A if kind=="legs" else Motion.ARM_A))<.00001,"Keyframes retain fixed upper bone length")
     require(absf(chain.joint.distance_to(chain.end)-(Motion.LEG_B if kind=="legs" else Motion.ARM_B))<.00001,"Keyframes retain fixed lower bone length")
     for point in ["root","joint","end"]:
      var error:float=chain[point].distance_to(exact[kind][side][point]);peak=maxf(peak,error)
      require(error<.0015,"Interpolated joints stay within 0.0015 authoring units of the authored motion")
  require(Motion.clip_keys[state].times.size()<2048,"Adaptive keyframes remain bounded")
 for state:StringName in Motion.STATES:
  if state in Motion.CACHED_STATES:continue
  for phase in [0.0,.137,.5,.823,1.0]:
   for left in [false,true]:require(Motion.sample(state,phase,left)==Motion.sample_exact(state,phase,left),"Attacks, transitions, falls and uncached poses remain exact")
 var actor=load("res://scripts/prototype_3d/young_model.gd").new();root.add_child(actor)
 for state:StringName in Motion.STATES:
  for phase in [.117,.481,.759]:
   Motion.use_keyframes=false;actor.use_bind_frame_cache=false;actor.animate(state,phase)
   var original:Array=actor.posed.duplicate()
   actor.use_bind_frame_cache=true;actor.animate(state,phase)
   require(actor.posed==original,"Reference-frame caching is numerically identical for every animation")
 Motion.use_keyframes=true
 var first:Dictionary=Motion.sample(&"walk",.117);first.arms[0].end=Vector3.INF
 require(Motion.sample(&"walk",.117).arms[0].end.is_finite(),"Actor changes cannot corrupt shared clip keys")
 actor.free()
 print("%s: %d keyframe, anatomy, state and reference-frame checks; maximum joint error %.8f authoring units"%["PASS" if failures==0 else "FAIL",checks,peak]);quit(1 if failures else 0)
