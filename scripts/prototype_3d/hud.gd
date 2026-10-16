extends Control
## Reuses the approved frames and icons; scaling never changes click coordinates.
const Style=preload("res://scripts/ui_style.gd")
const Settings=preload("res://scripts/prototype_3d/settings_panel.gd")
const Icons=preload("res://scripts/prototype_3d/item_icons.gd")
var game
var life:Label
var food:Label
var water:Label
var weight:Label
var clock:Label
var level:Label
var message:Label
var gear:Button
var pause_button:Button
var quick:=Control.new()
var slots:Array[TextureRect]=[]
var slot_frames:Array[Panel]=[]
var map_frame:=Panel.new()
var map_view:Control
var skills:=Panel.new()
var ability_buttons:Array[Button]=[]
var amounts:Array[Label]=[]
func configure(owner_game) -> void:
 game=owner_game;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE
 theme=Style.theme()
 life=label(Vector2(160,40));food=label(Vector2(180,40));water=label(Vector2(180,40));weight=label(Vector2(120,28));clock=label(Vector2(180,32));level=label(Vector2(120,32))
 var life_icon:=TextureRect.new();life_icon.texture=load("res://assets/ui/styles/life_icon.png");life_icon.position=Vector2(8,8);life_icon.size=Vector2(25,25);life_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;life_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;life.add_child(life_icon)
 add_child(map_frame);map_frame.size=Vector2(190,194);map_frame.add_theme_stylebox_override("panel",Style.frame());map_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
 map_view=preload("res://scripts/prototype_3d/map_view.gd").new();map_view.game=game;map_frame.add_child(map_view);map_view.position=Vector2(10,28);map_view.size=Vector2(170,156)
 var map_title:=Label.new();map_title.text="MAPA";map_title.position=Vector2(10,3);map_frame.add_child(map_title)
 var map_button:=Button.new();map_button.position=Vector2(155,2);map_button.size=Vector2(28,25);map_button.icon=load("res://assets/ui/styles/map_icon.png");map_button.expand_icon=true;map_button.pressed.connect(game.toggle_map);map_frame.add_child(map_button)
 add_child(skills);skills.size=Vector2(246,66);skills.add_theme_stylebox_override("panel",Style.frame());skills.mouse_filter=Control.MOUSE_FILTER_IGNORE
 for i in 4:
  var slot:=Panel.new();slot.position=Vector2(6+i*60,6);slot.size=Vector2(54,54);slot.add_theme_stylebox_override("panel",Style.frame());skills.add_child(slot)
  if i<2:
   var button:=Button.new();button.size=Vector2(54,54);button.text="Z" if i==0 else "X";Style.skin_button(button);slot.add_child(button)
   button.pressed.connect(game.activate_skill.bind(&"speed" if i==0 else &"power"));ability_buttons.append(button)
 message=Label.new();add_child(message);message.mouse_filter=Control.MOUSE_FILTER_IGNORE;Style.set_font_size(message,18)
 gear=icon_button("settings_icon",game.open_settings);pause_button=icon_button("pause_icon",game.toggle_pause)
 add_child(quick);quick.mouse_filter=Control.MOUSE_FILTER_IGNORE;quick.size=Vector2(396,66)
 for i in 6:
  var frame:=Panel.new();frame.size=Vector2(62,66);frame.position=Vector2(i*66,0);frame.add_theme_stylebox_override("panel",Style.frame());frame.mouse_filter=Control.MOUSE_FILTER_IGNORE;quick.add_child(frame);slot_frames.append(frame)
  var icon:=TextureRect.new();icon.position=Vector2(7,15);icon.size=Vector2(48,44);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame.add_child(icon);slots.append(icon)
  var key:=Label.new();key.text=str(i+1);key.position=Vector2(6,0);key.mouse_filter=Control.MOUSE_FILTER_IGNORE;Style.set_font_size(key,14);frame.add_child(key)
  var amount:=Label.new();amount.position=Vector2(25,43);amount.size=Vector2(33,20);amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;amount.mouse_filter=Control.MOUSE_FILTER_IGNORE;Style.set_font_size(amount,12);frame.add_child(amount);amounts.append(amount)
 game.settings.changed.connect(fit);get_viewport().size_changed.connect(fit);fit()
func label(dimensions:Vector2) -> Label:
 var result:=Label.new();result.size=dimensions;result.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;result.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 result.add_theme_stylebox_override("normal",Style.frame());result.mouse_filter=Control.MOUSE_FILTER_IGNORE;Style.set_font_size(result,20);add_child(result);return result
func icon_button(kind:String,callback:Callable) -> Button:
 var button:=Button.new();button.size=Vector2(50,48);button.icon=load("res://assets/ui/styles/"+kind+".png");button.expand_icon=true;button.pressed.connect(callback);Style.skin_button(button);add_child(button);return button
func fit() -> void:
 var factor:=Settings.hud_scale(game.settings.values.hud_size);var screen:=get_viewport_rect().size
 for node in [life,food,water,weight,clock,level,gear,pause_button,quick,map_frame,skills]:node.scale=Vector2.ONE*factor
 gear.position=Vector2(18,18);pause_button.position=gear.position+Vector2(62*factor,0)
 life.position=Vector2(18,screen.y-18-120*factor);food.position=life.position+Vector2(0,40*factor);water.position=food.position+Vector2(0,40*factor)
 message.position=life.position-Vector2(0,32)
 quick.position=Vector2((screen.x-(quick.size.x+14+skills.size.x)*factor)/2,screen.y-18-quick.size.y*factor)
 skills.position=quick.position+Vector2((quick.size.x+14)*factor,0)
 weight.position=Vector2(screen.x-18-weight.size.x*factor,screen.y-18-weight.size.y*factor)
 map_frame.position=Vector2(screen.x-18-map_frame.size.x*factor,18)
 clock.position=map_frame.position+Vector2(0,202*factor);level.position=map_frame.position-Vector2(132*factor,0)
func _process(_delta:float) -> void:
 if game==null:return
 life.text="%d / %d"%[int(game.player_health),int(game.progression.max_health())];food.text="%d kcal"%game.nutrition.calories_today
 water.text="Agua: %d ml"%roundi(game.nutrition.hydration_ml);weight.text="60 kg";clock.text=game.day_cycle.clock_text();level.text="Nivel %d"%game.level
 message.text=game.status.text
 for i in slots.size():
  var item:Dictionary=game.bag.quick_slots[i]
  slots[i].texture=Icons.for_item(item) if not item.is_empty() else null
  amounts[i].text=str(item.quantity) if item.get("quantity",0)>1 else ""
  slot_frames[i].modulate=Color(1.2,1.2,1.08) if game.player.equipped and item.get("uid",-2)==game.bag.active_quick_uid else Color.WHITE
 for i in ability_buttons.size():
  var id:StringName=&"speed" if i==0 else &"power"
  var remaining:float=game.progression.cooldowns[id]
  ability_buttons[i].disabled=game.progression.skills[id]==0 or remaining>0 or game.player_health<=0
  ability_buttons[i].text=("Z" if i==0 else "X")+("\n%.0fs"%ceilf(remaining) if remaining>0 else "")
  ability_buttons[i].tooltip_text=game.progression.SKILLS[id].name
func refresh() -> void:_process(0)
