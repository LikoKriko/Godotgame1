extends SceneTree
const ROOT="res://assets/characters/prototype_3d/generated/"
const ACTOR="res://scripts/animation/authoring/aren_short_run_actor.gd"
const FootPath=preload("res://scripts/animation/authoring/aren_short_run.gd")
func _initialize():call_deferred("run")
func run() -> void:
 var args:=OS.get_cmdline_user_args()
 if args.size()!=2 or args[0]!="--output" or DirAccess.dir_exists_absolute(args[1]):push_error("Expected --output NEW-directory");quit(1);return
 var output:String=args[1]
 var profile:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"aren_walk_upper_v1/profile.json"))
 profile.run_stride={};profile.run_cycles={}
 DirAccess.make_dir_recursive_absolute(output)
 var actor=load(ROOT+"aren_walk_upper_v1/aren.tscn").instantiate();root.add_child(actor);actor.set_process(false)
 for style in ["normal","cautious","tired"]:
  actor.set_style(style)
  var old:Animation=actor.library.get_animation(&"run");var info:Dictionary=old.get_meta("cycle").duplicate()
  var maximum:=0.0
  for frame in 960:
   var sampled:Dictionary=actor.sampler.sample("run",frame/960.0*old.length)
   var a:Transform3D=actor.native.frame*sampled.feet[0];var b:Transform3D=actor.native.frame*sampled.feet[1]
   maximum=maxf(maximum,absf(a.origin.z-b.origin.z)*FootPath.SCALE)
  var parameters:Dictionary=old.get_meta("parameters")
  var p:Dictionary={"duration_scale":.9,"split_ratio":.8,"source_split_m":maximum,"source_support":info.support,"support":info.support/.9,"flight_rise_m":.025*parameters.get("run_body_motion",1.0)*parameters.get("run_flow",0.0),"half":info.half,"lift":4.5*(1-parameters.fatigue*.18)*parameters.get("run_lift",1.0),"heel_recovery_m":{"normal":.18,"cautious":.14,"tired":.13}[style],"release":.1,"landing":.14}
  var low:=.001;var high:=.1
  for iteration in 24:
   p.release=(low+high)*.5;p.landing=p.release*1.4
   if FootPath.maximum_split(p)>maximum*p.split_ratio:high=p.release
   else:low=p.release
  profile.run_stride[style]=p
  var clip:Animation=old.duplicate(true)
  for track in clip.get_track_count():
   for key in clip.track_get_key_count(track):clip.track_set_key_time(track,key,old.track_get_key_time(track,key)*p.duration_scale)
  clip.length=old.length*p.duration_scale
  info.duration=clip.length;info.distance_m=info.speed_mps*clip.length;info.support=p.support
  clip.set_meta("cycle",info)
  var path:String=output+"/run_"+style+".res";ResourceSaver.save(clip,path);profile.run_cycles[style]=path
  print(style," split_m=",maximum," target_m=",FootPath.maximum_split(p)," cadence_spm=",120/clip.length," support_s=",info.support*clip.length)
 actor.free()
 for path in [ACTOR,"res://scripts/animation/authoring/aren_short_run_sampler.gd","res://scripts/animation/authoring/aren_short_run.gd","res://tools/animation/generate_aren_short_run.gd",ROOT+"aren_walk_upper_v1/profile.json"]:profile.source_hashes[path]=FileAccess.get_sha256(path)
 for path in profile.run_cycles.values():profile.source_hashes[path]=FileAccess.get_sha256(path)
 var file:=FileAccess.open(output+"/profile.json",FileAccess.WRITE);file.store_string(JSON.stringify(profile,"  "));file.close()
 var scene:="[gd_scene format=3]\n\n[ext_resource type=\"PackedScene\" path=\"%saren_walk_upper_v1/aren.tscn\" id=\"1\"]\n[ext_resource type=\"Script\" path=\"%s\" id=\"2\"]\n\n[node name=\"ArenShortRun\" instance=ExtResource(\"1\")]\nscript = ExtResource(\"2\")\ntransition_profile = \"%s/profile.json\"\n"%[ROOT,ACTOR,output]
 file=FileAccess.open(output+"/aren.tscn",FileAccess.WRITE);file.store_string(scene);file.close();quit()
