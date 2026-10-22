extends "res://scripts/animation/authoring/aren_review.gd"
## Catalog presentation only. Historical sources remain available to other tools.
const PILOT_SCENE="res://scenes/prototype_3d/aren_blender_landing_review_actor.tscn"
const PROCEDURAL_INDEX=17
const TURNS_ID=1000
var pilot_index:=0
var comparison_selector:OptionButton
var speed_presets:OptionButton
var catalog_ready:=false
var turn_review_button:Button
func _ready() -> void:
 pilot_index=sources.size();sources.append({"label":"Piloto Blender · recepción 3 m","path":PILOT_SCENE})
 scene_path=PILOT_SCENE;motion="idle_to_fall"
 super._ready()
 for child in get_children():
  if child is Button and child.text=="Paso 3: comparar giros":
   turn_review_button=child;turn_review_button.hide()
 source_selector.item_selected.disconnect(select_source)
 source_selector.clear()
 source_selector.add_separator("Animaciones aprobadas")
 source_selector.add_item("Locomoción y transiciones",14)
 source_selector.add_item("Salto voluntario y transiciones",15)
 source_selector.add_item("Caída automática y transiciones",16)
 source_selector.add_item("Giros y cambios de dirección",TURNS_ID)
 source_selector.add_separator("Animación en desarrollo")
 source_selector.add_item("Piloto Blender · recepción 3 m",pilot_index)
 source_selector.item_selected.connect(select_catalog_item)
 comparison_selector=OptionButton.new();comparison_selector.position=Vector2(965,36)
 comparison_selector.add_item("Anterior (procedural)");comparison_selector.add_item("Actual (Blender)")
 comparison_selector.item_selected.connect(select_comparison);add_child(comparison_selector)
 speed_slider.step=.001;speed_slider.value=1.0;speed_slider.hide()
 speed_presets=OptionButton.new();speed_presets.add_item("1,0×");speed_presets.add_item("0,25×")
 speed_presets.item_selected.connect(func(index:int):speed_slider.value=1.0 if index==0 else .25)
 speed_slider.get_parent().add_child(speed_presets)
 for child in speed_slider.get_parent().get_children():
  if child is Label:
   child.text="4 vistas";child.tooltip_text="Frontal · lateral · trasera · diagonal"
 catalog_ready=true
 update_pilot_controls()
func select_catalog_item(item:int) -> void:
 var id:=source_selector.get_item_id(item)
 if id==TURNS_ID:
  sync_catalog_selection()
  get_tree().change_scene_to_file("res://scenes/prototype_3d/aren_turn_review.tscn")
  return
 select_source(id)
func sync_catalog_selection() -> void:
 if not catalog_ready or not source_selector:return
 var id:=pilot_index if source_index==PROCEDURAL_INDEX else source_index
 source_selector.select(source_selector.get_item_index(id))
func update_source_status() -> void:
 super.update_source_status()
 update_pilot_controls()
func select_source(index:int) -> void:
 if index in [PROCEDURAL_INDEX,pilot_index] and state_selector:state_selector.select(0)
 if motion_selector:
  for item in MOTIONS.size():motion_selector.set_item_disabled(item,false)
 # The base uses source indices; the visible catalog uses item IDs and headings.
 var selector:=source_selector
 if catalog_ready:source_selector=null
 super.select_source(index)
 source_selector=selector
 if index in [PROCEDURAL_INDEX,pilot_index]:
  motion="idle_to_fall";actors[0].review_height=3.0;actors[0].begin_preview(motion)
  elapsed=0;refresh_jump_view()
 update_pilot_controls()
func update_pilot_controls() -> void:
 if not compare_button:return
 compare_button.hide()
 if landing_reference:landing_reference.hide()
 if turn_review_button:turn_review_button.hide()
 if not catalog_ready:return
 sync_catalog_selection()
 var development:=source_index in [PROCEDURAL_INDEX,pilot_index]
 comparison_selector.visible=development
 if development:
  comparison_selector.select(1 if source_index==pilot_index else 0)
  state_selector.select(0);state_selector.disabled=true
  motion="idle_to_fall";motion_selector.select(MOTIONS.find(motion))
  for index in MOTIONS.size():motion_selector.set_item_disabled(index,MOTIONS[index]!="idle_to_fall")
  source_status.text="En desarrollo · pendiente de aprobación"
func review_heights() -> Array:
 return [3.0] if source_index in [PROCEDURAL_INDEX,pilot_index] else super.review_heights()
func select_comparison(index:int) -> void:
 var target:=PROCEDURAL_INDEX if index==0 else pilot_index
 if source_index==target:return
 var at:float=actors[0].preview_clock;var was_playing:=playing
 select_source(target)
 actors[0].advance_jump_preview(at)
 elapsed=at;playing=was_playing
 refresh_jump_view()
func compare_pilot() -> void:
 if source_index in [PROCEDURAL_INDEX,pilot_index]:
  select_comparison(0 if source_index==pilot_index else 1)
