extends Control
## Release HUD artwork; input, counters and uniform HUD scaling stay shared.
const Frames=preload("res://scripts/prototype_3d/hud_frames.gd")
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
var fps_counter:Label
var fps_elapsed:=0.0
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
 theme=Style.theme();texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 life=label(&"life",180);food=label(&"food",180);water=label(&"water",180);weight=label(&"weight",120);clock=label(&"clock",180);level=label(&"level",120)
 fps_counter=label(&"level",120);fps_counter.name="FPSCounter"
 for counter in [water,clock,level,fps_counter]:Style.set_font_size(counter,18)
 var life_icon:=TextureRect.new();life_icon.texture=load("res://assets/ui/styles/life_icon.png");life_icon.position=Vector2(8,8);life_icon.size=Vector2(25,25);life_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;life_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;life.add_child(life_icon)
 add_child(map_frame);map_frame.size=Frames.dimensions(&"map",190);map_frame.add_theme_stylebox_override("panel",Frames.frame(&"map"));map_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
 map_view=preload("res://scripts/prototype_3d/map_view.gd").new();map_view.game=game;map_frame.add_child(map_view);map_view.position=Vector2(14,32);map_view.size=map_frame.size-Vector2(28,46)
 var map_title:=Label.new();map_title.text="MAPA";map_title.position=Vector2(16,13);Style.set_font_size(map_title,12);map_title.mouse_filter=Control.MOUSE_FILTER_IGNORE;map_frame.add_child(map_title)
 var map_button:=Button.new();map_button.name="HUDMapButton";map_button.position=Vector2(164,0);map_button.size=Vector2(26,26);map_button.tooltip_text="Mapa (M)";Frames.transparent_button(map_button);map_button.pressed.connect(game.toggle_map);map_frame.add_child(map_button)
 add_child(skills);skills.size=Vector2(246,66);skills.add_theme_stylebox_override("panel",Frames.frame(&"skills"));skills.mouse_filter=Control.MOUSE_FILTER_IGNORE
 for i in 4:
  var slot:=Panel.new();slot.position=Vector2(6+i*60,6);slot.size=Vector2(54,54);slot.add_theme_stylebox_override("panel",StyleBoxEmpty.new());slot.mouse_filter=Control.MOUSE_FILTER_IGNORE;skills.add_child(slot)
  if i<2:
   var button:=Button.new();button.size=Vector2(54,54);button.text="Z" if i==0 else "X";Frames.transparent_button(button);slot.add_child(button)
   button.pressed.connect(game.activate_skill.bind(&"speed" if i==0 else &"power"));ability_buttons.append(button)
 message=Label.new();add_child(message);message.mouse_filter=Control.MOUSE_FILTER_IGNORE;Style.set_font_size(message,18)
 gear=icon_button("settings_icon",&"settings",game.open_settings);pause_button=icon_button("pause_icon",&"pause",game.toggle_pause)
 add_child(quick);quick.mouse_filter=Control.MOUSE_FILTER_IGNORE;quick.size=Frames.dimensions(&"quick",396)
 for i in 6:
  var frame:=Panel.new();frame.size=Vector2(66,quick.size.y);frame.position=Vector2(i*66,0);frame.add_theme_stylebox_override("panel",Frames.quick_slot(i));frame.mouse_filter=Control.MOUSE_FILTER_IGNORE;quick.add_child(frame);slot_frames.append(frame)
  var icon:=TextureRect.new();icon.position=Vector2(7,15);icon.size=Vector2(48,44);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame.add_child(icon);slots.append(icon)
  var key:=Label.new();key.text=str(i+1);key.position=Vector2(7,5);key.mouse_filter=Control.MOUSE_FILTER_IGNORE;Style.set_font_size(key,14);frame.add_child(key)
  var amount:=Label.new();amount.position=Vector2(25,43);amount.size=Vector2(33,20);amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;amount.mouse_filter=Control.MOUSE_FILTER_IGNORE;Style.set_font_size(amount,12);frame.add_child(amount);amounts.append(amount)
 game.settings.changed.connect(fit);get_viewport().size_changed.connect(fit);fit()
func label(kind:StringName,width:float) -> Label:
 var result:=Label.new();result.size=Frames.dimensions(kind,width);result.clip_text=true;result.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;result.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 result.add_theme_stylebox_override("normal",Frames.frame(kind));result.mouse_filter=Control.MOUSE_FILTER_IGNORE;Style.set_font_size(result,20);add_child(result);return result
func icon_button(kind:String,frame_kind:StringName,callback:Callable) -> Button:
 var button:=Button.new();button.size=Vector2(50,48);button.icon=load("res://assets/ui/styles/"+kind+".png");button.expand_icon=true;button.pressed.connect(callback);Frames.skin_button(button,frame_kind);add_child(button);return button
func fit() -> void:
 var factor:=Settings.hud_scale(game.settings.values.hud_size);var screen:=get_viewport_rect().size
 for node in [life,food,water,weight,clock,level,fps_counter,gear,pause_button,quick,map_frame,skills]:node.scale=Vector2.ONE*factor
 gear.position=Vector2(18,18);pause_button.position=gear.position+Vector2(62*factor,0)
 water.position=Vector2(18,screen.y-18-water.size.y*factor)
 food.position=water.position-Vector2(0,(food.size.y+4)*factor)
 life.position=food.position-Vector2(0,(life.size.y+4)*factor)
 message.position=life.position-Vector2(0,32)
 quick.position=Vector2((screen.x-(quick.size.x+14+skills.size.x)*factor)/2,screen.y-18-quick.size.y*factor)
 skills.position=quick.position+Vector2((quick.size.x+14)*factor,0)
 weight.position=Vector2(screen.x-18-weight.size.x*factor,screen.y-18-weight.size.y*factor)
 map_frame.position=Vector2(screen.x-18-map_frame.size.x*factor,18)
 clock.position=map_frame.position+Vector2(0,(map_frame.size.y+8)*factor);level.position=map_frame.position-Vector2(132*factor,0)
 fps_counter.position=level.position-Vector2((fps_counter.size.x+12)*factor,0)
 fps_counter.visible=game.settings.values.show_fps
 if fps_counter.visible:fps_counter.text="FPS %d"%Engine.get_frames_per_second()
 fps_elapsed=0.0
func _process(delta:float) -> void:
 if game==null:return
 if fps_counter.visible:
  fps_elapsed+=delta
  if fps_elapsed>=0.25:
   fps_counter.text="FPS %d"%Engine.get_frames_per_second();fps_elapsed=fmod(fps_elapsed,0.25)
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
