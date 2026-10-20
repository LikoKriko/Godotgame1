extends SceneTree
const ROOT="res://assets/characters/prototype_3d/generated/"
const ACTOR="res://scripts/animation/authoring/aren_walk_launch_actor.gd"
func _initialize():call_deferred("run")
func run() -> void:
 var args:=OS.get_cmdline_user_args()
 if args.size()!=2 or args[0]!="--output" or DirAccess.dir_exists_absolute(args[1]):push_error("Expected --output NEW-directory");quit(1);return
 var output:String=args[1]
 var profile:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"aren_short_run_v1/profile.json"))
 for state in profile.walk_torso:profile.walk_torso[state].pitch_deg*=.35
 profile.arm_prepare={"states":{"normal":1.0,"cautious":.85,"tired":.70},"lead_forward_deg":8.0,"lag_forward_deg":3.0,"lead_fold_deg":32.0,"lag_fold_deg":18.0,"lead_onset":.02,"lag_onset":.65,"recovery_steps":2.0,"response":20.0,"walk_gain":.35}
 for path in [ACTOR,"res://scripts/animation/authoring/aren_arm_preparation.gd","res://tools/animation/generate_aren_walk_launch.gd",ROOT+"aren_short_run_v1/profile.json"]:profile.source_hashes[path]=FileAccess.get_sha256(path)
 DirAccess.make_dir_recursive_absolute(output)
 var file:=FileAccess.open(output+"/profile.json",FileAccess.WRITE);file.store_string(JSON.stringify(profile,"  "));file.close()
 var scene:="[gd_scene format=3]\n\n[ext_resource type=\"PackedScene\" path=\"%saren_short_run_v1/aren.tscn\" id=\"1\"]\n[ext_resource type=\"Script\" path=\"%s\" id=\"2\"]\n\n[node name=\"ArenWalkLaunch\" instance=ExtResource(\"1\")]\nscript = ExtResource(\"2\")\ntransition_profile = \"%s/profile.json\"\n"%[ROOT,ACTOR,output]
 file=FileAccess.open(output+"/aren.tscn",FileAccess.WRITE);file.store_string(scene);file.close();print("PASS: moderated walking pitch and asymmetric arm preparation profile");quit()
