extends Node3D
## Playable 3D world; the session owns the title screen and manual save lifecycle.
signal main_menu_requested
signal world_ready
signal load_failed(message:String)
signal loading_changed(value:float)
const Save=preload("res://scripts/prototype_3d/save_game.gd")
var world_seed:=73129
var initial_state:Dictionary={}
var save_path:=Save.PATH
var save_button:Button
var return_button:Button
var player: CharacterBody3D
var camera_rig: Node3D
var paused := false
var bag = preload("res://scripts/inventory.gd").new()
var status: Label
var pause_panel: Control
var message_time := 0.0
var settings=preload("res://scripts/game_settings.gd").new()
var nutrition=preload("res://scripts/nutrition.gd").new()
var day_cycle=preload("res://scripts/day_cycle.gd").new()
var parry=preload("res://scripts/parry.gd").new()
var player_health:=20.0
var level:=1
var hud:Control
var settings_panel:PanelContainer
var settings_holder:CenterContainer
var settings_from_pause:=false
var pause_title:Label
var continue_button:Button
var respawn_button:Button
var main_sun:DirectionalLight3D
var world_ambient:Environment
var map_holder:CenterContainer
var inventory_panel:Control
var item_catalog:Control
var workbenches=null
var corpse_loot:Node
var styled_hud:Control
var progression=preload("res://scripts/progression.gd").new()
var skill_points:=0
var experience:=0
var pending_consumption:Dictionary={}
var terrain:Node3D
var combat_effects:Node3D
var use_test_layout:=false
var world_bounds:=Rect2(-24,-24,48,48)
var environment_content:Node3D
var loading_state:=false
var loading_screen:Control
var loading_progress:ProgressBar
func _ready() -> void:
 # The 2D cursor autoload would override captured mouse mode each frame.
 if not initial_state.is_empty():world_seed=initial_state.seed
 var cursor := get_tree().root.get_node_or_null("GameCursor")
 if cursor != null: cursor.set_process(false); cursor.hide()
 for overlay in get_tree().root.get_children():
  if overlay.name == &"GameCursor": continue
  if overlay.get("name") == &"DayZeroCursor": overlay.hide(); overlay.process_mode = Node.PROCESS_MODE_DISABLED
 Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
 settings.load_settings()
 preload("res://scripts/prototype_3d/settings_panel.gd").apply_runtime(settings,get_viewport())
 progression.reset()
 bag.reset()
 bag.move_item(&"quick",5,&"quick",0)
 if not use_test_layout:world_bounds=Rect2(-42,-28,84,56)
 build_environment()
 combat_effects=preload("res://scripts/prototype_3d/combat_effects.gd").new();add_child(combat_effects);combat_effects.game=self
 player = preload("res://scripts/prototype_3d/player.gd").new(); add_child(player); player.configure(self); player.position = Vector3(0,0.2,2.0)
 camera_rig = preload("res://scripts/prototype_3d/shoulder_camera.gd").new(); add_child(camera_rig); camera_rig.configure(self,player); camera_rig.update(1.0)
 build_ui()
 var enemy:=preload("res://scripts/prototype_3d/young_enemy.gd").new();add_child(enemy);enemy.position=Vector3(7,0.2,-4);enemy.configure(self)
 if not use_test_layout:call_deferred("generate_content")
func build_environment() -> void:
 var environment := WorldEnvironment.new(); var environment_settings := Environment.new()
 environment_settings.background_mode = Environment.BG_COLOR; environment_settings.background_color = Color("809495")
 environment_settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; environment_settings.ambient_light_color = Color("b2b59b"); environment_settings.ambient_light_energy = 0.6
 environment.environment = environment_settings;world_ambient=environment_settings; add_child(environment)
 var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-52,-35,0); sun.light_color = Color("fff1d6"); sun.light_energy = 1.2; sun.shadow_enabled = true; add_child(sun);main_sun=sun
 var ground := StaticBody3D.new(); add_child(ground)
 var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(world_bounds.size.x,0.4,world_bounds.size.y); shape.shape = box; shape.position.y = -0.2; ground.add_child(shape)
 if not use_test_layout:
  for axis in 2:
   for sign_side in [-1,1]:
    var boundary:=StaticBody3D.new();add_child(boundary);var limit:=CollisionShape3D.new();var wall_shape:=BoxShape3D.new();wall_shape.size=Vector3(0.3,20,world_bounds.size.y) if axis==0 else Vector3(world_bounds.size.x,20,0.3);limit.shape=wall_shape;limit.position=Vector3(sign_side*world_bounds.size.x*0.5,10,0) if axis==0 else Vector3(0,10,sign_side*world_bounds.size.y*0.5);boundary.add_child(limit);boundary.set_meta("physical_height",20.0)
 terrain=preload("res://scripts/prototype_3d/terrain_chunks.gd").new();add_child(terrain)
 var units:float=preload("res://scripts/prototype_3d/terrain_chunks.gd").METRES_PER_UNIT
 terrain.configure(world_seed,null,Rect2(world_bounds.position/units,world_bounds.size/units))
 terrain.update_observer(Vector3.ZERO)
 if use_test_layout:
  var fixture=load("res://tests/fixtures/prototype_layout.gd").new();add_child(fixture);fixture.populate(self)
func build_ui() -> void:
 var layer := CanvasLayer.new(); add_child(layer)
 var root := Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(root)
 var aim:=preload("res://scripts/prototype_3d/reticle.gd").new();aim.name="Reticle";root.add_child(aim)
 status = Label.new();status.hide();status.text="";root.add_child(status)
 hud=preload("res://scripts/prototype_3d/hud.gd").new();root.add_child(hud);hud.configure(self)
 pause_panel = CenterContainer.new(); pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(pause_panel); pause_panel.hide()
 var frame := PanelContainer.new(); frame.theme = preload("res://scripts/ui_style.gd").theme(); pause_panel.add_child(frame)
 var buttons := VBoxContainer.new(); buttons.add_theme_constant_override("separation",16); frame.add_child(buttons)
 pause_title=Label.new();pause_title.text="PAUSA";buttons.add_child(pause_title)
 for caption in ["Continuar","Guardar partida","Configuración","Reaparecer","Menú principal","Salir"]:
  var button := preload("res://scripts/menu_button.gd").new(); button.text = caption; button.set_meta("caption",caption);buttons.add_child(button)
  if caption=="Continuar":continue_button=button;button.pressed.connect(toggle_pause)
  elif caption=="Configuración":button.pressed.connect(open_settings)
  elif caption=="Guardar partida":save_button=button;button.pressed.connect(save_current_game)
  elif caption=="Reaparecer":respawn_button=button;button.pressed.connect(respawn);button.hide()
  elif caption=="Menú principal":return_button=button;button.pressed.connect(request_main_menu)
  else:button.pressed.connect(get_tree().quit)
 var save_message:=Label.new();save_message.name="SaveMessage";save_message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;save_message.custom_minimum_size.x=320;preload("res://scripts/ui_style.gd").set_font_size(save_message,14);buttons.add_child(save_message)
 settings_holder=CenterContainer.new();settings_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(settings_holder);settings_holder.hide()
 settings_panel=preload("res://scripts/prototype_3d/settings_panel.gd").new();settings_holder.add_child(settings_panel);settings_panel.configure(self);settings_panel.closed.connect(close_settings)
 map_holder=CenterContainer.new();map_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(map_holder);map_holder.hide()
 var map_panel:=PanelContainer.new();map_panel.theme=preload("res://scripts/ui_style.gd").theme();map_holder.add_child(map_panel)
 var map_layout:=VBoxContainer.new();map_panel.add_child(map_layout)
 var title:=Label.new();title.text="MAPA";map_layout.add_child(title)
 var overview:=preload("res://scripts/prototype_3d/map_view.gd").new();overview.game=self;overview.custom_minimum_size=Vector2(560,560);map_layout.add_child(overview)
 var close_map:=preload("res://scripts/menu_button.gd").new();close_map.text="Cerrar · M";close_map.pressed.connect(toggle_map);map_layout.add_child(close_map)
 inventory_panel=preload("res://scripts/prototype_3d/inventory_panel.gd").new();root.add_child(inventory_panel);inventory_panel.configure(bag,self)
 inventory_panel.consume_requested.connect(consume_item)
 inventory_panel.equipment_changed.connect(sync_equipment)
 inventory_panel.visibility_changed.connect(func():if not inventory_panel.visible and paused and not pause_panel.visible and not settings_holder.visible:resume_world())
 item_catalog=preload("res://scripts/prototype_3d/item_catalog.gd").new();root.add_child(item_catalog);item_catalog.configure(self)
 item_catalog.visibility_changed.connect(func():if not item_catalog.visible and paused and not pause_panel.visible:resume_world())
 styled_hud=hud
 workbenches=preload("res://scripts/prototype_3d/workbenches.gd").new();add_child(workbenches);workbenches.configure(self,root)
 corpse_loot=preload("res://scripts/prototype_3d/corpse_loot.gd").new();add_child(corpse_loot);corpse_loot.configure(self,root)
 build_loading_screen(root)
func toggle_pause() -> void:
 if corpse_loot!=null and corpse_loot.window.visible:corpse_loot.close_window();return
 if workbenches!=null and workbenches.placing():workbenches.cancel_placement();return
 if workbenches!=null and workbenches.window.visible:workbenches.window.hide();return
 if inventory_panel!=null and inventory_panel.visible:inventory_panel.hide();return
 if item_catalog!=null and item_catalog.visible:item_catalog.hide();return
 if map_holder!=null and map_holder.visible:toggle_map();return
 if settings_holder.visible:close_settings();return
 if paused and player_health<=0:return
 paused = not paused; pause_panel.visible = paused
 pause_title.text="HAS MUERTO" if player_health<=0 else "PAUSA"
 continue_button.disabled=player_health<=0
 for button in pause_panel.find_children("*","Button",true,false):
  var caption:String=button.get_meta("caption","")
  button.visible=caption!="Reaparecer" if player_health>0 else caption in ["Reaparecer","Menú principal"]
 return_button.text="Salir" if player_health<=0 else "Menú principal"
 Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
func open_settings() -> void:
 settings_from_pause=paused;paused=true;pause_panel.hide();settings_holder.show();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func close_settings() -> void:
 settings_holder.hide();paused=settings_from_pause;pause_panel.visible=paused
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
func toggle_map() -> void:
 if map_holder.visible:map_holder.hide();paused=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 elif not paused:map_holder.show();paused=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func activate_parry() -> bool:
 if player.action_elapsed>=0 or player_health<=0 or parry.cooldown_remaining()>0:return false
 if not parry.activate():return false
 player.guard_point=Vector3.INF
 var nearest:=1.5
 for enemy in get_tree().get_nodes_in_group("prototype_enemies"):
  var distance:float=enemy.global_position.distance_to(player.global_position)
  if enemy.health>0 and distance<nearest:
   nearest=distance
   var pose:Dictionary=preload("res://scripts/prototype_3d/young_pose.gd").sample(&"attack",0.5,enemy.punch_left)
   player.guard_point=enemy.model.to_global(pose.arms[1 if enemy.punch_left else 0].end)
 player.begin_parry()
 if parry.used:player.model.confirm_parry()
 return true
func enemy_contact(attacker,damage:float,contact_time:float) -> void:
 if parry.impact(attacker,damage,contact_time):player.model.confirm_parry()
func _physics_process(delta:float) -> void:
 if paused:return
 terrain.update_observer(player.global_position)
 for hit in parry.advance(delta):player_health=maxf(0,player_health-hit.damage)
 progression.health=player_health;progression.advance(delta)
 if not pending_consumption.is_empty() and player.preview_state==&"":finish_consumption()
 if day_cycle.advance(delta)>0:nutrition.new_day()
 nutrition.advance(delta,day_cycle.day_seconds)
 refresh_daylight()
func refresh_daylight() -> void:
 var daylight:Dictionary=day_cycle.sun_state()
 main_sun.light_energy=daylight.elevation*1.2;main_sun.rotation_degrees=Vector3(-lerpf(18,76,daylight.elevation),lerpf(-70,70,daylight.progress),0)
 world_ambient.ambient_light_color=daylight.ambient;world_ambient.ambient_light_energy=lerpf(0.32,0.65,daylight.elevation)
func respawn() -> void:
 player_health=20;level=1;nutrition.reset();parry.reset()
 if workbenches!=null:workbenches.cancel_placement();workbenches.window.hide()
 skill_points=0;experience=0
 var preserved_skills:Dictionary=progression.skills.duplicate();progression.reset()
 for id in progression.skills:progression.skills[id]=1 if preserved_skills[id]>0 else 0
 pending_consumption.clear();player.preview_state=&"";player.pickup_target={};player.pickup_point=Vector3.INF
 bag.reset()
 for i in bag.slots.size():bag.slots[i]={}
 for i in bag.quick_slots.size():bag.quick_slots[i]={}
 bag.active_quick_uid=-1;player.equipped=false;player.death_elapsed=-1;player.action_elapsed=-1;player.bow_follow_elapsed=-1;player.equip_elapsed=-1;player.equip_recovery=0;player.parry_elapsed=-1;player.reset_motion_state();player.position=Vector3(0,0.2,2)
 player.pickup_recovery=0;player.model.wear({})
 paused=false;pause_panel.hide();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func request_main_menu() -> void:
 if main_menu_requested.get_connections().is_empty():get_tree().change_scene_to_file("res://scenes/prototype_3d/day_zero.tscn")
 else:main_menu_requested.emit()
func open_2d() -> void:
 if get_tree().root.get_node_or_null("GameCursor") == null:
  var cursor := preload("res://scripts/cursor_overlay.gd").new(); cursor.name = "GameCursor"; get_tree().root.add_child(cursor)
 get_tree().change_scene_to_file("res://scenes/day_zero.tscn")
func _unhandled_input(event: InputEvent) -> void:
 if loading_state:return
 if workbenches!=null and workbenches.placing():
  if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:workbenches.cancel_placement();get_viewport().set_input_as_handled()
  return
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode == KEY_ESCAPE: toggle_pause(); get_viewport().set_input_as_handled()
  elif event.keycode>=KEY_1 and event.keycode<=KEY_6 and not paused:player.select_quick(event.keycode-KEY_1)
  elif event.keycode==KEY_E and not paused:interact()
  elif event.keycode == KEY_F and not paused:activate_parry()
  elif event.keycode == KEY_M:toggle_map()
  elif event.keycode == KEY_I and not pause_panel.visible:toggle_inventory(0)
  elif event.keycode == KEY_T and not pause_panel.visible:toggle_inventory(1)
  elif event.keycode == KEY_K and not pause_panel.visible:toggle_catalog()
  elif event.keycode == KEY_Z and not paused:activate_skill(&"speed")
  elif event.keycode == KEY_X and not paused:activate_skill(&"power")
 if paused: return
 if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: camera_rig.look(event.relative)
 if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: player.strike()
func target_owner(collider):
 return collider.get_meta("creature",collider.get_meta("resource",collider))
func target_still_at(result:Dictionary,owner_node) -> bool:
 var query:=PhysicsShapeQueryParameters3D.new();var sphere:=SphereShape3D.new();sphere.radius=0.07
 query.shape=sphere;query.transform=Transform3D(Basis.IDENTITY,result.position);query.collision_mask=25;query.collide_with_areas=true
 for hit in get_world_3d().direct_space_state.intersect_shape(query):
  if target_owner(hit.collider)==owner_node:return true
 return false
func resolve_hit(click_target=null) -> bool:
 var result:Dictionary=camera_rig.target() if click_target==null else click_target
 if result.is_empty() or not is_instance_valid(result.collider):status.text="Golpe al aire";return false
 var target=target_owner(result.collider)
 var family:StringName=player.action_family if player.action_elapsed>=0 else player.family()
 var item:Dictionary=bag.held_item() if player.equipped else {}
 if not item.is_empty() and item.uses<=0:return false
 var sapling:bool=target.is_in_group("prototype_saplings")
 var enemy:bool=target.is_in_group("prototype_enemies")
 var tree:bool=target.is_in_group("prototype_trees")
 var rock:bool=target.is_in_group("prototype_rocks")
 if not enemy and not tree and not rock and not sapling:status.text="Golpe al aire";return false
 if target.health<=0 or not target_still_at(result,target):status.text="Golpe al aire";return false
 if not player.can_reach_contact(result.position):status.text="Fuera de alcance";return false
 var shoulder:Vector3=player.model.to_global(player.model.displayed_pose.shoulders[0] if not player.model.displayed_pose.is_empty() else Vector3(0,45.7,0))
 var path:=PhysicsRayQueryParameters3D.create(shoulder,result.position,1,[player.get_rid()])
 var blocking:=get_world_3d().direct_space_state.intersect_ray(path)
 if not blocking.is_empty() and target_owner(blocking.collider)!=target:status.text="Hay un obstáculo delante.";return false
 if enemy:
  var base:float=bag.held_damage() if player.equipped else 0.0
  target.take_damage(progression.combat_damage(base) if family==&"sword" else base)
  if player.equipped:bag.consume_use(2 if family in [&"axe",&"pickaxe"] else 1)
  combat_effects.flash(result.position);status.text="Enemigo: %d / 10"%int(target.health);return true
 if sapling:
  if family!=&"":status.text="Rompe este arbolito con las manos.";return false
  if target.health==1 and not bag.can_add_many(target.rewards):status.text="La mochila está llena.";return false
  target.hit();combat_effects.flash(result.position)
  if target.health==0:bag.add_many(target.rewards)
  return true
 if rock and target.hand_collectable:status.text="Recoge esta piedra con E y las manos libres.";return false
 var correct:bool=family==(&"axe" if tree else &"pickaxe")
 if player.equipped:bag.consume_use(1 if correct or family==&"sword" else 2)
 if not correct:status.text="Necesitas el hacha." if tree else "Necesitas el pico.";return true
 var reward:StringName=&"madera" if tree else &"piedra"
 var amount:int=4 if tree else target.yield_count
 if target.health==1 and not bag.can_add(reward,amount):status.text="Libera espacio en la mochila para recoger los materiales.";return true
 target.hit();combat_effects.flash(result.position)
 if target.health==0:bag.add(reward,amount)
 status.text="%s: %d golpes restantes"%["Árbol" if tree else "Roca",target.health];return true
func release_arrow(point:Vector3,uid:int) -> bool:
 var bow:Dictionary=bag.item_by_uid(uid)
 if bow.get("id")!=&"bow" or bag.count(&"flecha")<=0:return false
 bag.remove_amount(&"flecha",1)
 var from:Vector3=player.model.held_props[&"bow"].nocked.global_position
 var arrow:=preload("res://scripts/prototype_3d/arrow.gd").new();add_child(arrow);arrow.configure(self,from,point)
 arrow.travel(minf(24*1.75/64.0,from.distance_to(point)))
 return true
func interact() -> bool:
 if player.action_elapsed>=0 or player.equip_elapsed>=0 or player.parry_elapsed>=0 or player.preview_state!=&"" or player_health<=0:return false
 var result:Dictionary=camera_rig.action_sample(true).hit
 if result.is_empty():return false
 var target=target_owner(result.collider)
 if result.position.distance_to(player.global_position)>1.75:status.text="Acércate para interactuar.";return false
 if target.is_in_group("prototype_drops"):
  if player.equipped:status.text="Necesitas las manos libres para recogerlo.";return false
  return player.begin_pickup(result)
 if target.is_in_group("prototype_enemies") and target.health<=0:return corpse_loot.open_window(target)
 if target.is_in_group("prototype_workbenches"):return workbenches.open_table(target)
 if target.is_in_group("prototype_water"):
  var outcome:Dictionary=preload("res://scripts/nutrition.gd").refill(bag.held_item() if player.equipped else {})
  status.text=outcome.message;inventory_panel.refresh();return outcome.ok
 if target.is_in_group("prototype_burdock") and target.health>0:
  if player.equipped:status.text="Necesitas las manos libres para recogerlo.";return false
  return player.begin_pickup(result)
 if target.is_in_group("prototype_rocks") and target.hand_collectable and target.health>0:
  if player.equipped:status.text="Necesitas las manos libres para recogerlo.";return false
  return player.begin_pickup(result)
 return false
func complete_pickup(result:Dictionary,point:Vector3) -> bool:
 if player_health<=0 or player.equipped or not is_instance_valid(result.get("collider")):return false
 var target=target_owner(result.collider)
 if not target_still_at(result,target):return false
 var local_point:Vector3=player.model.to_local(point)
 var pose:Dictionary=player.Clips.sample(&"",&"pickup",0.5,0,Vector3.ZERO,local_point)
 if not pose.contact_reachable:status.text="Acércate para recogerlo con la mano.";return false
 # Check the hand path as well as camera visibility; a nearby visible item
 # behind a wall cannot be collected through that wall.
 var from:Vector3=player.model.to_global(pose.shoulders[1])
 for segment in [[player.global_position+Vector3.UP,from],[from,point]]:
  var query:=PhysicsRayQueryParameters3D.create(segment[0],segment[1],1,[player.get_rid()])
  var obstruction:=get_world_3d().direct_space_state.intersect_ray(query)
  if not obstruction.is_empty() and target_owner(obstruction.collider)!=target:return false
 if target.is_in_group("prototype_drops"):return corpse_loot.pickup(target,false)
 if target.health<=0:return false
 if target.is_in_group("prototype_burdock"):
  if not bag.add_many(target.rewards):status.text="La mochila está llena.";return false
  target.hit();status.text="Hojas de bardana recogidas.";return true
 if target.is_in_group("prototype_rocks") and target.hand_collectable:
  if not bag.add(&"piedra",target.yield_count):status.text="La mochila está llena.";return false
  target.hit();status.text="Piedra × %d"%target.yield_count;return true
 return false
func resume_world() -> void:
 paused=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func toggle_inventory(section:int) -> void:
 if player_health<=0 or not pending_consumption.is_empty():return
 if inventory_panel.visible:
  if inventory_panel.navigation.current_tab==section:inventory_panel.hide()
  else:inventory_panel.open_section(section)
  return
 if paused:return
 paused=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;inventory_panel.open_section(section)
func toggle_catalog() -> void:
 if item_catalog.visible:item_catalog.hide();return
 if paused or not pending_consumption.is_empty():return
 paused=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;item_catalog.open_catalog()
func cancel_work() -> void:player.cancel_action()
func update_hud() -> void:
 if hud!=null:hud.refresh()
func item_icon(item:Dictionary) -> Texture2D:return preload("res://scripts/prototype_3d/item_icons.gd").for_item(item)
func sync_equipment() -> void:
 player.equipped=bag.held_id()!=&""
 player.model.wear(bag.equipment[&"torso"])
 inventory_panel.refresh();update_hud()
func buy_improvement(id:StringName,ability:bool) -> bool:
 progression.health=player_health
 var spent:int=progression.purchase(id,ability,skill_points)
 if spent<=0:return false
 skill_points-=spent;player_health=progression.health;return true
func activate_skill(id:StringName) -> bool:
 progression.health=player_health
 var success:bool=progression.activate(id)
 if not success:status.text="Habilidad no disponible."
 return success
func gain_experience(amount:int,source:StringName=&"") -> bool:
 if amount<=0 or not preload("res://scripts/experience_sources.gd").accepts(source):return false
 experience+=amount
 while experience>=level*20:experience-=level*20;level+=1;skill_points+=1
 return true
func consume_item(index:int,quick:bool=false) -> bool:
 if not pending_consumption.is_empty() or player_health<=0:return false
 var item:Dictionary=bag.at(&"quick" if quick else &"bag",index)
 if item.is_empty():return false
 var trial=bag.fork();var nutrition_trial=preload("res://scripts/nutrition.gd").new()
 nutrition_trial.hydration_ml=nutrition.hydration_ml
 var result:Dictionary=nutrition_trial.consume(trial,index,quick)
 if not result.ok:status.text=result.message;inventory_panel.status.text=result.message;return false
 pending_consumption={"uid":item.uid,"id":item.id}
 inventory_panel.hide();item_catalog.hide();resume_world()
 player.play_preview(&"bottle" if item.id in [&"botella",&"water"] else &"food",&"drink" if item.id in [&"botella",&"water"] else &"eat")
 return true
func finish_consumption() -> void:
 var location:Dictionary=bag.location(pending_consumption.uid)
 if not location.is_empty() and location.kind in [&"bag",&"quick"]:
  var result:Dictionary=nutrition.consume(bag,location.index,location.kind==&"quick");status.text=result.message
 pending_consumption.clear();sync_equipment()
func spawn_enemy_near_player() -> bool:
 for index in 16:
  var point:Vector3=player.global_position+Vector3(cos(index*TAU/16),0,sin(index*TAU/16))*3
  var query:=PhysicsShapeQueryParameters3D.new();var sphere:=SphereShape3D.new();sphere.radius=0.4
  query.shape=sphere;query.transform.origin=point+Vector3.UP*0.5;query.collision_mask=11
  if not get_world_3d().direct_space_state.intersect_shape(query).is_empty():continue
  var enemy:=preload("res://scripts/prototype_3d/young_enemy.gd").new();add_child(enemy);enemy.global_position=point+Vector3.UP*0.1;enemy.configure(self);return true
 return false
func _exit_tree() -> void:
 Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
 var cursor := get_tree().root.get_node_or_null("GameCursor")
 if cursor != null: cursor.show(); cursor.set_process(true)

func build_loading_screen(root:Control) -> void:
 loading_screen=Control.new();loading_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(loading_screen)
 var background:=ColorRect.new();background.color=Color.BLACK;background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);loading_screen.add_child(background)
 var center:=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);loading_screen.add_child(center)
 var layout:=VBoxContainer.new();layout.add_theme_constant_override("separation",12);center.add_child(layout)
 var label:=Label.new();label.text="Cargando mundo" if not initial_state.is_empty() else "Generando mundo";label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;layout.add_child(label)
 loading_progress=ProgressBar.new();loading_progress.custom_minimum_size=Vector2(360,18);loading_progress.show_percentage=false;loading_progress.max_value=1
 var border:=StyleBoxFlat.new();border.bg_color=Color.BLACK;border.border_color=Color.WHITE;border.set_border_width_all(1);loading_progress.add_theme_stylebox_override("background",border)
 var fill:=StyleBoxFlat.new();fill.bg_color=Color.WHITE;loading_progress.add_theme_stylebox_override("fill",fill);layout.add_child(loading_progress)
 loading_screen.visible=not use_test_layout
 if not use_test_layout:loading_state=true;paused=true
func generate_content() -> void:
 await get_tree().process_frame
 environment_content=preload("res://scripts/prototype_3d/world_content.gd").new();add_child(environment_content)
 environment_content.progress_changed.connect(func(value):set_loading_progress(value*0.8))
 environment_content.completed.connect(finish_world_loading)
 environment_content.configure(self,world_seed)
func set_loading_progress(value:float) -> void:
 loading_progress.value=value;loading_changed.emit(value)
func finish_world_loading() -> void:
 if not initial_state.is_empty():
  if not Save.restore(self,initial_state):
   load_failed.emit("No se pudo restaurar esta partida: sus datos no coinciden con el mundo.");return
 else:refresh_daylight()
 set_loading_progress(0.9)
 # If saved indoors, the actual interior must be ready before releasing physics.
 var required:Array=[]
 for building in get_tree().get_nodes_in_group("prototype_buildings"):
  if not is_ancestor_of(building):continue
  building.stream.update_stream(player.global_position)
  if building.stream.interior_bounds.has_point(building.to_local(player.global_position)):required.append(building.stream)
 var deadline:=Time.get_ticks_msec()+15000
 while true:
  var ready_count:=0
  for stream in required:
   stream.update_stream(player.global_position)
   if stream.failed:load_failed.emit("No se pudo cargar el interior de la partida.");return
   if stream.interior_ready:ready_count+=1
  if ready_count==required.size():break
  if Time.get_ticks_msec()>deadline:load_failed.emit("El interior no terminó de cargar. Puedes volver a intentarlo.");return
  set_loading_progress(0.9+0.08*ready_count/maxi(1,required.size()))
  await get_tree().process_frame
 for view in get_tree().get_nodes_in_group("prototype_maps"):
  if is_ancestor_of(view):view.refresh_terrain()
 terrain.update_observer(player.global_position);set_loading_progress(1)
 await get_tree().process_frame
 camera_rig.update(1)
 initial_state.clear();loading_state=false;loading_screen.hide();resume_world();world_ready.emit()
func save_current_game() -> Error:
 var message:Label=pause_panel.find_child("SaveMessage",true,false)
 var reason:=Save.save_block_reason(self)
 if not reason.is_empty():
  if message!=null:message.text=reason
  return ERR_BUSY
 var result:=Save.write(self,save_path)
 if message!=null:message.text="Partida guardada." if result==OK else "No se pudo guardar (%s)."%error_string(result)
 status.text="Partida guardada." if result==OK else "No se pudo guardar la partida."
 return result

func surface_height(point:Vector3) -> float:
 return environment_content.surface_height(point) if environment_content!=null else 0.0

func can_cross_jump(point:Vector3,motion:Vector3,actor_rid:RID) -> bool:
 if motion.is_zero_approx():return true
 var from:=Vector3(point.x,0.25,point.z)
 var query:=PhysicsRayQueryParameters3D.create(from,from+motion+motion.normalized()*0.21,1,[actor_rid])
 var result:=get_world_3d().direct_space_state.intersect_ray(query)
 return result.is_empty() or float(result.collider.get_meta("physical_height",0.0))<=1.75*0.3
