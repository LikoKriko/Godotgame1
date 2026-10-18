extends SceneTree
const Source=preload("res://tools/animation/characters/motion_source.gd")
const Controls=preload("res://scripts/animation/characters/survivor_controls.gd")
const Clips=preload("res://scripts/prototype_3d/survivor_animation.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():
 var key_count:=0;var dense_count:=0
 for name in Source.CLIPS:
  var animation:Animation=Controls.LIBRARY.get_animation(name)
  for track in animation.get_track_count():key_count+=animation.track_get_key_count(track);dense_count+=601
  # Offset samples inspect points between the author's 600 Hz samples too.
  for frame in 1201:
   var phase:float=(frame+.37)/1202.0
   var expected:=Source.sample(name,phase);var actual:=Controls.sample(name,phase)
   for control in expected:
    var angular:=String(control) in ["chest","pelvis","spine","shoulders","arms","angles","curl","wind_axis","hit_axis","foot_angles_l","foot_angles_r","effort","timing","recovery"]
    var error:float=expected[control].distance_to(actual[control])
    require(error<(.00065 if angular else .022),"Reduced control stays within positional/angular error budget: %s %s %.6f"%[name,control,error])
  var mutable:=Controls.sample(name,.42);mutable.clear()
  require(not Controls.sample(name,.42).is_empty(),"A caller cannot mutate the shared control cache")
  if name in [&"walk",&"run"]:
   var before:=Controls.sample(name,0);var after:=Controls.sample(name,1)
   for control in before:require(before[control].distance_to(after[control])<.00001,"Loop endpoints match")
 require(key_count<dense_count*.20,"Key reduction retains fewer than 20 percent of dense samples")
 for state in [&"walk",&"run"]:
  var a:=Clips.sample(&"",state,.02,.02,Vector3.BACK)
  var b:=Clips.sample(&"",state,.20,.20,Vector3.BACK)
  var raw_a:Vector3=Controls.sample(state,.02).foot_l
  var raw_b:Vector3=Controls.sample(state,.20).foot_l
  var speed:float=(raw_a.x-raw_b.x)*Clips.GAIT_STRIDE_LENGTH*(1.75/64)/(.18*Clips.duration(state))
  require(a.legs[0].end.y>=2.09 and b.legs[0].end.y>=2.09,"Upright reach correction keeps the support sole above ground")
  require(absf(speed-(2.0 if state==&"walk" else 3.2)*Clips.GAIT_STRIDE_LENGTH)<.035,"Authoring preserves the reference stride before the upright anatomical reach limit: %s %.4f"%[state,speed])
 # Heel contact and toe release must not introduce a vertical/ankle snap.
 for running in [false,true]:
  var support:=.40 if running else .60
  for contact in [0.0,support]:
   var h:=.0001
   var before:=Source.foot(contact-h,running)
   var at:=Source.foot(contact,running)
   var after:=Source.foot(contact+h,running)
   require(absf((at.y-before.y)/h)<.05 and absf((after.y-at.y)/h)<.05,"Foot approaches/leaves contact with a soft vertical velocity")
   require(absf((at.z-before.z)/h)<.01 and absf((after.z-at.z)/h)<.01,"Ankle roll has no sudden heel/toe contact rotation")
  var highest:=Source.foot(support+(1-support)*.5,running)
  require(absf(highest.y-(8.2 if running else 4.8))<.001,"Soft landing preserves the original peak foot clearance")
 print("%s: %d reduced-curve, cache, loop and gait-distance checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
