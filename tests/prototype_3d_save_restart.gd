extends SceneTree
const Save=preload("res://scripts/prototype_3d/save_game.gd")
func _initialize():call_deferred("run")
func run():
 var args:=OS.get_cmdline_user_args()
 if args.size()!=2 or args[0] not in ["write","read"] or not args[1].begins_with("/tmp/day-zero-restart-test-"):
  push_error("Use -- write|read /tmp/day-zero-restart-test-<name>.save");quit(1);return
 var app=load("res://scenes/prototype_3d/day_zero.tscn").instantiate();app.save_path=args[1];app.session_ready.connect(func(world):world.paused=true);root.add_child(app)
 var ok:=true
 if args[0]=="write":await app.new_game()
 else:
  ok=app.menu.can_continue
  await app.continue_game()
 var deadline:=Time.get_ticks_msec()+30000
 while app.loading_busy and Time.get_ticks_msec()<deadline:await process_frame
 if not is_instance_valid(app.game) or app.loading_busy:push_error("Fresh process failed to open the world");app.free();quit(1);return
 var game=app.game
 var resource=game.environment_content.resource_nodes.values()[0]
 if args[0]=="write":
  resource.health=1;resource.hit();game.bag.add(&"flecha",7);game.skill_points=42;ok=game.save_current_game()==OK
 else:ok=ok and game.bag.count(&"flecha")==7 and game.skill_points==42 and resource.health==0
 app.free();await process_frame
 if not ok:push_error("Disk state did not survive an actual process restart")
 print("%s: %s save across separate Godot processes"%["PASS" if ok else "FAIL",args[0]]);quit(0 if ok else 1)
