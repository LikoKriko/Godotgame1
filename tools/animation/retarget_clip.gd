extends SceneTree
## Writes a separate clip; source scenes, meshes and animation libraries are untouched.
func _initialize():call_deferred("run")
func fail(message:String) -> void:
 push_error(message);quit(1)
func run() -> void:
 var args:=OS.get_cmdline_user_args();var options:Dictionary={}
 if args.size()%2!=0:fail("Use --source-scene PATH --target-scene PATH --source-profile PATH --target-profile PATH --animation PATH --output PATH; optional --clip NAME");return
 for i in range(0,args.size(),2):
  if options.has(args[i]):fail("Repeated option: "+args[i]);return
  options[args[i]]=args[i+1]
 for option in ["--source-scene","--target-scene","--source-profile","--target-profile","--animation","--output"]:
  if not options.has(option):fail("Missing "+option);return
 for option in options:
  if option not in ["--source-scene","--target-scene","--source-profile","--target-profile","--animation","--output","--clip"]:fail("Unknown option: "+option);return
 var output:String=options["--output"]
 if FileAccess.file_exists(output) or output.get_extension() not in ["res","tres"]:fail("Output must be a new .res or .tres file");return
 var source_scene=load(options["--source-scene"]);var target_scene=load(options["--target-scene"])
 var source_profile=load(options["--source-profile"]);var target_profile=load(options["--target-profile"])
 var clip=load(options["--animation"])
 if clip is AnimationLibrary:clip=clip.get_animation(options.get("--clip",&""))
 if not source_scene is PackedScene or not target_scene is PackedScene or not clip is Animation:fail("Expected two scenes and an Animation, or an AnimationLibrary with --clip");return
 var a:Node=source_scene.instantiate();var b:Node=target_scene.instantiate();root.add_child(a);root.add_child(b)
 var source_rigs:=a.find_children("*","Skeleton3D",true,false);var target_rigs:=b.find_children("*","Skeleton3D",true,false)
 if a is Skeleton3D:source_rigs.push_front(a)
 if b is Skeleton3D:target_rigs.push_front(b)
 if source_rigs.size()!=1 or target_rigs.size()!=1:a.free();b.free();fail("Each scene must contain exactly one skeleton in its reference pose");return
 var adapter=preload("res://scripts/animation/shared/animation_retargeter.gd").new()
 if not adapter.configure(source_rigs[0],target_rigs[0],source_profile,target_profile):a.free();b.free();fail(str(adapter.errors));return
 # Track roots can vary across scenes; identify the input skeleton path from a mapped bone.
 var source_path:=NodePath()
 for track in clip.get_track_count():
  var path:NodePath=clip.track_get_path(track)
  if path.get_subname_count()==1 and adapter.mapping.has(path.get_subname(0)):source_path=NodePath(path.get_concatenated_names());break
 if source_path.is_empty():a.free();b.free();fail("Input clip has no mapped bone tracks");return
 var result:Animation=adapter.retarget_animation(clip,source_path,b.get_path_to(target_rigs[0]))
 if result==null or result.get_track_count()==0:a.free();b.free();fail("No bone rotations were adapted");return
 var error:=ResourceSaver.save(result,output)
 print("Adapted ",result.get_track_count()," tracks; skipped ",adapter.skipped_tracks.size()," non-transferable tracks. Output: ",output)
 a.free();b.free();quit(0 if error==OK else 1)
