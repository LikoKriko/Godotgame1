extends Control
## Four live views of a generated library, on a real fixed ground grid.
@export var scene_path:="res://assets/characters/prototype_3d/generated/aren_natural_v1/aren.tscn"
var actors:Array[Node3D]=[]
var cameras:Array[Camera3D]=[]
var viewports:Array[SubViewport]=[]
var motion:="walk"
var elapsed:=0.0
var playing:=true
var travel:=0.0
var speed_slider:HSlider
var motion_selector:OptionButton
var grounds:Array[Node3D]=[]
func _ready() -> void:
 var paths:=OS.get_cmdline_user_args()
 if paths.size()==1:scene_path=paths[0]
 build_views()
 var bar:=HBoxContainer.new();bar.position=Vector2(12,8);add_child(bar)
 var clips:=OptionButton.new()
 motion_selector=clips
 for label in ["walk","run","idle","transitions"]:clips.add_item(label)
 bar.add_child(clips);clips.item_selected.connect(func(index):motion=["walk","run","idle","transitions"][index];elapsed=0)
 var angles:=Label.new();angles.text="Frente · lateral · espalda · tres cuartos";bar.add_child(angles)
 var pause:=Button.new();pause.text="Pausa";bar.add_child(pause);pause.pressed.connect(func():playing=not playing)
 speed_slider=HSlider.new();speed_slider.min_value=.1;speed_slider.max_value=1.5;speed_slider.value=1;speed_slider.custom_minimum_size.x=160;bar.add_child(speed_slider)
 get_viewport().size_changed.connect(fit_views);fit_views()
func fit_views() -> void:
 scale=Vector2.ONE*minf(get_viewport_rect().size.x/1200.0,get_viewport_rect().size.y/885.0)
func build_views() -> void:
 for i in 4:
  var box:=SubViewportContainer.new();box.position=Vector2((i%2)*600,45+(i/2)*420);box.size=Vector2(600,420);add_child(box)
  var viewport:=SubViewport.new();viewport.size=Vector2i(600,420);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;box.add_child(viewport);viewports.append(viewport)
  var world:=Node3D.new();viewport.add_child(world)
  var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("36434b");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("dce4ec");environment.environment.ambient_light_energy=.65;world.add_child(environment)
  var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-35,0);light.shadow_enabled=true;world.add_child(light)
  var ground:=Node3D.new();world.add_child(ground);grounds.append(ground)
  var plane:=MeshInstance3D.new();plane.mesh=PlaneMesh.new();plane.mesh.size=Vector2(60,60);ground.add_child(plane)
  var material:=StandardMaterial3D.new();material.albedo_color=Color("657278");plane.material_override=material
  var grid:=MeshInstance3D.new();var lines:=ImmediateMesh.new();grid.mesh=lines;ground.add_child(grid)
  var line_material:=StandardMaterial3D.new();line_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;line_material.albedo_color=Color("859298")
  lines.surface_begin(Mesh.PRIMITIVE_LINES,line_material)
  for line in range(-40,41):
   var p:=line*.25
   for point in [Vector3(p,.002,-10),Vector3(p,.002,10),Vector3(-10,.002,p),Vector3(10,.002,p)]:lines.surface_add_vertex(point)
  lines.surface_end()
  var actor:Node3D=load(scene_path).instantiate();world.add_child(actor);actors.append(actor);actor.set_process(false);actor.tree.active=false
  var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.5;world.add_child(camera);camera.current=true;cameras.append(camera)
func show_frame(clip:String,seconds:float) -> void:
 if motion_selector:motion_selector.select(["walk","run","idle"].find(clip))
 for i in actors.size():
  var actor=actors[i]
  actor.tree.active=false
  var animation:Animation=actor.library.get_animation(StringName(clip))
  var info:Dictionary=animation.get_meta("cycle")
  actor.position.z=seconds*float(info.speed_mps)
  actor.player.play(StringName("aren/"+clip));actor.player.seek(fposmod(seconds,animation.length),true)
  point_camera(i)
func point_camera(index:int) -> void:
 var angle:float=[0.0,PI/2,PI,PI/4][index]
 var target:=actors[index].position+Vector3(0,.9,0)
 grounds[index].position.z=floorf(actors[index].position.z)
 cameras[index].position=target+Vector3(sin(angle)*4,.3,cos(angle)*4);cameras[index].look_at(target)
func _process(delta:float) -> void:
 if not playing:return
 elapsed+=delta*speed_slider.value
 if motion!="transitions":show_frame(motion,elapsed);return
 var target:float=0 if fmod(elapsed,8)>6 else (actors[0].library.get_animation(&"walk").get_meta("cycle").speed_mps if fmod(elapsed,8)<3 else actors[0].library.get_animation(&"run").get_meta("cycle").speed_mps)
 for i in actors.size():
  actors[i].tree.active=true;actors[i].set_locomotion(target);actors[i]._process(delta*speed_slider.value)
  if i==0:travel+=actors[i].current_speed*delta*speed_slider.value
  actors[i].position.z=travel;point_camera(i)
