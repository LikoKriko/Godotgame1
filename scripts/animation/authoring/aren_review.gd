extends Control
## Four live views of a generated library, on a real fixed ground grid.
const Actor=preload("res://scripts/prototype_3d/survivor_model.gd")
const ROOT="res://assets/characters/prototype_3d/generated/"
@export var scene_path:=ROOT+"aren_walk_upper_v1/aren.tscn"
var sources:Array=[
 {"label":"Original del juego","path":""},
 {"label":"Generada natural v1","path":ROOT+"aren_natural_v1/aren.tscn"},
 {"label":"Prueba: paso +20 %, brazos +30 %","path":ROOT+"aren_walk_proof_20_30_v1/aren.tscn"},
 {"label":"Generada cautelosa v1","path":ROOT+"aren_cautious_v1/aren.tscn"},
 {"label":"Generada cansada v1","path":ROOT+"aren_tired_v1/aren.tscn"},
 {"label":"Caminata: torso coordinado","path":ROOT+"aren_walk_torso_v2/aren.tscn"},
 {"label":"Carrera y reposo corregidos","path":ROOT+"aren_run_idle_v3/aren.tscn"},
 {"label":"Transiciones con apoyos","path":ROOT+"aren_transitions_v1/aren.tscn"},
 {"label":"Carrera e impulso: postura ajustada","path":ROOT+"aren_run_launch_v1/aren.tscn"},
 {"label":"Coordinación: brazos y rodillas","path":ROOT+"aren_coordination_v1/aren.tscn"},
 {"label":"Caminata: torso superior coordinado","path":ROOT+"aren_walk_upper_v1/aren.tscn"}
]
const MOTIONS=["walk","run","idle","transitions","idle_to_walk","idle_to_run","walk_to_run","run_to_walk","walk_to_idle","run_to_idle"]
const CHAIN=["idle_to_walk","walk_to_run","run_to_walk","walk_to_idle","idle_to_run","run_to_idle"]
var state_selector:OptionButton
var restart_button:Button
var compare_button:Button
var chain_index:=0
var chain_wait:=0.0
var source_index:=7
var source_selector:OptionButton
var source_status:Label
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
 if paths.size()==1 and paths[0].ends_with(".tscn") and ResourceLoader.exists(paths[0]):scene_path=paths[0]
 source_index=-1
 for i in sources.size():
  if sources[i].path==scene_path:source_index=i;break
 if source_index<0:
  sources.append({"label":"Generada personalizada","path":scene_path});source_index=sources.size()-1
 if sources[source_index].path.ends_with("aren_transitions_v1/aren.tscn"):motion="transitions"
 if sources[source_index].path.ends_with("aren_run_launch_v1/aren.tscn"):motion="run"
 build_views()
 var bar:=HBoxContainer.new();bar.position=Vector2(12,8);add_child(bar)
 source_selector=OptionButton.new();source_selector.name="SourceSelector"
 for source in sources:source_selector.add_item(source.label)
 bar.add_child(source_selector);source_selector.select(source_index);source_selector.item_selected.connect(select_source)
 var clips:=OptionButton.new()
 motion_selector=clips
 for label in ["walk","run","idle","Encadenadas","Reposo → caminar","Reposo → correr","Caminar → correr","Correr → caminar","Caminar → reposo","Correr → reposo"]:clips.add_item(label)
 bar.add_child(clips);clips.select(MOTIONS.find(motion));clips.item_selected.connect(select_motion)
 var angles:=Label.new();angles.text="Frente · lateral · espalda · tres cuartos";bar.add_child(angles)
 var pause:=Button.new();pause.text="Pausa";bar.add_child(pause);pause.pressed.connect(func():playing=not playing)
 speed_slider=HSlider.new();speed_slider.min_value=.1;speed_slider.max_value=1.5;speed_slider.value=1;speed_slider.custom_minimum_size.x=100;bar.add_child(speed_slider)
 state_selector=OptionButton.new();state_selector.position=Vector2(12,36)
 for label in ["Normal","Cauteloso","Cansado"]:state_selector.add_item(label)
 add_child(state_selector);state_selector.item_selected.connect(select_state)
 restart_button=Button.new();restart_button.text="Reiniciar";restart_button.position=Vector2(145,36);add_child(restart_button)
 restart_button.pressed.connect(func():reset_trees() if transition_motion() else show_frame(motion,0))
 compare_button=Button.new();compare_button.position=Vector2(235,36);add_child(compare_button);compare_button.pressed.connect(compare_posture)
 source_status=Label.new();source_status.position=Vector2(350,36);add_child(source_status)
 refresh_options()
 if transition_motion():reset_trees()
 update_source_status()
 get_viewport().size_changed.connect(fit_views);fit_views()
func fit_views() -> void:
 scale=Vector2.ONE*minf(get_viewport_rect().size.x/1200.0,get_viewport_rect().size.y/905.0)
func build_views() -> void:
 for i in 4:
  var box:=SubViewportContainer.new();box.position=Vector2((i%2)*600,65+(i/2)*420);box.size=Vector2(600,420);add_child(box)
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
  var actor:=create_actor(world);actors.append(actor)
  var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.5;world.add_child(camera);camera.current=true;cameras.append(camera)
func show_frame(clip:String,seconds:float) -> void:
 for i in actors.size():
  var actor=actors[i]
  var info:=cycle_info(clip)
  actor.position.z=seconds*float(info.speed_mps)
  if source_index==0:
   var phase:=fposmod(seconds/info.duration,1.0)
   actor.animate(StringName(clip),phase,false,0,phase,Vector3.BACK if clip!="idle" else Vector3.ZERO)
  else:
   actor.tree.active=false
   if actor.has_method("seek_cycle"):actor.seek_cycle(clip,fposmod(seconds,info.duration))
   else:
    actor.player.play(StringName("aren/"+clip));actor.player.seek(fposmod(seconds,info.duration),true);actor.player.pause()
  point_camera(i)
func point_camera(index:int) -> void:
 var angle:float=[0.0,PI/2,PI,PI/4][index]
 var target:=actors[index].position+Vector3(0,.9,0)
 grounds[index].position.z=floorf(actors[index].position.z)
 cameras[index].position=target+Vector3(sin(angle)*4,.3,cos(angle)*4);cameras[index].look_at(target)
func _process(delta:float) -> void:
 if not playing:return
 elapsed+=delta*speed_slider.value
 if advanced() and transition_motion():
  process_transitions(delta*speed_slider.value);return
 if motion!="transitions":show_frame(motion,elapsed);return
 if source_index==0:
  show_frame("idle" if fmod(elapsed,8)>6 else ("walk" if fmod(elapsed,8)<3 else "run"),elapsed);return
 var target:float=0 if fmod(elapsed,8)>6 else (cycle_info("walk").speed_mps if fmod(elapsed,8)<3 else cycle_info("run").speed_mps)
 for i in actors.size():
  actors[i].tree.active=true;actors[i].set_locomotion(target);actors[i]._process(delta*speed_slider.value)
  if i==0:travel+=actors[i].current_speed*delta*speed_slider.value
  actors[i].position.z=travel;point_camera(i)

func create_actor(world:Node3D) -> Node3D:
 var actor:Node3D=Actor.new() if source_index==0 else load(sources[source_index].path).instantiate()
 world.add_child(actor);actor.set_process(false)
 if source_index==0:
  actor.scale=Vector3.ONE*(1.75/64.0);actor.family_override=&"";actor.steering_is_physical=true
 else:actor.tree.active=false
 return actor
func cycle_info(clip:String) -> Dictionary:
 if source_index!=0:
  var animation:Animation=actors[0].library.get_animation(StringName(clip))
  var result:Dictionary=animation.get_meta("cycle").duplicate();result.duration=animation.length;return result
 if clip=="idle":return {"duration":1.0,"speed_mps":0.0}
 var sprint:=1.0 if clip=="run" else 0.0
 var speed:=4.48 if clip=="run" else 2.0
 var distance:float=Actor.Clips.cycle_distance(sprint)/Actor.Clips.gait_playback_rate(sprint)
 return {"duration":distance/speed,"speed_mps":speed}
func select_source(index:int) -> void:
 if index<0 or index>=sources.size():return
 var phase:float=fposmod(elapsed/cycle_info("walk" if transition_motion() else motion).duration,1.0)
 source_index=index;scene_path=sources[index].path

 for i in actors.size():
  var world:=actors[i].get_parent();actors[i].free();actors[i]=create_actor(world)
 elapsed=phase*cycle_info("walk" if transition_motion() else motion).duration;travel=0
 if source_selector:source_selector.select(index)
 refresh_options();update_source_status()
 if not transition_motion():show_frame(motion,elapsed)
 else:reset_trees()
func reset_trees() -> void:
 if advanced():start_transition_preview();return
 for actor in actors:
  if source_index!=0:actor.blend=0;actor.tree.active=true
func update_source_status() -> void:
 if not source_status:return
 if compare_button:
  compare_button.disabled=source_index not in [9,10]
  compare_button.text="Ver antes" if source_index==10 else "Ver después"
 if source_index==0:source_status.text="Original del juego · animación procedural aprobada";return
 if advanced() and transition_motion():
  var actor=actors[0]
  source_status.text="%s · %s · %.2f m/s"%[["Normal","Cauteloso","Cansado"][state_selector.selected],actor.recipe if not actor.recipe.is_empty() else "Ciclo estable",actor.current_speed]
  if actor.has_method("seek_cycle") and motion=="idle_to_run":
   var extra:float=actor.launch_pitch-actor.steady_chest_pitch
   if actor.has_method("impulse_increment"):extra+=actor.impulse_increment()
   source_status.text+=" · %.1f pasos · extra %.1f°"%[actor.recovery_steps_done,rad_to_deg(maxf(0,extra))]
  return
 var clip:String="walk" if transition_motion() else motion
 var animation:Animation=actors[0].library.get_animation(StringName(clip))
 var parameters:Dictionary=animation.get_meta("parameters")
 if clip=="run" or clip=="idle":
  source_status.text="%s · %s · Ciclo %.2f s · %.3f m/s"%[sources[source_index].label,clip,animation.length,animation.get_meta("cycle").speed_mps]
  if actors[0].has_method("seek_cycle") and clip=="run":source_status.text="%s · run · torso +%.1f° · %.3f m/s"%[["Normal","Cauteloso","Cansado"][state_selector.selected],actors[0].profile.posture[actors[0].style].steady_deg,animation.get_meta("cycle").speed_mps]
  return
 if actors[0].has_method("impulse_increment") and clip=="walk":
  source_status.text="%s · walk · brazos contralaterales · %.3f m/s"%[["Normal","Cauteloso","Cansado"][state_selector.selected],animation.get_meta("cycle").speed_mps]
  if actors[0].profile.has("walk_torso"):source_status.text+=" · torso coordinado"
  return
 source_status.text="%s · Paso ×%.2f · Brazos ×%.2f · Torso extra %.1f°"%[sources[source_index].label,parameters.stride,parameters.arms,rad_to_deg(parameters.lean)]

func advanced() -> bool:return not actors.is_empty() and actors[0].has_method("advance_transition")
func transition_motion() -> bool:return motion=="transitions" or motion in CHAIN
func refresh_options() -> void:
 if not motion_selector:return
 for index in range(4,MOTIONS.size()):motion_selector.set_item_disabled(index,not advanced())
 motion_selector.set_item_disabled(3,source_index==0)
 if (motion in CHAIN and not advanced()) or (motion=="transitions" and source_index==0):motion="walk"
 motion_selector.select(MOTIONS.find(motion))
 if state_selector:state_selector.disabled=not advanced()
 if advanced():
  for actor in actors:actor.set_style(["normal","cautious","tired"][state_selector.selected])
func select_motion(index:int) -> void:
 motion=MOTIONS[index];elapsed=0;travel=0
 if transition_motion():reset_trees()
 else:show_frame(motion,0)
 update_source_status()
func select_state(index:int) -> void:
 if not advanced():return
 for actor in actors:actor.set_style(["normal","cautious","tired"][index])
 if transition_motion():start_transition_preview()
 else:show_frame(motion,0)
 update_source_status()
func start_transition_preview() -> void:
 chain_index=0;chain_wait=0;elapsed=0;travel=0
 var name:String=CHAIN[0] if motion=="transitions" else motion
 for actor in actors:
  actor.reset_motion(actor.profile.recipes[name].from)
  actor.request_transition(name);actor.position.z=0
 update_source_status()
func process_transitions(delta:float) -> void:
 if motion=="transitions" and actors[0].recipe.is_empty():
  chain_wait+=delta
  if chain_wait>=.45:
   chain_wait=0;chain_index=(chain_index+1)%CHAIN.size()
   for actor in actors:actor.request_transition(CHAIN[chain_index])
 for i in actors.size():
  actors[i].advance_transition(delta);actors[i].position.z=actors[i].distance_m;point_camera(i)
 update_source_status()

func compare_posture() -> void:
 if source_index not in [9,10]:return
 var seconds:=elapsed
 select_source(9 if source_index==10 else 10)
 if transition_motion():
  var remaining:=seconds
  while remaining>.0000001:
   var dt:float=minf(remaining,1.0/120);process_transitions(dt);remaining-=dt
  elapsed=seconds
 else:elapsed=seconds;show_frame(motion,seconds)
 update_source_status()
