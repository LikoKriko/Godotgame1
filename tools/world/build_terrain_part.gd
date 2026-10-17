extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
 var args:=OS.get_cmdline_user_args();var options:Dictionary={}
 if args.size()%2!=0:push_error("Use --recipe PATH --terrain PATH --output NEW.tscn");quit(1);return
 for i in range(0,args.size(),2):
  if args[i] not in ["--recipe","--terrain","--output"] or options.has(args[i]):push_error("Unknown/repeated option");quit(1);return
  options[args[i]]=args[i+1]
 if not options.has("--recipe") or not options.has("--terrain") or not options.has("--output"):push_error("Recipe, terrain profile and output are required");quit(1);return
 var output:String=options["--output"]
 if FileAccess.file_exists(output) or output.get_extension()!="tscn":push_error("Output must be a new .tscn file");quit(1);return
 var builder=preload("res://scripts/world/terrain/terrain_module_builder.gd").new()
 var part:Node3D=builder.build(load(options["--recipe"]),load(options["--terrain"]),preload("res://scripts/prototype_3d/story_zone_catalog.gd").new(),Rect2(-3200,-3200,6400,6400))
 if part==null:push_error(str(builder.errors));quit(1);return
 var scene:=PackedScene.new();var error:=scene.pack(part)
 if error==OK:error=ResourceSaver.save(scene,output)
 part.free();print("Terrain part: ",output);quit(0 if error==OK else 1)
