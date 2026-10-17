extends RefCounted
## Cache slow biome/path masks; retain original per-pixel texture detail and lighting.
const Sampler=preload("res://scripts/terrain_sampler.gd")
const STEP:=8.0
var data:Dictionary={}
var pending:Dictionary={}
var jobs:Array=[]
var ready:Array=[]
var mutex:=Mutex.new()
var worker:Thread
var serial:=0
var observer:=Vector2.ZERO
func request(key:Vector2i,rect:Rect2,sampler,profile) -> void:
 if data.has(key) or pending.has(key):return
 var influences:Array[Dictionary]=[]
 for influence in sampler.influences:
  if influence.rect.grow(maxf(influence.rect.size.x,influence.rect.size.y)*.15).intersects(rect):influences.append(influence.duplicate_deep(Resource.DEEP_DUPLICATE_ALL))
  if influences.size()==32:break
 serial+=1;pending[key]=serial
 jobs.append({"key":key,"rect":rect,"serial":serial,"seed":sampler.seed_value,"profile":profile.duplicate_deep(Resource.DEEP_DUPLICATE_ALL),"thresholds":sampler.thresholds,"paths":sampler.existing_paths,"influences":influences})
 start_next()
func start_next() -> void:
 if worker!=null or jobs.is_empty():return
 var nearest:=0;var distance:=INF
 for i in jobs.size():
  var candidate:float=jobs[i].rect.get_center().distance_squared_to(observer)
  if candidate<distance:nearest=i;distance=candidate
 worker=Thread.new();worker.start(build.bind(jobs.pop_at(nearest)))
func busy() -> bool:return not pending.is_empty()
func collect() -> Array:
 mutex.lock();var completed:Array=ready.duplicate();ready.clear();mutex.unlock()
 var changed:Array=[]
 for entry in completed:
  if pending.get(entry.key,-1)!=entry.serial:continue
  var texture:=ImageTexture.create_from_image(entry.image)
  data[entry.key]={"texture":texture,"origin":entry.origin,"size":entry.size};changed.append(entry.key)
  pending.erase(entry.key)
 if worker!=null and not worker.is_alive():worker.wait_to_finish();worker=null
 start_next();return changed
func forget(key:Vector2i) -> void:
 data.erase(key);pending.erase(key)
 jobs=jobs.filter(func(job):return job.key!=key)
func invalidate() -> void:
 jobs.clear();pending.clear();data.clear()
func finish() -> void:
 jobs.clear()
 if worker!=null:worker.wait_to_finish();worker=null
 ready.clear();pending.clear();data.clear()
func build(job:Dictionary) -> void:
 var sampler:=Sampler.new()
 sampler.seed_value=job.seed;sampler.profile=job.profile;sampler.thresholds=job.thresholds
 sampler.existing_paths=job.paths;sampler.influences=job.influences
 var rect:Rect2=job.rect
 var first:=Vector2i(floori(rect.position.x/STEP)-1,floori(rect.position.y/STEP)-1)
 var last:=Vector2i(ceili(rect.end.x/STEP)+1,ceili(rect.end.y/STEP)+1)
 var size:=last-first+Vector2i.ONE
 var values:=PackedFloat32Array();values.resize(size.x*size.y*4)
 for y in size.y:
  for x in size.x:
   var weights:=sampler.weights_at(Vector2(first+Vector2i(x,y))*STEP)
   var i:=(y*size.x+x)*4
   values[i]=weights.x;values[i+1]=weights.y;values[i+2]=weights.z;values[i+3]=weights.w
 var image:=Image.create_from_data(size.x,size.y,false,Image.FORMAT_RGBAF,values.to_byte_array())
 image.convert(Image.FORMAT_RGBAH)
 mutex.lock();ready.append({"key":job.key,"serial":job.serial,"image":image,"origin":Vector2(first)*STEP,"size":Vector2(size)});mutex.unlock()
