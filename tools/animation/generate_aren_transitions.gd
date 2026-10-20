extends SceneTree
## Generate six small shared control clips, referencing approved cycle libraries.
const ROOT="res://assets/characters/prototype_3d/generated/"
const ACTOR="res://scripts/animation/authoring/aren_transition_actor.gd"
func _initialize():call_deferred("run")
func run() -> void:
 var args:=OS.get_cmdline_user_args()
 if args.size()!=2 or args[0]!="--output":push_error("Expected --output NEW-directory");quit(1);return
 var output:String=args[1]
 if DirAccess.dir_exists_absolute(output):push_error("Refusing to overwrite output");quit(1);return
 var styles:Dictionary={"normal":{"scene":ROOT+"aren_run_idle_v3/aren.tscn","timing":1.0,"weight_shift_m":.012},"cautious":{"scene":ROOT+"aren_cautious_v1/aren.tscn","timing":1.25,"weight_shift_m":.009},"tired":{"scene":ROOT+"aren_tired_v1/aren.tscn","timing":1.4,"weight_shift_m":.010}}
 var recipes:Dictionary={
 "idle_to_walk":{"from":"idle","to":"walk","duration":1.15,"anticipation":.17},
 "idle_to_run":{"from":"idle","to":"run","duration":1.85,"anticipation":.12},
 "walk_to_run":{"from":"walk","to":"run","duration":1.10,"anticipation":.08},
 "run_to_walk":{"from":"run","to":"walk","duration":1.15,"anticipation":.05},
 "walk_to_idle":{"from":"walk","to":"idle","duration":1.10,"anticipation":.06},
 "run_to_idle":{"from":"run","to":"idle","duration":1.75,"anticipation":.05}}
 var hashes:Dictionary={}
 for state in styles:
  var path:String=styles[state].scene
  var scene:Node3D=load(path).instantiate()
  for clip in ["idle","walk","run"]:
   if not scene.library.has_animation(StringName(clip)):push_error("Missing approved cycle");quit(1);return
  hashes[path]=FileAccess.get_sha256(path);hashes[scene.library.resource_path]=FileAccess.get_sha256(scene.library.resource_path);scene.free()
 for path in [ACTOR,"res://scripts/animation/authoring/aren_cycle_sampler.gd","res://scripts/animation/authoring/aren_torso_flow.gd","res://scripts/animation/characters/native_survivor.gd","res://scripts/continuous_body_pose.gd","res://tools/animation/generate_aren_transitions.gd"]:hashes[path]=FileAccess.get_sha256(path)
 var controls:=AnimationLibrary.new()
 for name in recipes:
  var animation:=Animation.new();animation.length=1;animation.loop_mode=Animation.LOOP_NONE
  for property in ["progress","anticipation"]:
   var track:=animation.add_track(Animation.TYPE_VALUE);animation.track_set_path(track,NodePath("Controls:"+property))
  for frame in 241:
   var t:=frame/240.0;var hold:float=recipes[name].anticipation
   var u:=clampf((t-hold)/(1-hold),0,1)
   animation.track_insert_key(0,t,u*u*u*(u*(u*6-15)+10))
   animation.track_insert_key(1,t,pow(sin(PI*clampf(t/hold,0,1)),2) if t<hold else 0.0)
  controls.add_animation(StringName(name),animation)
 DirAccess.make_dir_recursive_absolute(output)
 if ResourceSaver.save(controls,output+"/controls.res",ResourceSaver.FLAG_COMPRESS)!=OK:quit(1);return
 var profile:Dictionary={"schema":1,"loading_m":.028,"controls":output+"/controls.res","recipes":recipes,"styles":styles,"source_hashes":hashes,"surface":"flat","direction":"forward"}
 var file:=FileAccess.open(output+"/profile.json",FileAccess.WRITE);file.store_string(JSON.stringify(profile,"  "));file.close()
 var scene_text:="[gd_scene format=3]\n\n[ext_resource type=\"PackedScene\" path=\"%s\" id=\"1\"]\n[ext_resource type=\"Script\" path=\"%s\" id=\"2\"]\n\n[node name=\"ArenTransitions\" instance=ExtResource(\"1\")]\nscript = ExtResource(\"2\")\ntransition_profile = \"%s/profile.json\"\n"%[styles.normal.scene,ACTOR,output]
 file=FileAccess.open(output+"/aren.tscn",FileAccess.WRITE);file.store_string(scene_text);file.close()
 print("PASS: six transition control clips, three referenced styles, no cycle duplication: ",output);quit()
