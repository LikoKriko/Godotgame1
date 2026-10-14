extends Node
## Whole-sprite food/death presentation. Inventory commits only at completion.
const EAT_SECONDS := 1.2
const DEATH_SECONDS := 3.0
var game
var food_uid := -1
var food_id: StringName = &""
var food_elapsed := 0.0
var death_elapsed := -1.0
var death_armor: StringName = &""
var panel: Control
func configure(owner_game, canvas: CanvasLayer) -> void:
 game = owner_game
 panel = Control.new(); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); panel.hide(); canvas.add_child(panel)
 panel.theme = preload("res://scripts/ui_style.gd").theme()
 var center := CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); panel.add_child(center)
 var frame := PanelContainer.new(); frame.add_theme_stylebox_override("panel",preload("res://scripts/ui_style.gd").frame(&"game",false,24)); center.add_child(frame)
 var content := VBoxContainer.new(); content.add_theme_constant_override("separation",20); frame.add_child(content)
 var label := Label.new(); label.text = "Has muerto"; label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; preload("res://scripts/ui_style.gd").set_font_size(label,28); content.add_child(label)
 for name in ["Reaparecer","Salir"]:
  var button := preload("res://scripts/menu_button.gd").new(); button.text = name; content.add_child(button)
  button.pressed.connect(respawn if name == "Reaparecer" else leave)
func eating() -> bool: return food_uid > 0
func dying() -> bool: return death_elapsed >= 0
func eat(index: int, quick: bool) -> bool:
 if eating() or dying() or game.working or game.interaction_motion.picking_up() or game.locomotion.airborne() or game.locomotion.sliding(): return false
 var storage: Array = game.bag.quick_slots if quick else game.bag.slots
 if index < 0 or index >= storage.size() or storage[index].is_empty(): return false
 var item: Dictionary = storage[index]
 if game.bag.DEFINITIONS[item.id].get("kcal",0) <= 0: return false
 food_uid = item.uid; food_id = item.id; food_elapsed = 0
 game.equipping = false; game.running = false; game.inventory_panel.hide()
 game.full_avatar.update_pose(0)
 return true
func advance(delta: float) -> void:
 if dying():
  death_elapsed = minf(DEATH_SECONDS,death_elapsed+maxf(0,delta))
  game.full_avatar.update_pose(0)
  if death_elapsed >= DEATH_SECONDS: panel.show()
  return
 if not eating(): return
 food_elapsed = minf(EAT_SECONDS,food_elapsed+maxf(0,delta))
 if food_elapsed < EAT_SECONDS: return
 var location: Dictionary = game.bag.location(food_uid)
 if location.get("kind") in [&"bag",&"quick"]:
  var result: Dictionary = game.nutrition.consume(game.bag,location.index,location.kind == &"quick")
  game.feedback = result.message; game.feedback_time = 2
 food_uid = -1; food_id = &""
 game.equipping = game.bag.held_id() != &""; game.equip_elapsed = 0
 if game.equipping: game.interaction_motion.draw_object()
 game.inventory_panel.refresh(); game.update_hud()
func die() -> void:
 if dying(): return
 food_uid = -1; food_id = &""
 death_armor = game.bag.equipment[&"torso"].get("id",&"")
 death_elapsed = 0; game.cancel_work(); game.equipping = false; game.running = false
 game.locomotion.reset(); game.interaction_motion.reset()
 game.inventory_panel.hide(); game.world_map.hide(); game.item_catalog.hide(); game.workbenches.window.hide(); game.workbenches.cancel_placement()
 game.loot.close_window()
 for arrow in game.get_tree().get_nodes_in_group("player_arrows"): arrow.queue_free()
 game.full_avatar.update_pose(0)
func respawn() -> void:
 var unlocked: Dictionary = game.progression.skills.duplicate()
 game.progression.reset(); game.progression.skills = unlocked
 game.experience = 0; game.level = 1; game.skill_points = 0
 for i in game.bag.CAPACITY: game.bag.slots[i] = {}
 game.bag.quick_slots.assign([{},{},{},{},{},{}]); game.bag.active_quick_uid = -1; game.bag.held_tool = {}
 for slot in game.bag.EQUIPMENT_SLOTS: game.bag.equipment[slot] = {}
 game.nutrition.reset()
 game.player = Vector2.ZERO; game.ground_height = 0; game.rock_support = game.world.NO_SUPPORT
 game.hut.inside = false; game.hut.apply_visibility()
 game.locomotion.reset(); game.movement.reset(); game.interaction_motion.reset(); game.pickup_cell = game.resources.NONE
 game.last_tool_uid = -1; game.weapon_timer = 0
 death_elapsed = -1; death_armor = &""; panel.hide()
 game.update_camera_position(); game.full_avatar.reset(); game.inventory_panel.refresh(); game.update_hud()
func leave() -> void: game.main_menu_requested.emit()

func reset() -> void:
 food_uid = -1; food_id = &""; food_elapsed = 0
 death_elapsed = -1; death_armor = &""
 if panel != null: panel.hide()
