extends SceneTree
## Version a coordinated run/launch profile, reusing approved cycles and controls.
const ROOT="res://assets/characters/prototype_3d/generated/"
const ACTOR="res://scripts/animation/authoring/aren_run_launch_actor.gd"
func _initialize():call_deferred("run")
func run() -> void:
 var args:=OS.get_cmdline_user_args()
 if args.size()!=2 or args[0]!="--output" or DirAccess.dir_exists_absolute(args[1]):push_error("Expected --output NEW-directory");quit(1);return
 var output:String=args[1]
 var profile:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"aren_transitions_v1/profile.json"))
 profile.posture={"normal":{"steady_deg":3.0,"launch_deg":7.0,"recovery_steps":2.5},"cautious":{"steady_deg":2.0,"launch_deg":4.0,"recovery_steps":3.0},"tired":{"steady_deg":1.5,"launch_deg":3.0,"recovery_steps":3.0}}
 for path in [ACTOR,"res://scripts/animation/authoring/aren_run_posture.gd","res://scripts/animation/authoring/aren_posture_sampler.gd","res://tools/animation/generate_aren_run_posture.gd",ROOT+"aren_transitions_v1/profile.json",profile.controls]:profile.source_hashes[path]=FileAccess.get_sha256(path)
 DirAccess.make_dir_recursive_absolute(output)
 var file:=FileAccess.open(output+"/profile.json",FileAccess.WRITE);file.store_string(JSON.stringify(profile,"  "));file.close()
 var text:="[gd_scene format=3]\n\n[ext_resource type=\"PackedScene\" path=\"%saren_run_idle_v3/aren.tscn\" id=\"1\"]\n[ext_resource type=\"Script\" path=\"%s\" id=\"2\"]\n\n[node name=\"ArenRunPosture\" instance=ExtResource(\"1\")]\nscript = ExtResource(\"2\")\ntransition_profile = \"%s/profile.json\"\n"%[ROOT,ACTOR,output]
 file=FileAccess.open(output+"/aren.tscn",FileAccess.WRITE);file.store_string(text);file.close()
 print("PASS: versioned posture profile, original cycles and six transition controls referenced without copying");quit()
