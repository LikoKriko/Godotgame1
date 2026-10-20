extends SceneTree
const ROOT="res://assets/characters/prototype_3d/generated/"
const ACTOR="res://scripts/animation/authoring/aren_run_refined_actor.gd"
func _initialize():call_deferred("run")
func run() -> void:
 var args:=OS.get_cmdline_user_args()
 if args.size()!=2 or args[0]!="--output" or DirAccess.dir_exists_absolute(args[1]):push_error("Expected --output NEW-directory");quit(1);return
 var output:String=args[1]
 var profile:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"aren_walk_launch_v1/profile.json"))
 profile.run_refinement={"split_ratio":.9,"duration_scale":.95,"speed_scale":.9/.95,"feet":{}}
 DirAccess.make_dir_recursive_absolute(output)
 var actor=load(ROOT+"aren_walk_launch_v1/aren.tscn").instantiate();root.add_child(actor);actor.set_process(false)
 for style in ["normal","cautious","tired"]:
  actor.set_style(style)
  var old:Animation=actor.library.get_animation(&"run");var info:Dictionary=old.get_meta("cycle").duplicate()
  var maximum:=0.0
  for frame in 720:
   var sample:Dictionary=actor.sampler.sample("run",frame/720.0*old.length)
   maximum=maxf(maximum,absf((actor.native.frame*sample.feet[0]).origin.z-(actor.native.frame*sample.feet[1]).origin.z)*actor.SCALE)
  var p:Dictionary=profile.run_stride[style]
  p.half*=.9;p.source_split_m=maximum;p.split_ratio=.9;p.duration_scale*=.95
  profile.run_refinement.feet[style]={"clearance_scale":{"normal":.85,"cautious":.88,"tired":.9}[style],"plantar_deg":{"normal":18.0,"cautious":14.0,"tired":12.0}[style],"dorsal_deg":{"normal":5.0,"cautious":4.0,"tired":3.0}[style],"rotation_clearance_m":.07}
  var clip:Animation=old.duplicate(true)
  for track in clip.get_track_count():
   for key in clip.track_get_key_count(track):clip.track_set_key_time(track,key,old.track_get_key_time(track,key)*.95)
  clip.length=old.length*.95
  info.duration=clip.length;info.speed_mps*=.9/.95;info.distance_m*=.9;info.half=p.half
  clip.set_meta("cycle",info)
  var path:String=output+"/run_"+style+".res";ResourceSaver.save(clip,path);profile.run_cycles[style]=path
  print(style," source_gap_m=",maximum," cadence_spm=",120/clip.length," speed_mps=",info.speed_mps)
 actor.free()
 for path in [ACTOR,"res://scripts/animation/authoring/aren_run_refined_sampler.gd","res://scripts/animation/authoring/aren_run_foot.gd","res://tools/animation/generate_aren_run_refined.gd",ROOT+"aren_walk_launch_v1/profile.json"]:profile.source_hashes[path]=FileAccess.get_sha256(path)
 for path in profile.run_cycles.values():profile.source_hashes[path]=FileAccess.get_sha256(path)
 var file:=FileAccess.open(output+"/profile.json",FileAccess.WRITE);file.store_string(JSON.stringify(profile,"  "));file.close()
 var scene:="[gd_scene format=3]\n\n[ext_resource type=\"PackedScene\" path=\"%saren_walk_launch_v1/aren.tscn\" id=\"1\"]\n[ext_resource type=\"Script\" path=\"%s\" id=\"2\"]\n\n[node name=\"ArenRunRefined\" instance=ExtResource(\"1\")]\nscript = ExtResource(\"2\")\ntransition_profile = \"%s/profile.json\"\n"%[ROOT,ACTOR,output]
 file=FileAccess.open(output+"/aren.tscn",FileAccess.WRITE);file.store_string(scene);file.close();quit()
