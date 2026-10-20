extends SceneTree
## --output new-directory [--preset natural|tired|cautious] [--request "..."]
## [--parameters '{"stride":0.8}'] [--evidence /absolute/local-directory]
const Generator=preload("res://scripts/animation/authoring/aren_generator.gd")
const Request=preload("res://scripts/animation/authoring/aren_request.gd")
const Validator=preload("res://scripts/animation/authoring/aren_validator.gd")
const Playback=preload("res://scripts/animation/authoring/aren_playback.gd")
func _initialize():call_deferred("run")
func fail(message:String) -> void:
 push_error(message);quit(1)
func run() -> void:
 var args:=OS.get_cmdline_user_args();var options:Dictionary={}
 if args.size()%2!=0:fail("Expected --option value pairs");return
 for i in range(0,args.size(),2):
  if args[i] not in ["--output","--preset","--request","--parameters","--evidence"] or options.has(args[i]):fail("Unknown or duplicate option");return
  options[args[i]]=args[i+1]
 if not options.has("--output"):fail("A new output directory is required");return
 var output:String=options["--output"]
 if DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output):fail("Refusing to overwrite output: "+output);return
 var request:Dictionary=Request.parse(options["--request"]) if options.has("--request") else Request.parameters(options.get("--preset","natural"))
 if not request.ok:fail(request.error);return
 if options.has("--parameters"):
  var overrides=JSON.parse_string(options["--parameters"])
  if not overrides is Dictionary:fail("Parameters must be a JSON object");return
  var merged:Dictionary=request.values.duplicate();merged.merge(overrides,true)
  request=Request.parameters(request.preset,merged)
  if not request.ok:fail(request.error);return
 var generator:=Generator.new()
 if not generator.configure(root):fail("Cannot bind Aren's 66-bone rig");return
 var scene:=Node3D.new();scene.name="ArenGenerated";scene.set_process(false)
 root.add_child(scene)
 # _ready requires a library; build with processing off and initialize after packing.
 var model:Node3D=load(Generator.MODEL).instantiate();model.name="NativeModel";scene.add_child(model);model.owner=scene
 var skeleton:Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
 var mesh:MeshInstance3D=model.find_children("*","MeshInstance3D",true,false)[0]
 var skeleton_path:=scene.get_path_to(skeleton);var mesh_path:=scene.get_path_to(mesh)
 var source_mesh:Mesh=mesh.mesh
 var approved_skin:bool=request.values.torso_flow>0
 if approved_skin:Playback.prepare_approved_skin(model)
 var library:=AnimationLibrary.new()
 for motion in ["idle","walk","run"]:library.add_animation(StringName(motion),generator.set_animation_style("Aren",motion,request.values,skeleton_path,mesh_path))
 # Validate through AnimationPlayer against the actual native scene.
 var player:=AnimationPlayer.new();scene.add_child(player);player.add_animation_library(&"",library)
 var reports:Dictionary={}
 var validator:=Validator.new()
 for motion in ["idle","walk","run"]:
  var report:=validator.validate(model,player,StringName(motion))
  # Bake a constant whole-body floor correction; this preserves planted speed.
  if absf(report.floor_min_m)>.0005 and absf(report.floor_min_m)<.08:
   var clip:Animation=library.get_animation(StringName(motion))
   var lift:Vector3=skeleton.global_transform.basis.inverse()*Vector3.UP*(-report.floor_min_m/Generator.SCALE+.01)
   for key in clip.track_get_key_count(0):clip.track_set_key_value(0,key,clip.track_get_key_value(0,key)+lift)
   report=validator.validate(model,player,StringName(motion))
  reports[motion]=report
  if not report.ok:write_evidence(options,reports);fail("Validation failed for "+motion+": "+str(report));return
 player.stop();scene.remove_child(player);player.free()
 scene.set_script(load("res://scripts/animation/authoring/aren_playback.gd"));scene.set("library",library);scene.set("model_path",NodePath("NativeModel"));scene.scale=Vector3.ONE*Generator.SCALE
 scene.set("use_approved_skin",approved_skin);mesh.mesh=source_mesh
 # Store the library separately to keep each deliverable replaceable.
 if DirAccess.make_dir_recursive_absolute(output)!=OK:fail("Cannot create output directory");return
 if ResourceSaver.save(library,output+"/clips.res",ResourceSaver.FLAG_COMPRESS)!=OK:fail("Cannot save clips");return
 library.take_over_path(output+"/clips.res")
 var packed:=PackedScene.new()
 if packed.pack(scene)!=OK or ResourceSaver.save(packed,output+"/aren.tscn")!=OK:fail("Cannot save scene");return
 var cache:=generator.profile()
 var source_commit:Array=[]
 if OS.execute("git",["-C",ProjectSettings.globalize_path("res://"),"rev-parse","HEAD"],source_commit)==0:cache["source_commit"]=str(source_commit[0]).strip_edges()
 var file:=FileAccess.open(output+"/rig_profile.json",FileAccess.WRITE);file.store_string(JSON.stringify(cache,"  "));file.close()
 write_evidence(options,reports)
 print("PASS: Aren walk/run baked and validated: ",output," parameters=",request.values)
 generator.actor.free();scene.free();quit(0)
func write_evidence(options:Dictionary,reports:Dictionary) -> void:
 if not options.has("--evidence"):return
 var directory:String=options["--evidence"]
 if not directory.begins_with("/") or directory.begins_with(ProjectSettings.globalize_path("res://")):return
 DirAccess.make_dir_recursive_absolute(directory)
 var file:=FileAccess.open(directory+"/validation.json",FileAccess.WRITE)
 if file:file.store_string(JSON.stringify(reports,"  "))
