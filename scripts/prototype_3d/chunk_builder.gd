extends RefCounted
## Read-only layout sampling and grass buffers; no scene or rendering API on worker.
const Layout=preload("res://scripts/prototype_3d/stream_layout.gd")
const Cover=preload("res://scripts/prototype_3d/ground_cover.gd")
var layout
var worker:Thread
var result:Dictionary={}
var mutex:=Mutex.new()
var shapes:Array=[]
func configure(source) -> void:
 finish()
 layout=Layout.new();layout.seed_value=source.seed_value
 layout.base=source.base;layout.base_chunks=source.base_chunks;layout.base_grass=source.base_grass
 layout.reservations=source.reservations
 var sampler=preload("res://scripts/terrain_sampler.gd").new()
 sampler.seed_value=source.sampler.seed_value;sampler.profile=source.sampler.profile.duplicate()
 sampler.thresholds=source.sampler.thresholds;sampler.existing_paths=source.sampler.existing_paths
 sampler.influences=source.sampler.influences.duplicate(true);layout.sampler=sampler
 for variant in 15:shapes.append(Cover.mesh_for(variant).surface_get_arrays(0))
func request(key:Vector2i) -> void:
 if worker!=null:return
 worker=Thread.new();worker.start(build.bind(key),Thread.PRIORITY_LOW)
func build(key:Vector2i) -> void:
 var data:Dictionary=layout.chunk(key)
 data.grass_mesh=Cover.build_arrays(data.grass,Vector2(key)*Layout.CHUNK_SIZE,shapes)
 mutex.lock();result={"key":key,"data":data};mutex.unlock()
func collect() -> Dictionary:
 if worker==null or worker.is_alive():return {}
 worker.wait_to_finish();worker=null
 mutex.lock();var ready:=result;result={};mutex.unlock()
 return ready
func finish() -> void:
 if worker!=null:worker.wait_to_finish();worker=null
 result.clear();shapes.clear()
