extends Node2D
## Rendering is bounded; the sampler is stateless with respect to explored area.
const Profile = preload("res://scripts/terrain_profile.gd")
const Sampler = preload("res://scripts/terrain_sampler.gd")
var profile = Profile.new()
var sampler = Sampler.new()
var shared_material: ShaderMaterial
var mesh: QuadMesh
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
 textures.clear()
 for path in profile.texture_paths: textures.append(load(path))
 sampler.configure(seed_number,profile)
 clip_bounds = bounds; bounded = bounds.has_area()
 shared_material = ShaderMaterial.new(); shared_material.shader = preload("res://shaders/chunk_ground.gdshader")
 for i in 4: shared_material.set_shader_parameter(["normal_ground","dark_ground","vegetation_ground","dirt_ground"][i],textures[i])
 shared_material.set_shader_parameter("seed_value",seed_number&0xffffffff)
 shared_material.set_shader_parameter("thresholds",sampler.thresholds)
 for property in ["region_scale","transition_width","texture_span","pixel_step"]: shared_material.set_shader_parameter(property,profile.get(property))
 mesh = QuadMesh.new(); mesh.size = Vector2.ONE*profile.chunk_size
 texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 return true
func clear_chunks() -> void:
 for node in active.values(): node.free()
 for node in cached.values(): node.free()
 active.clear(); cached.clear(); cache_order.clear(); pending.clear(); wanted.clear(); last_view = Rect2(); last_center = Vector2.INF
func coordinate(point: Vector2) -> Vector2i:
 return Vector2i(floori(point.x/profile.chunk_size),floori(point.y/profile.chunk_size))
func chunk_rect(key: Vector2i) -> Rect2:
 return Rect2(Vector2(key)*profile.chunk_size,Vector2.ONE*profile.chunk_size)
func update_window(center: Vector2,view_size: Vector2,immediate: bool = false) -> void:
 if shared_material == null: return
 var view := Rect2(center-view_size/2,view_size)
 if view == last_view and pending.is_empty(): return
 last_view = view; last_center = center
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
  var node: Node2D = active[key]; active.erase(key); node.hide(); cached[key] = node
  cache_order.append(key)
 while cache_order.size() > profile.cache_limit:
  var key: Vector2i = cache_order.pop_front(); cached[key].free(); cached.erase(key)
 for i in range(pending.size()-1,-1,-1):
  if not wanted.has(pending[i]): pending.remove_at(i)
 pending.sort_custom(func(a,b): return chunk_rect(a).get_center().distance_squared_to(center) < chunk_rect(b).get_center().distance_squared_to(center))
 # Initial visible geometry is cheap (shared mesh/textures); no first-frame holes.
 # Normal travel stays progressive because the prefetch ring is already ahead.
 for key in visible_keys:
  if not active.has(key): activate(key); pending.erase(key)
 advance_generation()
func advance_generation() -> void:
 for i in mini(profile.chunks_per_frame,pending.size()): activate(pending.pop_front())
func activate(key: Vector2i) -> void:
 if active.has(key): return
 if cached.has(key):
  var restored: Node2D = cached[key]; cached.erase(key); cache_order.erase(key); restored.show(); active[key] = restored; reuses += 1; return
 var node := MeshInstance2D.new(); node.mesh = mesh
 var rect := chunk_rect(key)
 if bounded: rect = rect.intersection(clip_bounds)
 if rect.size != mesh.size:
  var partial := QuadMesh.new(); partial.size = rect.size; node.mesh = partial
 node.position = rect.get_center(); node.material = material_for(rect)
 add_child(node); active[key] = node; generations += 1
func material_for(rect: Rect2) -> ShaderMaterial:
 var result: ShaderMaterial = shared_material.duplicate()
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
 for key in active: active[key].material = material_for(chunk_rect(key))
 for key in cached: cached[key].material = material_for(chunk_rect(key))
func set_ambient(color: Color) -> void:
 if color == ambient_tint: return
 ambient_tint = color
 for node in active.values()+cached.values(): node.material.set_shader_parameter("ambient_tint",Vector3(color.r,color.g,color.b))
func _exit_tree() -> void:
 # Hidden cached nodes still belong to this parent and are freed automatically.
 cached.clear(); active.clear()
