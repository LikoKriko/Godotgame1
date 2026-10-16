extends Node
## Shared item records move atomically from eight-slot remains into real storage.
const Style=preload("res://scripts/ui_style.gd")
const Icons=preload("res://scripts/prototype_3d/item_icons.gd")
var game
var corpse
var selected:=-1
var window:PanelContainer
var grid:GridContainer
var count_label:Label
var actions:HBoxContainer
func configure(owner_game,parent_ui:Control) -> void:
 game=owner_game;window=PanelContainer.new();window.theme=Style.theme();window.add_theme_stylebox_override("panel",Style.frame());parent_ui.add_child(window);window.hide()
 var column:=VBoxContainer.new();window.add_child(column)
 var heading:=HBoxContainer.new();column.add_child(heading)
 var title:=Label.new();title.text="Restos del enemigo";title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;Style.set_font_size(title,16);heading.add_child(title)
 var close:=preload("res://scripts/menu_button.gd").new();close.text="×";close.pressed.connect(close_window);heading.add_child(close)
 count_label=Label.new();Style.set_font_size(count_label,13);column.add_child(count_label)
 grid=GridContainer.new();grid.columns=4;column.add_child(grid)
 for i in 8:
  var button:=Button.new();button.expand_icon=true;button.pressed.connect(choose.bind(i));Style.skin_button(button);grid.add_child(button)
 actions=HBoxContainer.new();column.add_child(actions)
 for caption in ["Recoger","Tirar"]:
  var button:=preload("res://scripts/menu_button.gd").new();button.text=caption;button.pressed.connect(collect if caption=="Recoger" else drop_selected);actions.add_child(button)
 get_viewport().size_changed.connect(fit)
func fit() -> void:
 var inventory_size:Vector2=game.inventory_panel.panel.size*game.inventory_panel.panel.scale
 var dimensions:Vector2=inventory_size*sqrt(0.3)
 for button in grid.get_children():button.custom_minimum_size=Vector2(maxf(42,(dimensions.x-60)/4),maxf(42,(dimensions.y-130)/2))
 window.size=dimensions;window.position=(get_viewport().get_visible_rect().size-window.size)*0.5
func occupied() -> int:
 return game.bag.slots.filter(func(item):return not item.is_empty()).size()
func open_window(target) -> bool:
 if not is_instance_valid(target) or target.health>0 or target.death_elapsed<2:return false
 corpse=target;selected=-1;game.cancel_work();game.paused=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 window.show();refresh();fit();return true
func close_window() -> void:
 window.hide();corpse=null;selected=-1
 if game.paused and not game.pause_panel.visible:game.resume_world()
func refresh() -> void:
 if not is_instance_valid(corpse):close_window();return
 count_label.text="Espacio en tu inventario: %d / %d"%[occupied(),game.bag.CAPACITY]
 for i in 8:
  var item:Dictionary=corpse.loot_slots[i];var button:Button=grid.get_child(i)
  button.icon=Icons.for_item(item);button.disabled=item.is_empty();button.text=str(item.get("quantity",0)) if item.get("quantity",0)>1 else ""
  button.tooltip_text=game.bag.DEFINITIONS[item.id].name if not item.is_empty() else "Vacío"
  button.add_theme_constant_override("icon_max_width",maxi(30,int(button.custom_minimum_size.x*0.65)))
 actions.visible=selected>=0 and not corpse.loot_slots[selected].is_empty()
func choose(index:int) -> void:selected=index;refresh()
func store(item:Dictionary) -> bool:
 if item.is_empty() or not game.bag.can_add(item.id,item.quantity):return false
 if game.bag.DEFINITIONS[item.id].stack==1:
  for i in game.bag.CAPACITY:
   if game.bag.slots[i].is_empty():
    var saved:Dictionary=item.duplicate(true);saved.uid=game.bag.next_uid;game.bag.next_uid+=1;game.bag.slots[i]=saved;return true
  return false
 return game.bag.add(item.id,item.quantity)
func collect() -> void:
 if not is_instance_valid(corpse) or selected<0:return
 var item:Dictionary=corpse.loot_slots[selected]
 if not store(item):count_label.text="Espacio en tu inventario: %d / %d · mochila llena"%[occupied(),game.bag.CAPACITY];return
 corpse.loot_slots[selected]={};selected=-1;refresh();game.inventory_panel.refresh();game.update_hud()
func drop_selected() -> void:
 if not is_instance_valid(corpse) or selected<0:return
 var item:Dictionary=corpse.loot_slots[selected]
 if item.is_empty():return
 var point:Vector3=corpse.global_position+Vector3(0.55,0,0.4)
 spawn_drop(item,point);corpse.loot_slots[selected]={};selected=-1;refresh()
func spawn_drop(item:Dictionary,point:Vector3,settle:bool=true) -> Node3D:
 var drop:=preload("res://scripts/prototype_3d/world_item.gd").new();game.add_child(drop);drop.configure(item);drop.global_position=point
 if settle:drop.settle_on_ground()
 return drop
func pickup(drop:Node3D,animate:bool=true) -> bool:
 if drop.item.is_empty():return false
 if game.player.equipped:game.status.text="Necesitas las manos libres para recogerlo.";return false
 if not store(drop.item):game.status.text="La mochila está llena.";return false
 drop.item={};drop.collision_layer=0;drop.hide();drop.queue_free()
 if animate:game.player.play_preview(&"",&"pickup")
 game.inventory_panel.refresh();game.update_hud();return true
func _process(_delta:float) -> void:
 if window.visible and not is_instance_valid(corpse):close_window()
func _input(event:InputEvent) -> void:
 if window.visible and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
  close_window();get_viewport().set_input_as_handled()
