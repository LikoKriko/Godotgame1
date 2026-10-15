extends Node3D
const Table=preload("res://scripts/prototype_3d/workbench.gd")
const PLACE_SECONDS:=3.0
const REACH:=96.0*1.75/64.0
var game
var window:Control
var progress:ProgressBar
var pending_uid:=-1
var pending_point:=Vector3.ZERO
var remaining:=0.0
var tables:Array[Node3D]=[]
var preview:Node3D
var preview_paints:Array[StandardMaterial3D]=[]
func configure(owner_game,parent_ui:Control) -> void:
 game=owner_game
 window=preload("res://scripts/workbench_window.gd").new();parent_ui.add_child(window);window.configure(game)
 window.page.icon_provider=preload("res://scripts/prototype_3d/item_icons.gd")
 for id in window.page.recipe_buttons:window.page.recipe_buttons[id].icon=window.page.icon_provider.get_icon(id)
 window.page.refresh()
 window.visibility_changed.connect(func():if not window.visible and game.paused:game.resume_world())
 preview=Table.new();add_child(preview);preview.collision_layer=0;preview.remove_from_group("prototype_workbenches");preview.hide()
 for child in preview.get_children():
  if child is MeshInstance3D:
   child.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   var paint:StandardMaterial3D=child.material_override.duplicate();paint.next_pass=null;paint.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;child.material_override=paint;preview_paints.append(paint)
 progress=ProgressBar.new();progress.show_percentage=false;progress.max_value=PLACE_SECONDS;progress.mouse_filter=Control.MOUSE_FILTER_IGNORE
 progress.add_theme_stylebox_override("background",preload("res://scripts/ui_style.gd").frame())
 var fill:=StyleBoxFlat.new();fill.bg_color=Color("d5efc7");progress.add_theme_stylebox_override("fill",fill);parent_ui.add_child(progress);progress.hide()
func placing() -> bool:return pending_uid>0
func can_place(point:Vector3) -> bool:
 if not point.is_finite() or game.player_health<=0:return false
 if point.distance_to(game.player.global_position)>REACH:return false
 var rect:=Rect2(Vector2(point.x,point.z)-Vector2(Table.SIZE.x,Table.SIZE.z)*0.5,Vector2(Table.SIZE.x,Table.SIZE.z))
 if not game.world_bounds.grow(-0.1).encloses(rect):return false
 if rect.grow(0.22).has_point(Vector2(game.player.global_position.x,game.player.global_position.z)):return false
 for table in tables:
  var occupied:=Rect2(Vector2(table.position.x,table.position.z)-Vector2(Table.SIZE.x,Table.SIZE.z)*0.5,Vector2(Table.SIZE.x,Table.SIZE.z))
  if rect.grow(0.1).intersects(occupied):return false
 if absf(point.y)>0.06:return false
 var query:=PhysicsShapeQueryParameters3D.new();var shape:=BoxShape3D.new();shape.size=Table.SIZE+Vector3(0.1,-0.08,0.1)
 query.shape=shape;query.transform.origin=point+Vector3.UP*(Table.SIZE.y*0.5+0.05);query.collision_mask=27;query.collide_with_areas=true
 if preview!=null:query.exclude=[preview.get_rid()]
 return game.get_world_3d().direct_space_state.intersect_shape(query).is_empty()
func begin_placement(point:Vector3) -> bool:
 if placing() or game.paused or game.player.locomotion.airborne() or game.player.locomotion.sliding():return false
 if not game.player.equipped or game.bag.held_id()!=&"basic_workbench":return false
 if not can_place(point):game.status.text="Elige suelo libre y cercano para colocar la mesa.";return false
 game.cancel_work();pending_uid=game.bag.held_item().uid;pending_point=point;remaining=PLACE_SECONDS
 game.player.velocity=Vector3.ZERO;game.player.locomotion.reset();progress.value=0;progress.show();return true
func cancel_placement() -> void:
 pending_uid=-1;remaining=0;progress.hide()
func advance_placement(delta:float) -> void:
 if not placing():return
 if game.player_health<=0 or game.bag.held_item().get("uid",-1)!=pending_uid or not can_place(pending_point):cancel_placement();return
 remaining=maxf(0,remaining-maxf(0,delta));progress.value=PLACE_SECONDS-remaining
 if remaining>0.000001:return
 var location:Dictionary=game.bag.location(pending_uid)
 if location.is_empty() or location.kind!=&"quick":cancel_placement();return
 var uid:=pending_uid;var point:=pending_point
 game.bag.quick_slots[location.index]={};game.bag.active_quick_uid=-1;cancel_placement();add_table(point,uid);game.sync_equipment()
 game.status.text="Mesa colocada · apunta a ella y pulsa E."
func add_table(point:Vector3,uid:int) -> Node3D:
 var table:=Table.new();table.uid=uid;add_child(table);table.position=point;tables.append(table);return table
func open_table(target:Node3D) -> bool:
 if not target.is_in_group("prototype_workbenches"):return false
 if target.global_position.distance_to(game.player.global_position)>REACH:game.status.text="Acércate a la mesa de fabricación.";return false
 game.cancel_work();game.paused=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;window.open_window();return true
func _process(delta:float) -> void:
 if game==null:return
 if not game.paused:advance_placement(delta)
 preview.visible=not game.paused and game.player.equipped and game.bag.held_id()==&"basic_workbench"
 if preview.visible:
  var hit:Dictionary=game.camera_rig.target()
  if hit.is_empty():preview.hide()
  else:
   preview.global_position=pending_point if placing() else hit.position
   var color:=Color(0.68,0.95,0.6,0.45) if can_place(preview.global_position) else Color(0.9,0.3,0.25,0.45)
   for paint in preview_paints:paint.albedo_color=color
 if placing():
  var factor:float=preload("res://scripts/game_settings.gd").hud_scale(game.settings.values.hud_size)
  progress.size=Vector2(220,14)*factor;progress.position=Vector2(game.hud.quick.position.x+(game.hud.quick.size.x*factor-progress.size.x)*0.5,game.hud.quick.position.y-progress.size.y-8)
