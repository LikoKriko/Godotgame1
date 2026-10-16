extends RefCounted
## Native meshoptimizer LODs are prepared off the gameplay thread and shared.
var cache:Dictionary={}
var pending:Dictionary={}
var completed:Array=[]
var mutex:=Mutex.new()
var worker:Thread
var queue:Array[Mesh]=[]
var discarded:Dictionary={}
func forget(source:Mesh) -> void:
 var id:=source.get_instance_id()
 var queued:=queue.has(source)
 queue.erase(source);cache.erase(id)
 if pending.has(id) and not queued:discarded[id]=true
 pending.erase(id)
func mesh(source:Mesh,percent:int) -> Mesh:
 if source==null or percent>=100:return source
 var id:=source.get_instance_id()
 discarded.erase(id)
 if cache.has(id):return cache[id].get(percent,source)
 if not pending.has(id):
  # PrimitiveMesh builds its vertex buffers lazily. Initialize them on the
  # owning thread before the background worker reads immutable arrays.
  if source is PrimitiveMesh:source.get_mesh_arrays()
  pending[id]=source
  queue.append(source)
  start_next()
 return source
func collect() -> void:
 mutex.lock();var ready:=completed.duplicate();completed.clear();mutex.unlock()
 for entry in ready:
  if not discarded.has(entry.id):cache[entry.id]=materialize(entry)
  discarded.erase(entry.id);pending.erase(entry.id)
 if worker!=null and not worker.is_alive():worker.wait_to_finish();worker=null
 start_next()
func start_next() -> void:
 if worker!=null or queue.is_empty():return
 worker=Thread.new();worker.start(prepare.bind(queue.pop_front()))
func finish() -> void:
 queue.clear()
 if worker!=null:worker.wait_to_finish();worker=null
 collect();pending.clear()
func prepare(source:Mesh) -> void:
 var importer:=ImporterMesh.new()
 if source is ArrayMesh:
  for i in source.get_blend_shape_count():importer.add_blend_shape(source.get_blend_shape_name(i))
  importer.set_blend_shape_mode(source.blend_shape_mode)
 for surface in source.get_surface_count():
  var shapes:Array=source.surface_get_blend_shape_arrays(surface) if source is ArrayMesh else []
  var format:int=source.surface_get_format(surface) if source is ArrayMesh else 0
  var primitive:int=source.surface_get_primitive_type(surface) if source is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES
  importer.add_surface(primitive,source.surface_get_arrays(surface),shapes,{},source.surface_get_material(surface),"",format)
 importer.generate_lods(60.0,25.0,[])
 var built:Dictionary={};var variants:Dictionary={}
 for percent in range(35,100,5):
  var choices:Array[int]=[];var original:=true
  for surface in importer.get_surface_count():
   var arrays:Array=importer.get_surface_arrays(surface)
   var count:int=arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size()
   var wanted:=count*percent/100.0;var best:=-1;var error:=absf(count-wanted)
   for lod in importer.get_surface_lod_count(surface):
    var candidate:int=importer.get_surface_lod_indices(surface,lod).size()
    if candidate>=3 and absf(candidate-wanted)<error:best=lod;error=absf(candidate-wanted)
   choices.append(best);original=original and best<0
  if original:variants[percent]=source;continue
  var key:=str(choices)
  if not built.has(key):
   var surfaces:Array=[]
   for surface in importer.get_surface_count():
    var arrays:Array=importer.get_surface_arrays(surface)
    if choices[surface]>=0:arrays[Mesh.ARRAY_INDEX]=importer.get_surface_lod_indices(surface,choices[surface])
    var shapes:Array=[]
    if source is ArrayMesh:
     for shape in source.get_blend_shape_count():shapes.append(importer.get_surface_blend_shape_arrays(surface,shape))
    surfaces.append({"arrays":arrays,"shapes":shapes,"primitive":importer.get_surface_primitive_type(surface),"format":source.surface_get_format(surface) if source is ArrayMesh else 0,"material":source.surface_get_material(surface)})
   built[key]=surfaces
  variants[percent]=key
 mutex.lock();completed.append({"id":source.get_instance_id(),"source":source,"variants":variants,"built":built});mutex.unlock()
func materialize(entry:Dictionary) -> Dictionary:
 # Mesh optimization is CPU work; create/free rendering RIDs on the owning
 # thread. Streaming creates and destroys nodes concurrently with the worker.
 var source:Mesh=entry.source
 var built:Dictionary={};var variants:Dictionary={}
 for key in entry.built:
  var result:=ArrayMesh.new()
  if source is ArrayMesh:
   for i in source.get_blend_shape_count():result.add_blend_shape(source.get_blend_shape_name(i))
   result.blend_shape_mode=source.blend_shape_mode
  for surface in entry.built[key]:
   result.add_surface_from_arrays(surface.primitive,surface.arrays,surface.shapes,{},surface.format)
   result.surface_set_material(result.get_surface_count()-1,surface.material)
  result.custom_aabb=source.get_aabb();built[key]=result
 for percent in entry.variants:
  var value=entry.variants[percent]
  variants[percent]=built[value] if value is String else source
 return variants
