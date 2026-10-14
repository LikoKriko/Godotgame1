extends Node3D
## Reviewable first slice: real 3D survivor, shoulder camera, axe and woodland.
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
var styled_hud:Control
var progression=preload("res://scripts/progression.gd").new()
var skill_points:=0
var experience:=0
var pending_consumption:Dictionary={}
var terrain:Node3D
var combat_effects:Node3D
func _ready() -> void:
 # The 2D cursor autoload would override captured mouse mode each frame.
 var cursor := get_tree().root.get_node_or_null("GameCursor")
 if cursor != null: cursor.set_process(false); cursor.hide()
 for overlay in get_tree().root.get_children():
  if overlay.name == &"GameCursor": continue
  if overlay.get("name") == &"DayZeroCursor": overlay.hide(); overlay.process_mode = Node.PROCESS_MODE_DISABLED
 Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
 settings.load_settings()
 progression.reset()
 bag.reset()
 bag.move_item(&"quick",5,&"quick",0)
 build_environment()
 combat_effects=preload("res://scripts/prototype_3d/combat_effects.gd").new();add_child(combat_effects);combat_effects.game=self
 player = preload("res://scripts/prototype_3d/player.gd").new(); add_child(player); player.configure(self); player.position = Vector3(0,0.2,2.0)
 camera_rig = preload("res://scripts/prototype_3d/shoulder_camera.gd").new(); add_child(camera_rig); camera_rig.configure(self,player); camera_rig.update(1.0)
 build_ui()
 var enemy:=preload("res://scripts/prototype_3d/young_enemy.gd").new();add_child(enemy);enemy.position=Vector3(7,0.2,-4);enemy.configure(self)
func build_environment() -> void:
 var environment := WorldEnvironment.new(); var environment_settings := Environment.new()
 environment_settings.background_mode = Environment.BG_COLOR; environment_settings.background_color = Color("809495")
 environment_settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; environment_settings.ambient_light_color = Color("b2b59b"); environment_settings.ambient_light_energy = 0.6
 environment.environment = environment_settings;world_ambient=environment_settings; add_child(environment)
 var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-52,-35,0); sun.light_color = Color("fff1d6"); sun.light_energy = 1.2; sun.shadow_enabled = true; add_child(sun);main_sun=sun
 var ground := StaticBody3D.new(); add_child(ground)
 var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(48,0.4,48); shape.shape = box; shape.position.y = -0.2; ground.add_child(shape)
 terrain=preload("res://scripts/prototype_3d/terrain_chunks.gd").new();add_child(terrain)
 var units:float=preload("res://scripts/prototype_3d/terrain_chunks.gd").METRES_PER_UNIT
 terrain.configure(73129,null,Rect2(Vector2(-24,-24)/units,Vector2(48,48)/units))
 terrain.update_observer(Vector3.ZERO)
 for point in [Vector3(0,0,-1.6),Vector3(3,0,-4),Vector3(-3,0,-5),Vector3(5,0,3)]:
  var tree := preload("res://scripts/prototype_3d/tree_model.gd").new(); add_child(tree); tree.position = point; tree.scale = Vector3.ONE*0.65
 for index in get_tree().get_nodes_in_group("prototype_trees").size():
  var tree=get_tree().get_nodes_in_group("prototype_trees")[index]
  var center:Vector2=Vector2(tree.position.x,tree.position.z)/units
  terrain.sampler.add_influence(StringName("tree_%d"%index),&"dirt",Rect2(center-Vector2.ONE*25,Vector2.ONE*50),0.65)
 terrain.refresh_influences()
 var rock_points:=[Vector3(3,0,2.5),Vector3(4,0,-2.2),Vector3(-3,0,1.5),Vector3(8,0,-7)]
 for i in rock_points.size():
  var rock:=preload("res://scripts/prototype_3d/rock.gd").new();add_child(rock);rock.position=rock_points[i];rock.configure(i)
 var water:=preload("res://scripts/prototype_3d/water_source.gd").new();add_child(water);water.position=Vector3(-2,0,4)
 # A solid test wall also provides an explicit camera collision case.
 var wall := StaticBody3D.new(); add_child(wall); wall.position = Vector3(-6,1,-2)
 var collider := CollisionShape3D.new(); var block := BoxShape3D.new(); block.size = Vector3(0.5,2,5); collider.shape = block; wall.add_child(collider)
 var visual := MeshInstance3D.new(); var cube := BoxMesh.new(); cube.size = block.size; visual.mesh = cube
 var paint := StandardMaterial3D.new(); paint.albedo_color = Color("686257"); paint.roughness = 1.0; visual.material_override = paint; wall.add_child(visual)
func build_ui() -> void:
 var layer := CanvasLayer.new(); add_child(layer)
 var root := Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(root)
 var aim := Label.new(); aim.text = "·"; aim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; aim.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 aim.set_anchors_and_offsets_preset(Control.PRESET_CENTER); aim.offset_left = -12; aim.offset_top = -12; aim.offset_right = 12; aim.offset_bottom = 12; aim.add_theme_font_size_override("font_size",28); root.add_child(aim)
 aim.mouse_filter=Control.MOUSE_FILTER_IGNORE
 status = Label.new();status.hide();status.text="DAY ZERO · PROTOTIPO 3D";root.add_child(status)
 hud=preload("res://scripts/prototype_3d/hud.gd").new();root.add_child(hud);hud.configure(self)
 pause_panel = CenterContainer.new(); pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(pause_panel); pause_panel.hide()
 var frame := PanelContainer.new(); frame.theme = preload("res://scripts/ui_style.gd").theme(); pause_panel.add_child(frame)
 var buttons := VBoxContainer.new(); buttons.add_theme_constant_override("separation",16); frame.add_child(buttons)
 pause_title=Label.new();pause_title.text="PAUSA";buttons.add_child(pause_title)
 for caption in ["Continuar","Configuración","Reaparecer","Abrir versión 2D","Salir"]:
  var button := preload("res://scripts/menu_button.gd").new(); button.text = caption; buttons.add_child(button)
  if caption=="Continuar":continue_button=button;button.pressed.connect(toggle_pause)
  elif caption=="Configuración":button.pressed.connect(open_settings)
  elif caption=="Reaparecer":respawn_button=button;button.pressed.connect(respawn)
  else:button.pressed.connect(open_2d if caption=="Abrir versión 2D" else get_tree().quit)
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
func toggle_pause() -> void:
 if inventory_panel!=null and inventory_panel.visible:inventory_panel.hide();return
 if item_catalog!=null and item_catalog.visible:item_catalog.hide();return
 if map_holder!=null and map_holder.visible:toggle_map();return
 if settings_holder.visible:close_settings();return
 if paused and player_health<=0:return
 paused = not paused; pause_panel.visible = paused
 pause_title.text="HAS MUERTO" if player_health<=0 else "PAUSA"
 continue_button.disabled=player_health<=0;respawn_button.visible=player_health<=0
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
 var daylight:Dictionary=day_cycle.sun_state()
 main_sun.light_energy=daylight.elevation*1.2;main_sun.rotation_degrees=Vector3(-lerpf(18,76,daylight.elevation),lerpf(-70,70,daylight.progress),0)
 world_ambient.ambient_light_color=daylight.ambient;world_ambient.ambient_light_energy=lerpf(0.32,0.65,daylight.elevation)
func respawn() -> void:
 player_health=20;level=1;nutrition.reset();parry.reset()
 skill_points=0;experience=0
 var preserved_skills:Dictionary=progression.skills.duplicate();progression.reset()
 for id in progression.skills:progression.skills[id]=1 if preserved_skills[id]>0 else 0
 pending_consumption.clear();player.preview_state=&""
 bag.reset()
 for i in bag.slots.size():bag.slots[i]={}
 for i in bag.quick_slots.size():bag.quick_slots[i]={}
 bag.active_quick_uid=-1;player.equipped=false;player.death_elapsed=-1;player.action_elapsed=-1;player.equip_elapsed=-1;player.equip_recovery=0;player.parry_elapsed=-1;player.locomotion.reset();player.position=Vector3(0,0.2,2)
 player.pickup_recovery=0;player.model.wear({})
 paused=false;pause_panel.hide();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func open_2d() -> void:
 if get_tree().root.get_node_or_null("GameCursor") == null:
  var cursor := preload("res://scripts/cursor_overlay.gd").new(); cursor.name = "GameCursor"; get_tree().root.add_child(cursor)
 get_tree().change_scene_to_file("res://scenes/day_zero.tscn")
func _unhandled_input(event: InputEvent) -> void:
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
 var enemy:bool=target.is_in_group("prototype_enemies")
 var tree:bool=target.is_in_group("prototype_trees")
 var rock:bool=target.is_in_group("prototype_rocks")
 if not enemy and not tree and not rock:status.text="Golpe al aire";return false
 if target.health<=0 or not target_still_at(result,target):status.text="Golpe al aire";return false
 if not player.can_reach_contact(result.position):status.text="Fuera de alcance";return false
 if enemy:
  var base:float=bag.held_damage() if player.equipped else 0.0
  target.take_damage(progression.combat_damage(base) if family==&"sword" else base)
  if player.equipped:bag.consume_use(2 if family in [&"axe",&"pickaxe"] else 1)
  combat_effects.flash(result.position);status.text="Enemigo: %d / 10"%int(target.health);return true
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
 if player.action_elapsed>=0 or player.preview_state!=&"" or player_health<=0:return false
 var result:Dictionary=camera_rig.target()
 if result.is_empty():return false
 var target=target_owner(result.collider)
 if result.position.distance_to(player.global_position)>1.75:status.text="Acércate para interactuar.";return false
 if target.is_in_group("prototype_water"):
  var outcome:Dictionary=preload("res://scripts/nutrition.gd").refill(bag.held_item() if player.equipped else {})
  status.text=outcome.message;inventory_panel.refresh();return outcome.ok
 if target.is_in_group("prototype_rocks") and target.hand_collectable and target.health>0:
  if player.equipped:status.text="Necesitas las manos libres para recogerlo.";return false
  if not bag.add(&"piedra",target.yield_count):status.text="La mochila está llena.";return false
  target.hit();player.play_preview(&"",&"pickup");status.text="Piedra × %d"%target.yield_count;return true
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
