extends "res://scripts/animation/authoring/aren_blender_pilot_review.gd"
## Adds one isolated development sequence to the existing approved catalog.
const EXTREME_SCENE="res://scenes/prototype_3d/aren_extreme_review_actor.tscn"
const EXTREME_PHASES=["Desequilibrio","Inclinación · 19 %","Impacto y rebote","Tumbado","Incorporación"]
var extreme_index:=-1
var outcome_selector:OptionButton
func extreme_review() -> bool:return source_index==extreme_index and extreme_index>=0
func _ready() -> void:
 extreme_index=sources.size();sources.append({"label":"Blender · caída extrema ≥8 m","path":EXTREME_SCENE})
 super._ready()
 source_selector.add_item("Blender · caída extrema ≥8 m",extreme_index)
 outcome_selector=OptionButton.new();outcome_selector.position=Vector2(760,36)
 outcome_selector.add_item("Previsualizar: sobrevive");outcome_selector.add_item("Previsualizar: muere")
 outcome_selector.tooltip_text="Resultados de revisión. La integración futura consultará la vida real después del daño."
 outcome_selector.item_selected.connect(func(index:int):actors[0].outcome="survive" if index==0 else "die";restart_preview())
 add_child(outcome_selector)
 select_source(extreme_index)
func select_source(index:int) -> void:
 super.select_source(index)
 if outcome_selector:outcome_selector.visible=extreme_review()
 if not extreme_review():return
 motion="idle_to_fall"
 motion_selector.select(MOTIONS.find(motion))
 for item in MOTIONS.size():motion_selector.set_item_disabled(item,MOTIONS[item]!=motion)
 state_selector.select(0);state_selector.disabled=true
 if outcome_selector:actors[0].outcome="survive" if outcome_selector.selected==0 else "die"
 actors[0].begin_preview(motion);elapsed=0;playing=true;refresh_jump_view()
func update_source_status() -> void:
 if not extreme_review():super.update_source_status();return
 if not source_status:return
 update_pilot_controls()
 source_status.position.x=440;source_status.text="Blender ≥8 m · solo visor"
 source_status.tooltip_text="Cinco fases nuevas; aprobación visual pendiente. Sin integración jugable."
 state_selector.select(0);state_selector.disabled=true
 if comparison_selector:comparison_selector.visible=false
 if landing_detail:landing_detail.hide()
 for ledge in fall_ledges:ledge.hide()
 for marker in fall_markers:marker.hide()
func review_heights() -> Array:return [8.0,10.0,12.0,16.0] if extreme_review() else super.review_heights()
func refresh_phase_controls() -> void:
 if not extreme_review():super.refresh_phase_controls();return
 if not jump_bar:return
 jump_bar.get_child(0).text="Secuencia completa"
 for index in 6:
  var button:Button=jump_bar.get_child(index+1)
  button.visible=index<5
  if index<5:button.text=EXTREME_PHASES[index]
func refresh_jump_view() -> void:
 if not extreme_review():super.refresh_jump_view();return
 refresh_phase_controls();sync_pose_views()
 var actor=actors[0]
 jump_label.text="%s · caída %.2f / %.2f m · vy %.2f m/s · %s"%[EXTREME_PHASES[actor.phase_index],actor.drop_height-actor.position.y,actor.drop_height,actor.vertical_speed,"control bloqueado" if actor.controls_locked else "Idle recuperado"]
 jump_scrub.set_block_signals(true);jump_scrub.max_value=maxf(actor.preview_duration(motion),actor.preview_clock);jump_scrub.value=actor.preview_clock;jump_scrub.set_block_signals(false)
func show_jump_phase(index:int) -> void:
 if not extreme_review():super.show_jump_phase(index);return
 var actor=actors[0]
 var flight:float=Fall.flight_duration(actor.drop_height)
 var at:float=[.20,flight*sqrt(.19)+.08,flight+.10,flight+(actor.PRONE-actor.IMPACT)+.15,flight+(actor.GETUP-actor.IMPACT)+(actor.END-actor.GETUP)*.4][mini(index,4)]
 if index==4 and actor.outcome=="die":
  outcome_selector.select(0);actor.outcome="survive";actor.begin_preview(motion)
 playing=false;elapsed=at;actor.seek_preview(motion,at);refresh_jump_view()
func point_camera(index:int) -> void:
 if not extreme_review():super.point_camera(index);return
 var actor=actors[index]
 var angle:float=[0.0,PI/2,PI,PI/4][index]
 var target:Vector3=actor.position+Vector3(0,.65,.12)
 cameras[index].size=2.5
 cameras[index].position=target+Vector3(sin(angle)*4,.35,cos(angle)*4);cameras[index].look_at(target)
 grounds[index].position=Vector3.ZERO

func select_motion(index:int) -> void:
 super.select_motion(MOTIONS.find("idle_to_fall") if extreme_review() else index)
