extends SceneTree
## ALT changes only the view: native-head limits, constant-speed return,
## unchanged steering/action rays and the existing collision boom.
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:
  failures+=1
  if failures<12:push_error(message)
func alt(pressed:bool) -> void:
 var event:=InputEventKey.new();event.keycode=KEY_ALT;event.physical_keycode=KEY_ALT;event.pressed=pressed
 Input.parse_input_event(event);Input.flush_buffered_events()
func _initialize():call_deferred("run")
func run():
 if DisplayServer.get_name()=="headless":
  print("ALT free-look checks require a display with mouse capture");quit(1);return
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();game.use_test_layout=true;root.add_child(game)
 game.set_physics_process(false);game.player.set_physics_process(false);game.paused=false
 Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 game.player.position=Vector3(10,0,10)
 await physics_frame
 var rig=game.camera_rig
 rig.yaw=rig.head_yaw();rig.pitch=0;rig.update(1)
 var heading:float=rig.yaw;var pitch:float=rig.pitch
 var steering:Vector3=rig.movement_direction(Vector2.UP)
 var aim:Vector3=rig.aim_point()
 alt(true);require(Input.is_physical_key_pressed(KEY_ALT),"Physical ALT events reach the input state")
 rig.look(Vector2(1e6,100));rig.update(0)
 require(absf(rig.free_look_offset+PI/2)<0.00001,"Large mouse motion stops at the left 90-degree limit")
 require(rig.yaw==heading and rig.pitch==pitch,"Free look leaves normal aim yaw and pitch unchanged")
 require(rig.movement_direction(Vector2.UP).is_equal_approx(steering),"Looking sideways preserves movement direction")
 require(rig.aim_point().distance_to(aim)<0.001,"Looking sideways preserves action and character-facing rays")
 require((-rig.camera.global_basis.z).dot(-rig.aim_camera.global_basis.z)<0.001,"Rendered view turns without turning the aim camera")
 var reticle=game.hud.get_parent().get_node("Reticle");reticle._process(0)
 require(not reticle.visible,"Free look hides the reticle instead of suggesting a sideways action ray")
 require(root.get_camera_3d()==rig.camera,"Projection-only aim camera never renders a second view")
 for fps in [30,60,120]:
  for degrees in [-90.,-45.,0.,45.,90.]:
   rig.free_look_offset=0;alt(true);rig.look(Vector2(-deg_to_rad(degrees)/rig.SENSITIVITY,0));rig.update(0)
   require(absf(rad_to_deg(rig.free_look_offset)-degrees)<0.001,"Both sides reach the requested angle")
   alt(false)
   var duration:float=absf(degrees)/45
   var frames:=roundi(duration*fps)
   for frame in frames:
    rig.update(1.0/fps)
    var expected:float=maxf(0,absf(degrees)-45.0*(frame+1)/fps)
    require(absf(absf(rad_to_deg(rig.free_look_offset))-expected)<0.001,"Return remains exactly 45 degrees per second at every frame rate")
   rig.update(0)
   require(not rig.is_free_looking(),"Return finishes in the proportional duration without residual drift")
   require(rig.camera.global_transform.is_equal_approx(rig.aim_camera.global_transform),"Aim and view coincide after returning")
 alt(true);rig.look(Vector2(-PI/4/rig.SENSITIVITY,0));rig.update(0)
 alt(false);rig.update(.5)
 var partial:float=rig.free_look_offset
 alt(true);rig.look(Vector2.ZERO);rig.update(0)
 require(is_equal_approx(rig.free_look_offset,partial),"Pressing ALT during return resumes without a snap")
 game.paused=true;rig.update(.5)
 require(not rig.free_look_held,"Opening a menu releases the held free-look state")
 game.paused=false;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;rig.update(.5)
 require(not rig.free_look_held,"Uncaptured mouse cannot keep ALT active")
 alt(false);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;rig.free_look_offset=0
 for rotation_value in [-2.9,-.7,1.2,3.1]:
  game.player.model.rotation.y=rotation_value
  rig.yaw=rig.head_yaw();rig.update(0);alt(true)
  for relative in [-1e6,1e6]:
   rig.look(Vector2(relative,0));rig.update(0)
   var view:=atan2(rig.camera.global_basis.z.x,rig.camera.global_basis.z.z)
   require(absf(absf(wrapf(view-rig.head_yaw(),-PI,PI))-PI/2)<0.00001,"Limits follow the animated head across world headings")
  alt(false);rig.free_look_offset=0
 game.player.model.rotation.y=PI;rig.yaw=rig.head_yaw();game.player.position=Vector3(-6.55,0,-2)
 await physics_frame
 alt(true)
 for degrees in [-90.,0.,90.]:
  rig.free_look_offset=deg_to_rad(degrees);rig.update(0)
  var query:=PhysicsShapeQueryParameters3D.new();query.shape=rig.boom_shape;query.collision_mask=5;query.exclude=[game.player.get_rid()]
  query.transform=Transform3D(Basis.IDENTITY,rig.global_position);query.motion=rig.global_basis*rig.BOOM_OFFSET
  var fractions:PackedFloat32Array=rig.get_world_3d().direct_space_state.cast_motion(query)
  require(rig.actual_distance<=rig.DISTANCE*fractions[0]+.00001,"Lateral views preserve sphere-cast collision protection")
 alt(false);rig.reset_free_look();rig.update(0)
 reticle._process(0);require(reticle.visible,"Reticle returns when aim and view coincide")
 var native=game.player.model.native
 var head_pose:Transform3D=native.posed[native.head]
 var original_heading:float=rig.head_yaw()
 native.posed[native.head].basis=Basis(Vector3.UP,.4)*head_pose.basis
 require(absf(wrapf(rig.head_yaw()-original_heading,-PI,PI)-.4)<.00001,"Head reference follows animated bones independently of torso orientation")
 rig.yaw=original_heading;alt(true);rig.look(Vector2(-1e6,0));rig.update(0)
 require(absf(rig.free_look_offset-(.4+PI/2))<.00001,"Sideways limit uses the animated head, not just the body or original camera")
 alt(false);native.posed[native.head]=head_pose
 game.player.reset_motion_state()
 require(not rig.is_free_looking(),"Respawn and loading clear temporary free look without changing saved camera angles")
 rig.update(0);rig.look(Vector2(0,1e6));require(is_equal_approx(rig.pitch,-PI/2),"Normal downward aiming keeps its full range")
 rig.look(Vector2(0,-2e6));require(is_equal_approx(rig.pitch,PI/2),"Normal upward aiming keeps its full range")
 game.free();await RenderingServer.frame_post_draw;print("%s: %d ALT head-limit, steering, aim, return-time and collision checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
