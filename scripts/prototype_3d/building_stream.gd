extends Node3D
## Interior fragments share the exterior's world. No scene change or teleport.
signal ready_changed(value:bool)
signal load_failed(path:String)
@export var fragments:Array[String]=[]
@export var content_scale:=Vector3.ONE
@export var door_offset:=Vector3.ZERO
@export var start_distance:=18.0
@export var ready_distance:=3.0
@export var unload_distance:=26.0
@export var frame_budget_ms:=2.0
@export var near_budget_ms:=6.0
@export var interior_bounds:=AABB(Vector3(-3,0,-6),Vector3(6,3,6))
@export var guard_size:=Vector3(1.4,2.2,0.12)
var observer:Node3D
var interior_ready:=false
var active:=false
var failed:=false
var built:=0
var requests:Dictionary={}
var loaded:Dictionary={}
var content:Node3D
var guard:StaticBody3D
var guard_shape:CollisionShape3D
func _ready() -> void:
 guard=StaticBody3D.new();guard.collision_layer=1;guard.collision_mask=2
 guard.position=door_offset+Vector3.UP*guard_size.y*0.5;add_child(guard)
 guard_shape=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=guard_size;guard_shape.shape=shape;guard.add_child(guard_shape)
func _process(_delta:float) -> void:
 if is_instance_valid(observer):update_stream(observer.global_position)
func progress() -> float:return float(built)/maxi(1,fragments.size())
func can_enter() -> bool:return interior_ready
func update_stream(point:Vector3) -> void:
 var distance:=point.distance_to(to_global(door_offset))
 var inside:=interior_bounds.has_point(to_local(point))
 var wanted:=inside or distance<start_distance or (active and distance<unload_distance)
 if not wanted and active:unload()
 if wanted and not active and not failed:begin_loading()
 poll_requests()
 if not active or interior_ready or failed:return
 var deadline:=Time.get_ticks_usec()+int((near_budget_ms if distance<=ready_distance else frame_budget_ms)*1000)
 # Fragment scenes must be small: instantiation itself cannot be interrupted.
 while built<fragments.size() and Time.get_ticks_usec()<deadline:
  var path:=fragments[built]
  if not loaded.has(path):break
  var instance:Node=(loaded[path] as PackedScene).instantiate()
  content.add_child(instance);built+=1
 if built==fragments.size():
  interior_ready=true;content.show();content.process_mode=Node.PROCESS_MODE_INHERIT
  guard_shape.set_deferred("disabled",true);ready_changed.emit(true)
  loaded.clear()
func begin_loading() -> void:
 active=true;built=0
 content=Node3D.new();content.scale=content_scale;content.name="StreamedInterior";content.hide();content.process_mode=Node.PROCESS_MODE_DISABLED;add_child(content)
 for path in fragments:
  if requests.has(path) or loaded.has(path):continue
  if not ResourceLoader.exists(path,"PackedScene"):
   fail(path);return
  var error:=ResourceLoader.load_threaded_request(path,"PackedScene",false,ResourceLoader.CACHE_MODE_IGNORE)
  if error!=OK:fail(path);return
  requests[path]=true
func poll_requests() -> void:
 for path in requests.keys():
  var status:=ResourceLoader.load_threaded_get_status(path)
  if status==ResourceLoader.THREAD_LOAD_LOADED:
   var scene=ResourceLoader.load_threaded_get(path)
   requests.erase(path)
   if active and scene is PackedScene:loaded[path]=scene
  elif status in [ResourceLoader.THREAD_LOAD_FAILED,ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
   requests.erase(path)
   if active:fail(path)
func fail(path:String) -> void:
 failed=true;unload();load_failed.emit(path)
func unload() -> void:
 var was_ready:=interior_ready
 active=false;interior_ready=false;built=0;loaded.clear()
 if is_instance_valid(content):content.queue_free();content=null
 if is_instance_valid(guard_shape):guard_shape.set_deferred("disabled",false)
 if was_ready:ready_changed.emit(false)
 # In-flight requests are drained without blocking. Their results are released
 # when no longer needed, or reused if the player comes back before completion.
