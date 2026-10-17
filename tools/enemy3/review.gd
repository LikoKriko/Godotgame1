extends Node
## F6: four live Godot views. Space pauses, R restores the supplied pose, W walks.
const Actor=preload("res://scripts/prototype_3d/sprout_model.gd")
const Scene=preload("res://scenes/prototype_3d/enemy3.tscn")
var actors:Array[Node3D]=[]
var phase:=0.0
var paused:=false
var walking:=true
var running:=false
var capturing:=false
var status:Label
func _ready() -> void:
 get_window().size=Vector2i(1200,880)
 var title:=Label.new();title.text="Enemigo3 · Sunny Sprout · texturas originales · caminata y carrera";title.position=Vector2(18,8);title.add_theme_font_size_override("font_size",22);add_child(title)
 status=Label.new();status.position=Vector2(18,42);add_child(status)
 var positions:=[Vector3(0,1.05,4),Vector3(4,1.05,0),Vector3(0,1.05,-4),Vector3(2.8,1.7,3.3)]
 for i in 4:
  var column:=i%2;var row:=i/2
  var panel:=SubViewportContainer.new();panel.position=Vector2(column*600,80+row*400);panel.size=Vector2(600,400);add_child(panel)
  var view:=SubViewport.new();view.own_world_3d=true;view.size=Vector2i(600,400);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;panel.add_child(view)
  var world:=Node3D.new();view.add_child(world)
  var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("343d43");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.4;world.add_child(env)
  var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-38,-25,0);light.light_energy=.65;light.shadow_enabled=true;world.add_child(light)
  var floor_node:=MeshInstance3D.new();floor_node.mesh=PlaneMesh.new();floor_node.mesh.size=Vector2(3.5,3.5);var mat:=StandardMaterial3D.new();mat.albedo_color=Color("555a52");floor_node.material_override=mat;world.add_child(floor_node)
  var actor:=Scene.instantiate();world.add_child(actor);actors.append(actor)
  var camera:=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.9;camera.position=positions[i];camera.look_at(Vector3(0,.94,-.25))
  var label:=Label.new();label.text=["Frente","Lateral","Espalda","Tres cuartos"][i];label.position=Vector2(column*600+18,80+row*400+8);label.add_theme_font_size_override("font_size",18);add_child(label)
 if "--capture" in OS.get_cmdline_user_args():
  capturing=true;capture.call_deferred()
func _process(delta:float) -> void:
 if capturing:return
 if not paused:phase=fposmod(phase+delta/(Actor.RUN_CYCLE_SECONDS if running else Actor.CYCLE_SECONDS),1)
 pose()
func pose() -> void:
 for actor in actors:
  var player:AnimationPlayer=actor.get_node("AnimationPlayer")
  player.play((&"run" if running else &"walk") if walking else &"RESET");player.seek(phase*(Actor.RUN_CYCLE_SECONDS if running else Actor.CYCLE_SECONDS) if walking else 0.0,true);player.pause()
 status.text=("%s · %.2f s/ciclo · fase %.2f"%["Carrera" if running else "Caminata",Actor.RUN_CYCLE_SECONDS if running else Actor.CYCLE_SECONDS,phase] if walking else "Pose original · texturas enlazadas")+"    Espacio: pausa   R: original   W: caminar   C: correr"
func _unhandled_key_input(event:InputEvent) -> void:
 if event.is_action_pressed("ui_accept"):paused=not paused
 if event is InputEventKey and event.pressed:
  if event.keycode==KEY_R:walking=false
  if event.keycode==KEY_W:walking=true;running=false
  if event.keycode==KEY_C:walking=true;running=true
func capture() -> void:
 var folder:=OS.get_cmdline_user_args()[-1];DirAccess.make_dir_recursive_absolute(folder)
 walking=false;pose();await frames()
 get_viewport().get_texture().get_image().save_png("res://docs/previews/enemy3_textures.png")
 walking=true
 for i in 48:
  phase=i/48.0;pose();await frames()
  var picture:=get_viewport().get_texture().get_image();picture.save_png(folder+"/walk_%02d.png"%i)
  if i==9:picture.save_png("res://docs/previews/enemy3_walk.png")
 get_tree().quit()
func frames() -> void:
 for i in 3:await get_tree().process_frame
 await RenderingServer.frame_post_draw
