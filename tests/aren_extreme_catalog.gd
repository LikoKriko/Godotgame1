extends SceneTree
## Viewer wiring and preservation of the approved catalog.
var failures:Array[String]=[]
var checks:=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String) -> void:
 checks+=1
 if not ok and message not in failures:failures.append(message);push_error(message)
func run() -> void:
 var review=load("res://scenes/prototype_3d/aren_authoring_review.tscn").instantiate();root.add_child(review);review.set_process(false)
 await physics_frame
 check(review.extreme_review(),"extreme sequence opens in the required viewer")
 check(review.cameras.size()==4 and review.actors.size()==4,"four independent views")
 review.speed_presets.select(1);review.speed_presets.item_selected.emit(1)
 check(is_equal_approx(review.speed_slider.value,.25),"quarter speed")
 review.speed_presets.select(0);review.speed_presets.item_selected.emit(0)
 check(is_equal_approx(review.speed_slider.value,1),"normal speed")
 for phase in 5:
  review.show_jump_phase(phase)
  check(review.actors[0].phase_index==phase,"phase button "+str(phase))
 review.outcome_selector.select(1);review.outcome_selector.item_selected.emit(1)
 review.actors[0].advance_jump_preview(20);review.refresh_jump_view()
 check(review.actors[0].preview_stage=="prone" and review.actors[0].controls_locked,"death preview stays prone")
 review.show_jump_phase(4)
 check(review.actors[0].preview_stage=="getup" and review.outcome_selector.selected==0,"getup phase can restart a death preview")
 review.fall_height_selector.select(2);review.fall_height_selector.item_selected.emit(2)
 check(is_equal_approx(review.actors[0].drop_height,12),"height selector")
 for source in [14,15,16,review.pilot_index]:
  review.select_source(source);await physics_frame
  check(review.actors[0].native.skeleton.get_bone_count()==66,"approved native source "+str(source))
  check(not review.outcome_selector.visible,"outcome control isolated to extreme")
 review.select_comparison(0);check(review.source_index==review.PREVIOUS_INDEX,"existing previous reception")
 review.select_comparison(1);check(review.source_index==review.pilot_index,"existing current reception")
 review.select_source(review.extreme_index);await physics_frame
 check(review.extreme_review() and review.outcome_selector.visible,"return to extreme catalog entry")
 review.free();await process_frame
 print("EXTREME CATALOG ",checks," checks; failures ",failures)
 quit(0 if failures.is_empty() else 1)
