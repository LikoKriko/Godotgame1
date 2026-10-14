extends Node2D
## Eight-slot corpse storage and physical ground drops, never linked quick slots.
var game
var window: PanelContainer
var grid: GridContainer
var count_label: Label
var action_row: HBoxContainer
var corpse
var selected := -1
var pending_drop_uid := -1
var drop_committed := false
var drops: Array[Dictionary] = []
func configure(owner_game, canvas: CanvasLayer) -> void:
 game = owner_game
 z_index = 10
 window = PanelContainer.new(); window.theme = preload("res://scripts/ui_style.gd").theme()
 window.add_theme_stylebox_override("panel",preload("res://scripts/ui_style.gd").frame(&"game",false,24)); canvas.add_child(window); window.hide()
 var body := VBoxContainer.new(); body.add_theme_constant_override("separation",8); window.add_child(body)
 var heading := HBoxContainer.new(); body.add_child(heading)
 var title := Label.new(); title.text = "Restos del enemigo"; title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; preload("res://scripts/ui_style.gd").set_font_size(title,16); heading.add_child(title)
 var close := preload("res://scripts/menu_button.gd").new(); close.text = "×"; close.pressed.connect(close_window); heading.add_child(close)
 count_label = Label.new(); preload("res://scripts/ui_style.gd").set_font_size(count_label,13); body.add_child(count_label)
 grid = GridContainer.new(); grid.columns = 4; grid.size_flags_vertical = Control.SIZE_EXPAND_FILL; body.add_child(grid)
 for i in 8:
  var button := Button.new(); button.expand_icon = true; button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; button.size_flags_vertical = Control.SIZE_EXPAND_FILL
  button.pressed.connect(choose.bind(i)); grid.add_child(button)
  var artwork := TextureRect.new(); artwork.name = "Artwork"; artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  artwork.offset_left = 16; artwork.offset_top = 16; artwork.offset_right = -16; artwork.offset_bottom = -16
  artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  artwork.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE; button.add_child(artwork)
  var quantity := Label.new(); quantity.name = "Quantity"; quantity.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
  quantity.offset_left = -45; quantity.offset_top = -28; quantity.offset_right = -8; quantity.offset_bottom = -4
  quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE
  preload("res://scripts/ui_style.gd").set_font_size(quantity,13); button.add_child(quantity)
 action_row = HBoxContainer.new(); body.add_child(action_row)
 for label in ["Recoger","Tirar"]:
  var button := preload("res://scripts/menu_button.gd").new(); button.text = label; action_row.add_child(button)
  button.pressed.connect(collect if label == "Recoger" else drop_selected)
 game.get_viewport().size_changed.connect(fit)
func fit() -> void:
 if game.inventory_panel == null: return
 var inventory_size: Vector2 = game.inventory_panel.panel.size*game.inventory_panel.panel.scale
 var dimensions := inventory_size*sqrt(0.3)
 var available: Vector2 = game.get_viewport_rect().size
 window.size = dimensions; window.position = (available-window.size)/2
 for button in grid.get_children(): button.custom_minimum_size = Vector2(maxf(32,(dimensions.x-60)/4),maxf(32,(dimensions.y-145)/2))
func occupied() -> int:
 var result := 0
 for item in game.bag.slots:
  if not item.is_empty(): result += 1
 return result
func open_window(target) -> void:
 corpse = target; selected = -1
 game.cancel_work(); game.inventory_panel.hide(); game.world_map.hide(); game.item_catalog.hide(); game.workbenches.window.hide()
 window.show(); refresh(); fit()
func close_window() -> void:
 if window != null: window.hide()
 corpse = null; selected = -1
func refresh() -> void:
 if not is_instance_valid(corpse): close_window(); return
 count_label.text = "Espacio en tu inventario: %d / %d" % [occupied(),game.bag.CAPACITY]
 for i in 8:
  var item: Dictionary = corpse.loot_slots[i]; var button: Button = grid.get_child(i)
  button.get_node("Artwork").texture = preload("res://scripts/item_icons.gd").for_item(item)
  button.get_node("Quantity").text = str(item.quantity) if not item.is_empty() else ""
  button.tooltip_text = game.bag.DEFINITIONS[item.id].name if not item.is_empty() else "Vacío"
  button.disabled = item.is_empty()
  button.add_theme_constant_override("icon_max_width",maxi(28,floori(button.custom_minimum_size.x*0.65)))
 action_row.visible = selected >= 0 and not corpse.loot_slots[selected].is_empty()
func choose(index: int) -> void: selected = index; refresh()
func store(item: Dictionary) -> bool:
 if not game.bag.can_add(item.id,item.quantity): return false
 if game.bag.DEFINITIONS[item.id].stack == 1:
  for i in game.bag.CAPACITY:
   if game.bag.slots[i].is_empty():
    var saved: Dictionary = item.duplicate(true); saved.uid = game.bag.next_uid; game.bag.next_uid += 1; game.bag.slots[i] = saved
    return true
  return false
 return game.bag.add(item.id,item.quantity)
func collect() -> void:
 if not is_instance_valid(corpse) or selected < 0: return
 var item: Dictionary = corpse.loot_slots[selected]
 if item.is_empty(): return
 if not store(item): count_label.text = "Espacio en tu inventario: %d / %d · mochila llena" % [occupied(),game.bag.CAPACITY]; return
 corpse.loot_slots[selected] = {}; selected = -1; refresh(); game.inventory_panel.refresh(); game.update_hud()
func drop_selected() -> void:
 if not is_instance_valid(corpse) or selected < 0: return
 var item: Dictionary = corpse.loot_slots[selected]
 if item.is_empty(): return
 drops.append({"item":item.duplicate(true),"point":corpse.position+Vector2(22+drops.size()%3*8,20)})
 corpse.loot_slots[selected] = {}; selected = -1; refresh(); queue_redraw()
func interact(aim: Vector2) -> bool:
 for creature in get_tree().get_nodes_in_group("creatures"):
  if creature.health > 0 or creature.death_elapsed < 2 or not creature.visible: continue
  if creature.contains_point(aim) and game.player.distance_to(creature.position) <= 64: open_window(creature); return true
 for i in drops.size():
  var entry: Dictionary = drops[i]
  if aim.distance_to(entry.point) > 16 or game.player.distance_to(entry.point) > 64: continue
  if game.bag.held_id() != &"": game.feedback = "Deja las manos libres para recoger este objeto."; game.feedback_time = 2; return true
  pending_drop_uid = entry.item.uid; drop_committed = false
  game.pickup_aim = entry.point; game.pickup_cell = game.resources.NONE
  game.interaction_motion.pick_up(); return true
 return false
func _process(_delta: float) -> void:
 if window.visible and not is_instance_valid(corpse): close_window()
 visible = game.hut == null or not game.hut.inside
func _draw() -> void:
 for entry in drops:
  var icon: Texture2D = preload("res://scripts/item_icons.gd").for_item(entry.item)
  if icon != null: draw_texture_rect(icon,Rect2(entry.point-Vector2(10,10),Vector2(20,20)),false)

func advance_pickup() -> void:
 if pending_drop_uid < 0: return
 if not game.interaction_motion.picking_up(): pending_drop_uid = -1; return
 if drop_committed or game.interaction_motion.pickup_phase() < 0.5: return
 drop_committed = true
 for i in drops.size():
  var entry: Dictionary = drops[i]
  if entry.item.uid != pending_drop_uid: continue
  if game.bag.held_id() != &"" or game.player.distance_to(entry.point) > 64: break
  if not store(entry.item): game.feedback = "La mochila está llena."; game.feedback_time = 2; break
  drops.remove_at(i); game.inventory_panel.refresh(); game.update_hud(); queue_redraw(); break
 pending_drop_uid = -1

func reset() -> void:
 close_window(); drops.clear(); pending_drop_uid = -1; drop_committed = false; queue_redraw()
