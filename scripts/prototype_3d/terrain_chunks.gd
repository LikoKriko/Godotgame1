extends Node3D
## Rendering is bounded; the sampler is stateless with respect to explored area.
const METRES_PER_UNIT:=1.75/64.0
const Profile = preload("res://scripts/terrain_profile.gd")
const Sampler = preload("res://scripts/terrain_sampler.gd")
const Relief=preload("res://scripts/prototype_3d/initial_relief.gd")
var relief_enabled:=false
var relief_supports:Dictionary={}
var relief_meshes:Dictionary={}
var use_mask_cache:=true
var mask_cache=preload("res://scripts/prototype_3d/terrain_mask_cache.gd").new()
var progressive_window:=false
var observer_cell:=Vector2i(999999,999999)
var observer_view:=Vector2.ZERO
var profile = Profile.new()
var sampler = Sampler.new()
var shared_material: ShaderMaterial
var mesh: PlaneMesh
var active: Dictionary = {}
var cached: Dictionary = {}
var cache_order: Array[Vector2i] = []
var pending: Array[Vector2i] = []
var wanted: Dictionary = {}
var clip_bounds := Rect2()
var bounded := false
var generations := 0
var reuses := 0
var textures: Array[Texture2D] = []
var last_view := Rect2()
var last_center := Vector2.INF
var ambient_tint := Color.WHITE
func configure(seed_number: int,configuration = null,bounds: Rect2 = Rect2()) -> bool:
 if configuration != null: profile = configuration
 if not profile.valid(): return false
 for path in profile.texture_paths:
  if not ResourceLoader.exists(path): return false
 clear_chunks()
 relief_meshes.clear()
 observer_cell=Vector2i(999999,999999);observer_view=Vector2.ZERO
 textures.clear()
 for path in profile.texture_paths: textures.append(load(path))
 sampler.configure(seed_number,profile)
 clip_bounds = bounds; bounded = bounds.has_area()
 shared_material = ShaderMaterial.new(); shared_material.shader = preload("res://shaders/prototype_3d/chunk_ground.gdshader")
 for i in 4: shared_material.set_shader_parameter(["normal_ground","dark_ground","vegetation_ground","dirt_ground"][i],textures[i])
 shared_material.set_shader_parameter("seed_value",seed_number&0xffffffff)
 shared_material.set_shader_parameter("thresholds",sampler.thresholds)
 for property in ["region_scale","transition_width","texture_span","pixel_step"]: shared_material.set_shader_parameter(property,profile.get(property))
 mesh = PlaneMesh.new(); mesh.size = Vector2.ONE*profile.chunk_size*METRES_PER_UNIT
 return true
func clear_chunks() -> void:
 mask_cache.finish()
 for node in active.values(): node.free()
 for node in cached.values(): node.free()
 active.clear(); cached.clear(); cache_order.clear(); pending.clear(); wanted.clear(); last_view = Rect2(); last_center = Vector2.INF
func coordinate(point: Vector2) -> Vector2i:
 return Vector2i(floori(point.x/profile.chunk_size),floori(point.y/profile.chunk_size))
func chunk_rect(key: Vector2i) -> Rect2:
 return Rect2(Vector2(key)*profile.chunk_size,Vector2.ONE*profile.chunk_size)
func update_window(center: Vector2,view_size: Vector2,_immediate: bool = false) -> void:
 if shared_material == null: return
 var view := Rect2(center-view_size/2,view_size)
 if view == last_view and pending.is_empty(): return
 last_view = view; last_center = center
 mask_cache.observer=center
 var load_area := view.grow(profile.preload_chunks*profile.chunk_size)
 var retain_area := view.grow(profile.retain_chunks*profile.chunk_size)
 wanted.clear()
 var first := coordinate(load_area.position); var last := coordinate(load_area.end)
 var visible_keys: Array[Vector2i] = []
 for y in range(first.y,last.y+1):
  for x in range(first.x,last.x+1):
   var key := Vector2i(x,y); var rect := chunk_rect(key)
   if bounded and not rect.intersects(clip_bounds): continue
   wanted[key] = true
   if rect.intersects(view): visible_keys.append(key)
   if not active.has(key) and not pending.has(key): pending.append(key)
 for key in active.keys():
  if chunk_rect(key).intersects(retain_area): continue
  var node: Node3D = active[key]; active.erase(key); node.hide(); cached[key] = node
  cache_order.append(key)
 while cache_order.size() > profile.cache_limit:
  var key: Vector2i = cache_order.pop_front(); cached[key].free(); cached.erase(key);mask_cache.forget(key)
 for i in range(pending.size()-1,-1,-1):
  if not wanted.has(pending[i]): pending.remove_at(i)
 pending.sort_custom(func(a,b): return chunk_rect(a).get_center().distance_squared_to(center) < chunk_rect(b).get_center().distance_squared_to(center))
 # Initial visible geometry is cheap (shared mesh/textures); no first-frame holes.
 # Normal travel stays progressive because the prefetch ring is already ahead.
 for key in visible_keys:
  if not active.has(key) and (not progressive_window or chunk_rect(key).get_center().distance_to(center)<profile.chunk_size*2):activate(key);pending.erase(key)
 advance_generation()
func advance_generation() -> void:
 for i in mini(profile.chunks_per_frame,pending.size()): activate(pending.pop_front())
func activate(key: Vector2i) -> void:
 if active.has(key): return
 if cached.has(key):
  var restored: Node3D = cached[key]; cached.erase(key); cache_order.erase(key); restored.show(); active[key] = restored; reuses += 1; return
 var node := MeshInstance3D.new(); node.mesh = mesh;node.set_meta("streamed_terrain",true)
 var rect := chunk_rect(key)
 if bounded: rect = rect.intersection(clip_bounds)
 if rect.size != Vector2.ONE*profile.chunk_size:
  var partial := PlaneMesh.new(); partial.size = rect.size*METRES_PER_UNIT; node.mesh = partial
 var metres:=Rect2(rect.position*METRES_PER_UNIT,rect.size*METRES_PER_UNIT)
 if relief_enabled and metres.intersects(Relief.AREA):
  if not relief_meshes.has(key):relief_meshes[key]=Relief.geometry(metres,relief_supports)
  node.mesh=relief_meshes[key]
 var center:=rect.get_center()*METRES_PER_UNIT
 node.position = Vector3(center.x,0,center.y); node.material_override = material_for(rect)
 add_child(node); active[key] = node; generations += 1
func material_for(rect: Rect2) -> ShaderMaterial:
 var result: ShaderMaterial = shared_material.duplicate()
 var key:=coordinate(rect.position+Vector2.ONE*.01)
 if use_mask_cache:
  mask_cache.request(key,chunk_rect(key),sampler,profile)
  if mask_cache.data.has(key):
   var grid:Dictionary=mask_cache.data[key]
   result.shader=preload("res://shaders/prototype_3d/chunk_ground_cached.gdshader")
   for uniform in shared_material.shader.get_shader_uniform_list():result.set_shader_parameter(uniform.name,shared_material.get_shader_parameter(uniform.name))
   result.set_shader_parameter("biome_mask",grid.texture);result.set_shader_parameter("mask_origin",grid.origin);result.set_shader_parameter("mask_size",grid.size);result.set_shader_parameter("mask_step",mask_cache.STEP)

 result.set_shader_parameter("initial_relief",relief_enabled)
 result.set_shader_parameter("existing_paths",sampler.existing_paths)
 var bounds := PackedVector4Array(); var types := PackedVector2Array()
 for influence in sampler.influences:
  if not influence.rect.grow(maxf(influence.rect.size.x,influence.rect.size.y)*0.15).intersects(rect): continue
  if bounds.size() == 32: push_error("Terrain influence budget exceeded in one chunk"); break
  var area: Rect2 = influence.rect
  bounds.append(Vector4(area.get_center().x,area.get_center().y,area.size.x/2,area.size.y/2))
  types.append(Vector2(Sampler.TYPES.find(influence.type),influence.strength))
 result.set_shader_parameter("influence_count",bounds.size())
 while bounds.size() < 32: bounds.append(Vector4.ZERO); types.append(Vector2.ZERO)
 result.set_shader_parameter("influence_rects",bounds); result.set_shader_parameter("influence_types",types)
 result.set_shader_parameter("ambient_tint",Vector3(ambient_tint.r,ambient_tint.g,ambient_tint.b))
 return result
func refresh_influences() -> void:
 mask_cache.invalidate()
 for key in active: active[key].material_override = material_for(chunk_rect(key))
 for key in cached: cached[key].material_override = material_for(chunk_rect(key))
func set_ambient(color: Color) -> void:
 if color == ambient_tint: return
 ambient_tint = color
 for node in active.values()+cached.values(): node.material_override.set_shader_parameter("ambient_tint",Vector3(color.r,color.g,color.b))
func _exit_tree() -> void:
 # Hidden cached nodes still belong to this parent and are freed automatically.
 mask_cache.finish()
 cached.clear(); active.clear()

func update_observer(point:Vector3,view_metres:Vector2=Vector2(28,28)) -> void:
 if progressive_window:
  var cell:=Vector2i(floori(point.x/8),floori(point.z/8))
  if cell==observer_cell and view_metres==observer_view:return
  observer_cell=cell;observer_view=view_metres
  update_window((Vector2(cell)*8+Vector2.ONE*4)/METRES_PER_UNIT,(view_metres+Vector2.ONE*8)/METRES_PER_UNIT)
 else:update_window(Vector2(point.x,point.z)/METRES_PER_UNIT,view_metres/METRES_PER_UNIT)
func _process(_delta:float) -> void:
 for key in mask_cache.collect():
  if active.has(key):active[key].material_override=material_for(chunk_rect(key))
  elif cached.has(key):cached[key].material_override=material_for(chunk_rect(key))
 if progressive_window:advance_generation()
func terrain_at(point:Vector3) -> StringName:
 return sampler.type_at(Vector2(point.x,point.z)/METRES_PER_UNIT)
func density_at(point:Vector3) -> float:
 return sampler.vegetation_density(Vector2(point.x,point.z)/METRES_PER_UNIT)
