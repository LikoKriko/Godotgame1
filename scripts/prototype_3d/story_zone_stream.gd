extends Node3D
## One instance per zone, even across chunk borders; one box built per step.
var catalogue
var active:Dictionary={}
var pending:Array[String]=[]
var retiring:Array[String]=[]
func configure(source) -> void:catalogue=source
func update_window(area:Rect2,retention:float=32.0) -> void:
 pending.clear();retiring.clear()
 for zone in catalogue.records:
  if zone.reserved.intersects(area) and not active.has(zone.id):pending.append(zone.id)
 for id in active:
  if not catalogue.by_id[id].reserved.intersects(area.grow(retention)):retiring.append(id)
 pending.sort_custom(func(a,b):return catalogue.by_id[a].rect.get_center().distance_squared_to(area.get_center())<catalogue.by_id[b].rect.get_center().distance_squared_to(area.get_center()))
func busy() -> bool:
 if not pending.is_empty() or not retiring.is_empty():return true
 for entry in active.values():
  if not entry.complete:return true
 return false
func advance() -> void:
 if not retiring.is_empty():
  var id:String=retiring.pop_front();active[id].node.free();active.erase(id);return
 if not pending.is_empty():
  var id:String=pending.pop_front();var zone:Dictionary=catalogue.by_id[id]
  var holder:=Node3D.new();holder.name=id;holder.position=zone.position;holder.set_meta("story_zone_id",id);holder.add_to_group("prototype_story_zones");add_child(holder)
  active[id]={"node":holder,"next":-1,"complete":false};return
 for id in active:
  var entry:Dictionary=active[id]
  if entry.complete:continue
  var zone:Dictionary=catalogue.by_id[id]
  if entry.next<0:
   add_box(entry.node,"floor",Vector3(0,.005,0),Vector3(zone.rect.size.x,.01,zone.rect.size.y),zone.floor_color,false)
  else:
   var box:Dictionary=zone.boxes[entry.next]
   add_box(entry.node,box.id,box.offset+Vector3.UP*box.size.y*.5,box.size,box.color,true)
  entry.next+=1;entry.complete=entry.next>=zone.boxes.size();return
func add_box(holder:Node3D,id:String,position:Vector3,size:Vector3,color:Color,solid:bool) -> void:
 var body:=StaticBody3D.new();body.name=id;body.position=position;body.set_meta("story_element_id",id);body.collision_layer=1;body.collision_mask=0;holder.add_child(body)
 var visual:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;visual.mesh=mesh
 var paint:=StandardMaterial3D.new();paint.albedo_color=color;paint.roughness=1;visual.material_override=paint;body.add_child(visual)
 if solid:
  var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;collision.shape=shape;body.add_child(collision)
