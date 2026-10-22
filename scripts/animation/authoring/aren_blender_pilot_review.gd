extends "res://scripts/animation/authoring/aren_review.gd"
## Same four-angle authoring viewer; the optional pilot is isolated from gameplay.
const PILOT_SCENE="res://scenes/prototype_3d/aren_blender_landing_review_actor.tscn"
var pilot_index:=0
var turn_review_button:Button
func _ready() -> void:
 pilot_index=sources.size();sources.append({"label":"Piloto Blender · recepción 3 m","path":PILOT_SCENE})
 scene_path=PILOT_SCENE;motion="idle_to_fall"
 super._ready()
 for child in get_children():
  if child is Button and child.text=="Paso 3: comparar giros":turn_review_button=child
 compare_button.pressed.connect(compare_pilot)
 update_pilot_controls()
func update_source_status() -> void:
 super.update_source_status()
 update_pilot_controls()

func select_source(index:int) -> void:
 if index==pilot_index and state_selector:state_selector.select(0)
 if motion_selector:
  for item in MOTIONS.size():motion_selector.set_item_disabled(item,false)
 super.select_source(index)
 update_pilot_controls()
func update_pilot_controls() -> void:
 if not compare_button:return
 var pilot:=source_index==pilot_index
 if turn_review_button:turn_review_button.visible=source_index not in [17,pilot_index]
 if source_index not in [17,pilot_index]:
  compare_button.position=Vector2(235,36)
  return
 compare_button.visible=true;compare_button.disabled=false
 compare_button.position=Vector2(990,36)
 compare_button.text="Ver procedural" if pilot else "Ver Blender"
 if landing_reference and pilot:landing_reference.hide()
 if pilot:
  state_selector.select(0);state_selector.disabled=true
  motion="idle_to_fall";motion_selector.select(MOTIONS.find(motion))
  for index in MOTIONS.size():motion_selector.set_item_disabled(index,MOTIONS[index]!="idle_to_fall")
func review_heights() -> Array:return [3.0] if source_index==pilot_index else super.review_heights()
func compare_pilot() -> void:
 if source_index not in [17,pilot_index]:return
 var at:float=actors[0].preview_clock;var was_playing:=playing
 motion="idle_to_fall"
 select_source(17 if source_index==pilot_index else pilot_index)
 actors[0].review_height=3;actors[0].begin_preview(motion);actors[0].advance_jump_preview(at)
 elapsed=at;playing=was_playing
 if fall_height_selector:fall_height_selector.select(review_heights().find(3.0))
 refresh_jump_view()
