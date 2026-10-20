extends SceneTree
## Render actual native-skin motion: -- scene-path new-local-directory walk|run
func _initialize():call_deferred("run")
func run() -> void:
 var args:=OS.get_cmdline_user_args()
 if args.size()!=3 or args[2] not in ["walk","run"] or DirAccess.dir_exists_absolute(args[1]):push_error("Pass scene, NEW local directory, walk|run");quit(1);return
 if args[1].begins_with("res://") or args[1].begins_with(ProjectSettings.globalize_path("res://")):push_error("Evidence must stay outside Git");quit(1);return
 DirAccess.make_dir_recursive_absolute(args[1])
 root.size=Vector2i(1200,885);root.content_scale_size=Vector2i.ZERO
 var review=load("res://scripts/animation/authoring/aren_review.gd").new();review.scene_path=args[0];root.add_child(review);review.playing=false
 var clip:Animation=review.actors[0].library.get_animation(StringName(args[2]))
 for frame in 48:
  review.show_frame(args[2],frame/24.0*clip.length)
  for warmup in (3 if frame==0 else 1):await process_frame
  await RenderingServer.frame_post_draw
  var result:=root.get_texture().get_image().save_png(args[1]+"/frame_%03d.png"%frame)
  if result!=OK:push_error("Cannot save render");quit(1);return
 print("PASS: 48 rendered frames, four angles: ",args[1]);quit(0)
