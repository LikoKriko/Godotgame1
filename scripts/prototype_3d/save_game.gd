extends RefCounted
## Data-only 3D saves. A checked temporary file and last-good backup protect manual saves.
const PATH:="user://day_zero_3d.save"
const FORMAT:="day-zero-3d"
const VERSION:=1
const LAYOUT_VERSION:=1
const MAX_BYTES:=8*1024*1024
const Bag=preload("res://scripts/inventory.gd")
const Items=preload("res://scripts/save_game.gd")
const Progress=preload("res://scripts/progression.gd")
const MOTION:=["from_slide","jump_heading","launch_heading","jump_speed","jump_elapsed","slide_elapsed","cooldown","crouch"]
const ENEMY_FIELDS:=["health","phase","attack_elapsed","impact_done","punch_left","rise_elapsed","lower_elapsed","standing","damage_received","boxing_unlocked","boxing_check_remaining","boxing_remaining","attack_boxing","lower_from_boxing","death_elapsed","avoid_remaining"]
const BRAIN_FIELDS:=["mode","remembers_player","remaining","elapsed","feeding_cooldown"]
static func vector(point:Vector3) -> Array:return [point.x,point.y,point.z]
static func point(value:Array) -> Vector3:return Vector3(value[0],value[1],value[2])
static func integer(value,minimum:int,maximum:int) -> bool:return value is int and value>=minimum and value<=maximum
static func number(value,minimum:float,maximum:float) -> bool:return (value is int or value is float) and is_finite(float(value)) and value>=minimum and value<=maximum
static func valid_vector(value) -> bool:
 if not value is Array or value.size()!=3:return false
 for component in value:
  if not number(component,-10000,10000):return false
 return true
static func in_world(value) -> bool:
 return valid_vector(value) and absf(float(value[0]))<=42 and absf(float(value[2]))<=28 and number(value[1],-2,30)
static func rng_value(value) -> bool:return value is String and value.length()<=20 and value.is_valid_int()
static func normalized(value):
 # JSON numbers are decoded as floats by Godot. Restore exact small integer fields;
 # RNG states are decimal strings so their 64-bit precision is never lost.
 if value is float and is_finite(value) and value==floor(value) and absf(value)<9007199254740992.0:return int(value)
 if value is Array:
  var result:Array=[]
  for entry in value:result.append(normalized(entry))
  return result
 if value is Dictionary:
  var result:Dictionary={}
  for key in value:result[key]=normalized(value[key])
  return result
 return value
static func capture(game) -> Dictionary:
 var resources:Dictionary={}
 for id in game.environment_content.resource_nodes:resources[id]=game.environment_content.resource_nodes[id].health
 var motion:Dictionary={}
 for key in MOTION:motion[key]=game.player.locomotion.get(key)
 motion.slide_direction=[game.player.locomotion.slide_direction.x,game.player.locomotion.slide_direction.y]
 var enemies:Array=[]
 for actor in game.get_tree().get_nodes_in_group("prototype_enemies"):
  if actor.game!=game or actor.is_queued_for_deletion():continue
  var entry:Dictionary={"position":vector(actor.position),"heading":actor.model.rotation.y,"velocity":vector(actor.velocity),"avoid_direction":vector(actor.avoid_direction),"loot":actor.loot_slots.duplicate(true),"effects":actor.effects.active.duplicate(true)}
  for key in ENEMY_FIELDS:entry[key]=actor.get(key)
  var brain:Dictionary={"goal":vector(actor.brain.goal),"last_seen":vector(actor.brain.last_seen),"rng":str(actor.brain.rng.state),"tree":""}
  for key in BRAIN_FIELDS:brain[key]=actor.brain.get(key)
  if is_instance_valid(actor.brain.tree):brain.tree=str(actor.brain.tree.get_meta("resource_id",""))
  entry.brain=brain;enemies.append(entry)
 var drops:Array=[]
 for drop in game.get_tree().get_nodes_in_group("prototype_drops"):
  if not game.is_ancestor_of(drop) or drop.is_queued_for_deletion() or drop.item.is_empty():continue
  drops.append({"position":vector(drop.position),"item":drop.item.duplicate(true)})
 var tables:Array=[]
 for table in game.workbenches.tables:tables.append({"position":vector(table.position),"uid":table.uid})
 return {"version":VERSION,"layout_version":LAYOUT_VERSION,"seed":game.world_seed,"saved_at":Time.get_datetime_string_from_system(true),
  "player":{"position":vector(game.player.position),"velocity":vector(game.player.velocity),"heading":game.player.model.rotation.y,"phase":game.player.phase,"motion":motion,"response":game.player.movement_response.snapshot(),"slide_backward":game.player.slide_backward,"slide_facing":game.player.slide_facing,"slide_distance_scale":game.player.locomotion.slide_distance_scale,"death_elapsed":game.player.death_elapsed,"equip_recovery":game.player.equip_recovery,"pickup_recovery":game.player.pickup_recovery,"camera":[game.camera_rig.yaw,game.camera_rig.pitch]},
  "bag":{"slots":game.bag.slots.duplicate(true),"quick":game.bag.quick_slots.duplicate(true),"equipment":game.bag.equipment.duplicate(true),"active":game.bag.active_quick_uid,"next_uid":game.bag.next_uid,"recipes":game.bag.unlocked_recipes.duplicate()},
  "progress":{"level":game.level,"experience":game.experience,"points":game.skill_points,"health":game.player_health,"skills":game.progression.skills.duplicate(),"perks":game.progression.perks.duplicate(),"active":game.progression.active.duplicate(),"cooldowns":game.progression.cooldowns.duplicate(),"rng":str(game.progression.rng.state)},
  "nutrition":{"calories":game.nutrition.calories_today,"hydration":game.nutrition.hydration_ml,"water_today":game.nutrition.water_today_ml},
  "clock":{"day":game.day_cycle.day,"hour":game.day_cycle.hour},"parry":{"remaining":game.parry.cooldown_remaining(),"used":game.parry.used},
  "resources":resources,"enemies":enemies,"drops":drops,"tables":tables}
static func save_block_reason(game) -> String:
 if game.loading_state or game.environment_content==null:return "Espera a que termine de cargar el mundo."
 if not game.pending_consumption.is_empty() or game.player.preview_state!=&"" or game.player.action_elapsed>=0 or game.player.equip_elapsed>=0 or game.player.parry_elapsed>=0:return "Reanuda y termina la acción del personaje antes de guardar."
 if game.workbenches.placing():return "Termina o cancela la colocación antes de guardar."
 if game.inventory_panel.creation_page.is_crafting() or game.workbenches.window.page.is_crafting():return "Termina o cancela la fabricación antes de guardar."
 if not game.parry.pending.is_empty():return "Reanuda un momento para resolver el impacto pendiente antes de guardar."
 for arrow in game.get_tree().get_nodes_in_group("player_arrows_3d"):
  if game.is_ancestor_of(arrow) and not arrow.is_queued_for_deletion():return "Espera a que termine el disparo antes de guardar."
 return ""
static func valid_item(value,uids:Dictionary) -> bool:return Items.valid_item(value,uids)
static func item_array(value,size_value:int,uids:Dictionary) -> bool:
 if not value is Array or value.size()!=size_value:return false
 for item in value:
  if not valid_item(item,uids):return false
 return true
static func ranks(value,definitions:Dictionary,limit:int) -> bool:
 if not value is Dictionary or value.size()!=definitions.size():return false
 for id in definitions:
  if not integer(value.get(id),0,limit):return false
 return true
static func skill_times(value,key:String) -> bool:
 if not value is Dictionary or value.size()!=Progress.SKILLS.size():return false
 for id in Progress.SKILLS:
  if not number(value.get(id),0,Progress.SKILLS[id][key]):return false
 return true
static func valid(data) -> bool:
 if not data is Dictionary or data.get("version")!=VERSION or data.get("layout_version")!=LAYOUT_VERSION:return false
 if not integer(data.get("seed"),0,2147483647) or not data.get("saved_at") is String:return false
 for key in ["player","bag","progress","nutrition","clock","parry","resources"]:
  if not data.get(key) is Dictionary:return false
 var p:Dictionary=data.player;var b:Dictionary=data.bag;var progress:Dictionary=data.progress
 if not in_world(p.get("position")) or not valid_vector(p.get("velocity")) or not number(p.get("heading"),-100000,100000) or not number(p.get("phase"),0,1):return false
 if not number(p.get("equip_recovery"),0,1) or not number(p.get("pickup_recovery"),0,0.5):return false
 if not number(p.get("death_elapsed"),-1,3.1) or not p.get("camera") is Array or p.camera.size()!=2:return false
 if not number(p.camera[0],-100000,100000) or not number(p.camera[1],-preload("res://scripts/prototype_3d/shoulder_camera.gd").PITCH_LIMIT-0.000001,preload("res://scripts/prototype_3d/shoulder_camera.gd").PITCH_LIMIT+0.000001):return false
 if p.has("response") and not preload("res://scripts/prototype_3d/movement_response.gd").valid(p.response):return false
 if not p.get("slide_backward",false) is bool or not number(p.get("slide_facing",p.heading),-100000,100000) or not number(p.get("slide_distance_scale",1),0,1):return false
 var motion=p.get("motion")
 if not motion is Dictionary or not motion.get("from_slide") is bool:return false
 for key in ["jump_heading","launch_heading"]:
  if not number(motion.get(key),-100000,100000):return false
 for pair in [["jump_speed",1000.0],["jump_elapsed",0.66],["slide_elapsed",0.46],["cooldown",0.9],["crouch",1.0]]:
  if not number(motion.get(pair[0]),0,pair[1]):return false
 if not motion.get("slide_direction") is Array or motion.slide_direction.size()!=2:return false
 for component in motion.slide_direction:
  if not number(component,-1,1):return false
 var uids:Dictionary={}
 if not item_array(b.get("slots"),Bag.CAPACITY,uids) or not item_array(b.get("quick"),6,uids):return false
 if not b.get("equipment") is Dictionary or b.equipment.size()!=Bag.EQUIPMENT_SLOTS.size():return false
 for slot in Bag.EQUIPMENT_SLOTS:
  var item=b.equipment.get(slot)
  if not valid_item(item,uids) or (not item.is_empty() and Bag.DEFINITIONS[item.id].slot!=slot):return false
 if not integer(b.get("active"),-1,2147483647) or not integer(b.get("next_uid"),1,2147483647):return false
 if b.active!=-1:
  var found:=false
  for item in b.quick:
   if item.get("uid",-1)==b.active:
    found=Bag.DEFINITIONS[item.id].slot==&"tool" or Bag.DEFINITIONS[item.id].has("kcal")
  if not found:return false
 if not b.get("recipes") is Array:return false
 var recipes:Dictionary={}
 for id in b.recipes:
  if not (id is String or id is StringName) or not id in Bag.DEFAULT_RECIPES or recipes.has(id):return false
  recipes[id]=true
 if not integer(progress.get("level"),1,100000) or not integer(progress.get("experience"),0,progress.level*20-1) or not integer(progress.get("points"),0,2147483647):return false
 if not ranks(progress.get("skills"),Progress.SKILLS,Progress.SKILL_LIMIT) or not ranks(progress.get("perks"),Progress.PERKS,Progress.PERK_LIMIT):return false
 if not skill_times(progress.get("active"),"duration") or not skill_times(progress.get("cooldowns"),"cooldown") or not rng_value(progress.get("rng")):return false
 if not number(progress.get("health"),0,20*(1+0.1*progress.perks[&"life"])):return false
 if not integer(data.nutrition.get("calories"),0,2147483647) or not number(data.nutrition.get("hydration"),0,2000) or not integer(data.nutrition.get("water_today"),0,2147483647):return false
 if not integer(data.clock.get("day"),1,2147483647) or not number(data.clock.get("hour"),0,23.999999999):return false
 if not number(data.parry.get("remaining"),0,4) or not data.parry.get("used") is bool:return false
 if data.resources.size()>20000:return false
 for id in data.resources:
  if not id is String or not integer(data.resources[id],0,12):return false
 if not data.get("tables") is Array or data.tables.size()>2048:return false
 for table in data.tables:
  if not table is Dictionary or not in_world(table.get("position")) or not integer(table.get("uid"),1,2147483647) or uids.has(table.uid):return false
  uids[table.uid]=true
 if not data.get("drops") is Array or data.drops.size()>4096:return false
 for drop in data.drops:
  if not drop is Dictionary or not in_world(drop.get("position")) or not valid_item(drop.get("item"),uids) or drop.item.is_empty():return false
 if not data.get("enemies") is Array or data.enemies.size()>1024:return false
 for actor in data.enemies:
  if not valid_enemy(actor,uids):return false
 for uid in uids:
  if uid>=b.next_uid:return false
 return true
static func valid_enemy(actor,uids:Dictionary) -> bool:
 if not actor is Dictionary:return false
 for key in ["position","velocity","avoid_direction"]:
  if not valid_vector(actor.get(key)):return false
 # Streaming can retain enemies beyond the current finite player map.
 # Keep finite, bounded coordinates without discarding a suspended actor.
 if not valid_vector(actor.position) or not number(actor.get("heading"),-100000,100000):return false
 if not item_array(actor.get("loot"),8,uids) or not number(actor.get("health"),0,10):return false
 for key in ["impact_done","punch_left","standing"]:
  if not actor.get(key) is bool:return false
 for pair in [["phase",0,1],["attack_elapsed",-1,1.21],["rise_elapsed",-1,0.29],["lower_elapsed",-1,0.29],["death_elapsed",-1,182],["avoid_remaining",0,0.71]]:
  if not number(actor.get(pair[0]),pair[1],pair[2]):return false
 for key in ["boxing_unlocked","attack_boxing","lower_from_boxing"]:
  if not actor.get(key,false) is bool:return false
 for pair in [["boxing_check_remaining",0,10],["boxing_remaining",0,20]]:
  if not number(actor.get(pair[0],10.0 if pair[0]=="boxing_check_remaining" else 0.0),pair[1],pair[2]):return false
 if not number(actor.get("damage_received",maxf(0,10-actor.health)),0,10):return false
 if actor.health==0 and actor.death_elapsed<0:return false
 if not actor.get("effects") is Dictionary:return false
 for id in actor.effects:
  if id!=&"stun" or not actor.effects[id] is Dictionary:return false
  var effect:Dictionary=actor.effects[id]
  if not number(effect.get("remaining"),0,1.5) or not number(effect.get("elapsed"),0,1e9) or not number(effect.get("total"),0,1e9):return false
  if absf(effect.elapsed+effect.remaining-effect.total)>0.00001:return false
 var brain=actor.get("brain")
 if not brain is Dictionary or not rng_value(brain.get("rng")) or not brain.get("remembers_player") is bool:return false
 if brain.get("mode") not in ["idle","chase","investigate","search","walk","sit_down","sit","sit_up","feed","sleep_down","sleep","wake_up"]:return false
 if not number(brain.get("feeding_cooldown",0.0),0,26):return false
 return valid_vector(brain.get("goal")) and valid_vector(brain.get("last_seen")) and number(brain.get("remaining"),0,12) and number(brain.get("elapsed"),0,1e9) and brain.get("tree") is String
static func read_one(path:String) -> Dictionary:
 if not FileAccess.file_exists(path):return {}
 var file:=FileAccess.open(path,FileAccess.READ)
 if file==null or file.get_length()>MAX_BYTES:return {}
 var parser:=JSON.new()
 if parser.parse(file.get_as_text())!=OK:return {}
 var packet=parser.data
 if not packet is Dictionary or packet.get("format")!=FORMAT or not packet.get("state") is String or not packet.get("sha256") is String:return {}
 if packet.state.sha256_text()!=packet.sha256:return {}
 if parser.parse(packet.state)!=OK:return {}
 var data=normalized(parser.data)
 return data if valid(data) else {}
static func read_result(path:String=PATH) -> Dictionary:
 var data:=read_one(path)
 if not data.is_empty():return {"ok":true,"state":data,"message":"","recovered":false}
 data=read_one(path+".bak")
 if not data.is_empty():return {"ok":true,"state":data,"message":"Se ha recuperado la última copia válida del guardado.","recovered":true}
 return {"ok":false,"state":{},"message":"El guardado 3D está dañado o pertenece a otra versión." if FileAccess.file_exists(path) or FileAccess.file_exists(path+".bak") else "Todavía no hay una partida 3D guardada.","recovered":false}
static func read_state(path:String=PATH) -> Dictionary:return read_result(path).state
static func write(game,path:String=PATH) -> Error:
 if not save_block_reason(game).is_empty():return ERR_BUSY
 var data:=capture(game)
 # Validate the round trip before touching the existing file.
 var body:=JSON.stringify(data);var normalized_data=normalized(JSON.parse_string(body))
 if not valid(normalized_data):return ERR_INVALID_DATA
 var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
 if file==null:return FileAccess.get_open_error()
 file.store_string(JSON.stringify({"format":FORMAT,"sha256":body.sha256_text(),"state":body}));file.flush();file.close()
 if read_one(path+".tmp").is_empty():return ERR_FILE_CORRUPT
 if FileAccess.file_exists(path):
  if not read_one(path).is_empty():
   if FileAccess.file_exists(path+".bak"):
    var remove_error:=DirAccess.remove_absolute(path+".bak")
    if remove_error!=OK:return remove_error
   var backup_error:=DirAccess.rename_absolute(path,path+".bak")
   if backup_error!=OK:return backup_error
  else:
   var remove_error:=DirAccess.remove_absolute(path)
   if remove_error!=OK:return remove_error
 var result:=DirAccess.rename_absolute(path+".tmp",path)
 if result!=OK and not FileAccess.file_exists(path) and FileAccess.file_exists(path+".bak"):DirAccess.copy_absolute(path+".bak",path)
 return result
static func matches_world(game,data:Dictionary) -> bool:
 var nodes:Dictionary=game.environment_content.resource_nodes
 if data.resources.size()!=nodes.size():return false
 for id in data.resources:
  if not nodes.has(id) or data.resources[id]>nodes[id].health:return false
 for actor in data.enemies:
  if not actor.brain.tree.is_empty() and not nodes.has(actor.brain.tree):return false
 return true
static func restore(game,data:Dictionary) -> bool:
 if not valid(data) or game.world_seed!=data.seed or not matches_world(game,data):return false
 var b:Dictionary=data.bag
 game.bag.slots.assign(b.slots.duplicate(true));game.bag.quick_slots.assign(b.quick.duplicate(true));game.bag.equipment=b.equipment.duplicate(true)
 game.bag.held_tool={};game.bag.next_uid=b.next_uid;game.bag.active_quick_uid=b.active;game.bag.unlocked_recipes=b.recipes.duplicate()
 for key in ["skills","perks","active","cooldowns"]:game.progression.set(key,data.progress[key].duplicate())
 game.progression.rng.state=int(data.progress.rng);game.player_health=data.progress.health;game.progression.health=game.player_health
 game.level=data.progress.level;game.experience=data.progress.experience;game.skill_points=data.progress.points
 game.nutrition.calories_today=data.nutrition.calories;game.nutrition.hydration_ml=data.nutrition.hydration;game.nutrition.water_today_ml=data.nutrition.water_today
 game.day_cycle.day=data.clock.day;game.day_cycle.hour=data.clock.hour
 game.parry.reset();game.parry.last_activation=-4+data.parry.remaining;game.parry.used=data.parry.used
 for id in data.resources:
  var node=game.environment_content.resource_nodes[id]
  if data.resources[id]==0:node.health=1;node.hit()
  else:node.health=data.resources[id]
 var p:Dictionary=data.player
 game.player.bow_follow_elapsed=-1
 game.player.reset_motion_state()
 game.player.position=point(p.position);game.player.velocity=point(p.velocity);game.player.model.rotation.y=p.heading;game.player.phase=p.phase;game.player.death_elapsed=p.death_elapsed;game.player.equip_recovery=p.equip_recovery;game.player.pickup_recovery=p.pickup_recovery
 for key in MOTION:game.player.locomotion.set(key,p.motion[key])
 game.player.locomotion.slide_direction=Vector2(p.motion.slide_direction[0],p.motion.slide_direction[1])
 game.player.locomotion.slide_distance_scale=p.get("slide_distance_scale",1.0)
 game.player.slide_backward=p.get("slide_backward",false);game.player.slide_facing=p.get("slide_facing",p.heading)
 if p.has("response"):game.player.movement_response.restore(p.response)
 else:game.player.movement_response.speed=Vector2(p.velocity[0],p.velocity[2]).length()/game.player.SPEED
 game.player.facing_history=preload("res://scripts/prototype_3d/facing_delay.gd").new()
 game.player.facing_history.sample(game.player.model.basis.z*4,0)
 game.camera_rig.yaw=p.camera[0];game.camera_rig.pitch=clampf(p.camera[1],-game.camera_rig.PITCH_LIMIT,game.camera_rig.PITCH_LIMIT)
 for actor in game.get_tree().get_nodes_in_group("prototype_enemies"):
  if actor.game==game:actor.free()
 for entry in data.enemies:
  var actor=load("res://scripts/prototype_3d/young_enemy.gd").new();game.add_child(actor);actor.configure(game)
  actor.position=point(entry.position);actor.velocity=point(entry.velocity);actor.model.rotation.y=entry.heading;actor.avoid_direction=point(entry.avoid_direction)
  for key in ENEMY_FIELDS:
   if entry.has(key):actor.set(key,entry[key])
  actor.damage_received=entry.get("damage_received",maxf(0,10-actor.health))
  actor.loot_slots.assign(entry.loot.duplicate(true));actor.effects.active=entry.effects.duplicate(true)
  for key in BRAIN_FIELDS:
   if entry.brain.has(key):actor.brain.set(key,entry.brain[key])
  actor.brain.goal=point(entry.brain.goal);actor.brain.last_seen=point(entry.brain.last_seen);actor.brain.rng.state=int(entry.brain.rng)
  actor.brain.tree=game.environment_content.resource_nodes.get(entry.brain.tree)
  actor.restore_presentation()
 for entry in data.tables:game.workbenches.add_table(point(entry.position),entry.uid)
 for entry in data.drops:game.corpse_loot.spawn_drop(entry.item,point(entry.position),false)
 game.sync_equipment();game.player.model.family_override=game.player.family()
 var clip:StringName=&"idle";var phase:=0.0
 if game.player_health<=0:clip=&"death";phase=clampf(p.death_elapsed/3,0,1)
 elif game.player.locomotion.airborne():clip=&"slide_jump" if p.motion.from_slide else &"jump";phase=p.motion.jump_elapsed/0.66
 elif game.player.locomotion.sliding():clip=&"slide_back" if game.player.slide_backward else &"slide";phase=p.motion.slide_elapsed/0.46
 elif p.motion.crouch>0.1:clip=&"crouch"
 elif Vector2(p.velocity[0],p.velocity[2]).length()>0.1:clip=&"run" if Vector2(p.velocity[0],p.velocity[2]).length()>2.01 else &"walk";phase=p.phase
 game.player.model.sprint_weight=game.player.movement_response.sprint_weight;game.player.model.sprint_crouch=game.player.locomotion.crouch
 game.player.model.animate(clip,phase,game.player.equipped)
 game.camera_rig.update(1);game.refresh_daylight()
 if game.distance_optimization!=null:game.distance_optimization.update_enemies()
 return true
