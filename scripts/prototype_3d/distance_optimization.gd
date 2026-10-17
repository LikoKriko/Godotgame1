extends Node
## One world controller; UI and portrait viewports are deliberately excluded.
const Policy=preload("res://scripts/prototype_3d/distance_quality.gd")
var game
var materials=preload("res://scripts/prototype_3d/quality_materials.gd").new()
var meshes=preload("res://scripts/prototype_3d/quality_meshes.gd").new()
var entries:Dictionary={}
var mesh_uses:Dictionary={}
var material_uses:Dictionary={}
var elapsed:=0.0
const FRAME_BUDGET_USEC:=2000
var scheduled:Array[Dictionary]=[]
var cursor:=0
var credit:=0.0
var quality_clock:=0.0
func configure(owner_game) -> void:
 game=owner_game
 get_tree().node_added.connect(added)
 discover(game)
func discover(node:Node) -> void:
 if node!=game and (node is Viewport or node is CanvasLayer):return
 added(node)
 for child in node.get_children():discover(child)
func added(node:Node) -> void:
 if node is MeshInstance3D or node is MultiMeshInstance3D:register.call_deferred(weakref(node))
func register(reference:WeakRef) -> void:
 var node:Node=reference.get_ref()
 if not is_instance_valid(node) or not game.is_ancestor_of(node) or node.has_meta("quality_bucket"):return
 var parent:Node=node.get_parent()
 while parent!=game:
  if parent==null or parent is Viewport or parent is CanvasLayer:return
  parent=parent.get_parent()
 var id:int=node.get_instance_id()
 if entries.has(id):return
 var entry:={"node":weakref(node),"state":{},"material":node.material_override,"quality":-1,"revision":-1}
 if node is MeshInstance3D:
  if node.mesh==null:return
  entry.mesh=node.mesh;entry.center=node.mesh.get_aabb().get_center();entry.overrides=[]
  for surface in node.mesh.get_surface_count():entry.overrides.append(node.get_surface_override_material(surface))
 else:
  if node.multimesh==null or node.multimesh.mesh==null:return
  entry.mesh=node.multimesh.mesh;entry.source=node.multimesh;entry.instances=[];entry.buckets={};entry.members={}
  var count:int=node.multimesh.instance_count if node.multimesh.visible_instance_count<0 else mini(node.multimesh.visible_instance_count,node.multimesh.instance_count)
  for i in count:entry.instances.append({"transform":node.multimesh.get_instance_transform(i),"state":{},"color":node.multimesh.get_instance_color(i) if node.multimesh.use_colors else Color.WHITE,"custom":node.multimesh.get_instance_custom_data(i) if node.multimesh.use_custom_data else Color()})
 entry.slot=scheduled.size();entry.sampled_at=quality_clock;scheduled.append(entry)
 entries[id]=entry
 var mesh_id:int=entry.mesh.get_instance_id()
 mesh_uses[mesh_id]=int(mesh_uses.get(mesh_id,0))+1
 track_entry_materials(entry,true)
 # MeshInstance destruction still queries its material RIDs during tree exit.
 # Release shared LOD/material caches after that destruction has finished.
 node.tree_exiting.connect(unregister.bind(id),CONNECT_ONE_SHOT|CONNECT_DEFERRED)
func track_material(source:Material,add:bool) -> void:
 if source==null:return
 var id:=source.get_instance_id()
 var count:int=int(material_uses.get(id,0))+(1 if add else -1)
 if count>0:material_uses[id]=count
 else:material_uses.erase(id);materials.forget(source)
 if source.next_pass!=null:track_material(source.next_pass,add)
func track_entry_materials(entry:Dictionary,add:bool) -> void:
 track_material(entry.material,add)
 for surface in entry.mesh.get_surface_count():track_material(entry.mesh.surface_get_material(surface),add)
 for source in entry.get("overrides",[]):track_material(source,add)
func unregister(id:int) -> void:
 if not entries.has(id):return
 var entry:Dictionary=entries[id]
 var slot:int=entry.slot;var last:Dictionary=scheduled.pop_back()
 if slot<scheduled.size():scheduled[slot]=last;last.slot=slot
 # Keep the current sweep moving forward when old chunks retire.
 cursor=mini(cursor,scheduled.size())
 track_entry_materials(entry,false)
 var mesh_id:int=entry.mesh.get_instance_id()
 mesh_uses[mesh_id]-=1
 if mesh_uses[mesh_id]==0:mesh_uses.erase(mesh_id);meshes.forget(entry.mesh)
 entries.erase(id)
func _process(delta:float) -> void:
 if game==null or (game.paused and not game.loading_state) or not is_instance_valid(game.player):return
 meshes.collect()
 quality_clock+=maxf(0,delta)
 # Each object keeps its own sampling time; spread the tenth-second sweep
 # across frames instead of changing every LOD/material on a single frame.
 update_scheduled(delta)
 elapsed+=delta
 if elapsed+0.000001<Policy.TICK:return
 var step:=elapsed;elapsed=0
 update_grass(step)
 update_enemies()
func update_grass(delta:float,observer:Vector3=Vector3.INF,forward:Vector3=Vector3.INF) -> void:
 if not observer.is_finite():observer=game.player.global_position
 if not forward.is_finite():forward=-game.camera_rig.camera.global_basis.z
 if game.environment_content!=null and game.environment_content.has_method("update_grass_quality"):game.environment_content.update_grass_quality(observer,forward,delta)
func update_scheduled(delta:float) -> void:
 if scheduled.is_empty():credit=0;cursor=0;return
 credit=minf(scheduled.size(),credit+scheduled.size()*maxf(0,delta)/Policy.TICK)
 var count:=int(floor(credit+0.000001))
 if count==0:return
 var observer:Vector3=game.player.global_position;var forward:Vector3=-game.camera_rig.camera.global_basis.z
 var deadline:=Time.get_ticks_usec()+FRAME_BUDGET_USEC
 for i in count:
  if cursor>=scheduled.size():cursor=0
  var entry:Dictionary=scheduled[cursor];cursor+=1;credit=maxf(0,credit-1)
  update_entry(entry,maxf(0,quality_clock-entry.sampled_at),observer,forward)
  entry.sampled_at=quality_clock
  # One individual mesh/material change cannot be interrupted halfway.
  if Time.get_ticks_usec()>=deadline:break
func update_quality(delta:float,observer:Vector3=Vector3.INF,forward:Vector3=Vector3.INF) -> void:
 # Explicit full refresh for loaders, tooling and deterministic checks.
 if not observer.is_finite():observer=game.player.global_position
 if not forward.is_finite():forward=-game.camera_rig.camera.global_basis.z
 update_grass(delta,observer,forward)
 for entry in scheduled:
  update_entry(entry,delta,observer,forward);entry.sampled_at=quality_clock
func update_entry(entry:Dictionary,delta:float,observer:Vector3,forward:Vector3) -> void:
 var node=entry.node.get_ref()
 if not is_instance_valid(node) or not node.is_inside_tree():return
 if node.material_override!=entry.material and (node.material_override==null or not node.material_override.has_meta("distance_quality_variant")):
  track_material(entry.material,false);track_material(node.material_override,true)
  entry.material=node.material_override;entry.quality=-1
 if node is MultiMeshInstance3D:update_batch(node,entry,observer,forward,delta);return
 var point:Vector3=node.to_global(entry.center)
 var percent:=Policy.advance(entry.state,observer.distance_to(point),Policy.behind(point,observer,forward),delta)
 var source_revision:int=1 if meshes.cache.has(entry.mesh.get_instance_id()) else 0
 if entry.quality==percent and entry.revision==source_revision:return
 var replacement:Mesh=meshes.mesh(entry.mesh,percent)
 if node.mesh!=replacement:
  var morphs:PackedFloat32Array=[]
  if node.mesh is ArrayMesh:
   for i in node.mesh.get_blend_shape_count():morphs.append(node.get_blend_shape_value(i))
  node.mesh=replacement
  for i in morphs.size():node.set_blend_shape_value(i,morphs[i])
 node.material_override=materials.material(entry.material,percent,node.material_override)
 for surface in entry.mesh.get_surface_count():
  var original:Material=entry.overrides[surface]
  if original==null:original=entry.mesh.surface_get_material(surface)
  node.set_surface_override_material(surface,materials.material(original,percent,node.get_surface_override_material(surface)))
 entry.quality=percent;entry.revision=source_revision
func update_batch(node:MultiMeshInstance3D,entry:Dictionary,observer:Vector3,forward:Vector3,delta:float) -> void:
 # Batch by budget rather than treating thousands of scattered tufts as one
 # object at the origin. Rebuild buffers only when membership actually changes.
 var groups:Dictionary={}
 for i in entry.instances.size():
  var instance:Dictionary=entry.instances[i]
  var point:Vector3=node.to_global(instance.transform.origin)
  var percent:=Policy.advance(instance.state,observer.distance_to(point),Policy.behind(point,observer,forward),delta)
  if not groups.has(percent):groups[percent]=[]
  groups[percent].append(i)
 for percent in entry.buckets:
  if not groups.has(percent):entry.buckets[percent].hide()
 for percent in groups:
  var target:MultiMeshInstance3D
  if not entry.buckets.has(percent):
   target=MultiMeshInstance3D.new();target.set_meta("quality_bucket",true)
   target.cast_shadow=node.cast_shadow;target.layers=node.layers
   node.add_child(target);entry.buckets[percent]=target
  target=entry.buckets[percent];target.show()
  if entry.members.get(percent,[])!=groups[percent]:
   var batch:=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D
   batch.use_colors=entry.source.use_colors;batch.use_custom_data=entry.source.use_custom_data
   batch.mesh=meshes.mesh(entry.mesh,percent);batch.instance_count=groups[percent].size()
   for destination in groups[percent].size():
    var original:Dictionary=entry.instances[groups[percent][destination]]
    batch.set_instance_transform(destination,original.transform)
    if batch.use_colors:batch.set_instance_color(destination,original.color)
    if batch.use_custom_data:batch.set_instance_custom_data(destination,original.custom)
   target.multimesh=batch;entry.members[percent]=groups[percent].duplicate()
  target.multimesh.mesh=meshes.mesh(entry.mesh,percent)
  var original:Material=entry.material if entry.material!=null else entry.mesh.surface_get_material(0)
  target.material_override=materials.material(original,percent,target.material_override)
 # Keep the original instance buffer immutable for other scenes/users.
 if node.multimesh==entry.source:
  var empty:=MultiMesh.new();empty.transform_format=MultiMesh.TRANSFORM_3D
  empty.use_colors=entry.source.use_colors;empty.use_custom_data=entry.source.use_custom_data
  empty.mesh=entry.mesh;empty.instance_count=entry.source.instance_count
  var buffer:PackedFloat32Array=entry.source.buffer
  if not buffer.is_empty():empty.buffer=buffer
  empty.visible_instance_count=0
  node.multimesh=empty
func update_enemies() -> void:
 for enemy in get_tree().get_nodes_in_group("prototype_enemies"):
  if enemy.game!=game or enemy.is_queued_for_deletion():continue
  var far:bool=enemy.global_position.distance_squared_to(game.player.global_position)>=Policy.ENEMY_DISTANCE*Policy.ENEMY_DISTANCE
  if far and not enemy.distance_suspended:enemy.suspend_distance()
  elif not far and enemy.distance_suspended:enemy.resume_distance()
func _exit_tree() -> void:
 meshes.finish()
