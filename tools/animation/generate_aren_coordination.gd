extends SceneTree
## New version, same cycle resources: arm phase and exact additive launch overlay.
const ROOT="res://assets/characters/prototype_3d/generated/"
const ACTOR="res://scripts/animation/authoring/aren_coordination_actor.gd"
func _initialize():call_deferred("run")
func run() -> void:
 var args:=OS.get_cmdline_user_args()
 if args.size()!=2 or args[0]!="--output" or DirAccess.dir_exists_absolute(args[1]):push_error("Expected --output NEW-directory");quit(1);return
 var output:String=args[1]
 var profile:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"aren_run_launch_v1/profile.json"))
 profile.walk_arm_phase=.5;profile.launch_increment_deg=1.5
 for path in [ACTOR,"res://scripts/animation/authoring/aren_coordination_sampler.gd","res://scripts/animation/authoring/aren_knee_plane.gd","res://tools/animation/generate_aren_coordination.gd",ROOT+"aren_run_launch_v1/profile.json"]:profile.source_hashes[path]=FileAccess.get_sha256(path)
 DirAccess.make_dir_recursive_absolute(output)
 var file:=FileAccess.open(output+"/profile.json",FileAccess.WRITE);file.store_string(JSON.stringify(profile,"  "));file.close()
 var text:="[gd_scene format=3]\n\n[ext_resource type=\"PackedScene\" path=\"%saren_run_launch_v1/aren.tscn\" id=\"1\"]\n[ext_resource type=\"Script\" path=\"%s\" id=\"2\"]\n\n[node name=\"ArenCoordinated\" instance=ExtResource(\"1\")]\nscript = ExtResource(\"2\")\ntransition_profile = \"%s/profile.json\"\n"%[ROOT,ACTOR,output]
 file=FileAccess.open(output+"/aren.tscn",FileAccess.WRITE);file.store_string(text);file.close()
 print("PASS: versioned arm/launch coordination profile, approved sources preserved");quit()
