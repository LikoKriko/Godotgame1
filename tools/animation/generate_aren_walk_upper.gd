extends SceneTree
## Versioned walking torso parameters over approved shared cycle libraries.
const ROOT="res://assets/characters/prototype_3d/generated/"
const ACTOR="res://scripts/animation/authoring/aren_walk_upper_actor.gd"
func _initialize():call_deferred("run")
func run() -> void:
 var args:=OS.get_cmdline_user_args()
 if args.size()!=2 or args[0]!="--output" or DirAccess.dir_exists_absolute(args[1]):push_error("Expected --output NEW-directory");quit(1);return
 var output:String=args[1]
 var profile:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"aren_coordination_v1/profile.json"))
 profile.walk_torso={}
 for state in ["normal","cautious","tired"]:
  var amplitude:Vector3={"normal":Vector3(.85,4.20,1.50),"cautious":Vector3(.60,3.20,1.00),"tired":Vector3(.75,3.60,1.30)}[state]
  profile.walk_torso[state]={"pitch_deg":amplitude.x,"yaw_deg":amplitude.y,"roll_deg":amplitude.z,"spine_shares":[.28,.63,1.0],"pelvis_retention":.90,"neck_follow":.45,"head_follow":.20}
 for path in [ACTOR,"res://scripts/animation/authoring/aren_walk_upper_sampler.gd","res://scripts/animation/authoring/aren_walk_upper_body.gd","res://tools/animation/generate_aren_walk_upper.gd",ROOT+"aren_coordination_v1/profile.json"]:profile.source_hashes[path]=FileAccess.get_sha256(path)
 DirAccess.make_dir_recursive_absolute(output)
 var file:=FileAccess.open(output+"/profile.json",FileAccess.WRITE);file.store_string(JSON.stringify(profile,"  "));file.close()
 var scene:="[gd_scene format=3]\n\n[ext_resource type=\"PackedScene\" path=\"%saren_coordination_v1/aren.tscn\" id=\"1\"]\n[ext_resource type=\"Script\" path=\"%s\" id=\"2\"]\n\n[node name=\"ArenWalkUpper\" instance=ExtResource(\"1\")]\nscript = ExtResource(\"2\")\ntransition_profile = \"%s/profile.json\"\n"%[ROOT,ACTOR,output]
 file=FileAccess.open(output+"/aren.tscn",FileAccess.WRITE);file.store_string(scene);file.close()
 print("PASS: versioned walking torso profile, approved sources preserved");quit()
