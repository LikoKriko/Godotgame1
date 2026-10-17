extends RefCounted
## Chunk-local random streams: exploration order never affects generated content.
const UNIT:=1.75/64.0
const CHUNK_SIZE:=32.0
const BOUNDS:=Rect2(-3200,-3200,6400,6400)
const Hash=preload("res://scripts/terrain_sampler.gd")
const Nature=preload("res://scripts/nature_variants.gd")
var base=preload("res://scripts/prototype_3d/world_layout.gd").new()
var base_records:Dictionary={}
var base_chunks:Dictionary={}
var base_grass:Dictionary={}
var seed_value:=0
var sampler
var reservations=preload("res://scripts/prototype_3d/story_zone_catalog.gd").new()
static func coordinate(point:Vector2) -> Vector2i:return Vector2i(floori(point.x/CHUNK_SIZE),floori(point.y/CHUNK_SIZE))
static func rect(key:Vector2i) -> Rect2:return Rect2(Vector2(key)*CHUNK_SIZE,Vector2.ONE*CHUNK_SIZE)
func configure(seed_number:int,ground_sampler) -> void:
 seed_value=seed_number;sampler=ground_sampler;base.generate(seed_number)
 base_records.clear();base_chunks.clear();base_grass.clear()
 for record in base.records:
  base_records[record.id]=record
  var key:=coordinate(Vector2(record.position.x,record.position.z))
  if not base_chunks.has(key):base_chunks[key]=[]
  base_chunks[key].append(record)
 for record in base.source.grass_tufts:
  var key:=coordinate(record.position*UNIT)
  if not base_grass.has(key):base_grass[key]=[]
  base_grass[key].append(record)
func chunk(key:Vector2i,include_grass:bool=true,include_reserved:bool=false) -> Dictionary:
 var resources:Array=[];var grass:Array=[]
 if not rect(key).intersects(BOUNDS):return {"resources":resources,"grass":grass}
 for record in base_chunks.get(key,[]):
  if include_reserved or reservations.allows_resource(record):resources.append(record)
 if include_grass:
  for record in base_grass.get(key,[]):
   if include_reserved or reservations.allows_grass(record):grass.append(record)
 var rng:=RandomNumberGenerator.new()
 rng.seed=(seed_value ^ (key.x*73856093) ^ (key.y*19349663))&0xffffffff
 # The original clearing is preserved exactly; extend its existing species,
 # dimensions and resource rules outside that authored starting area.
 for slot in 16:
  var point:=Vector2(key)*CHUNK_SIZE+Vector2(slot%4,slot/4)*8+Vector2(rng.randf_range(2,6),rng.randf_range(2,6))
  var roll:=rng.randf();var variant:=rng.randi_range(0,29);var design:=rng.randi_range(0,8)
  if base.bounds.grow(3).has_point(point) or not BOUNDS.grow(-3).has_point(point):continue
  var density:float=sampler.vegetation_density(point/UNIT)
  if sampler.path_mask(point/UNIT)>.2:continue
  var kind:=2 if roll<density*.65 else (1 if roll>.94 else (4 if roll>.91 else (5 if roll>.88 else 0)))
  if kind==0:continue
  var record:Dictionary={"id":"w2:%d:%d:%d"%[key.x,key.y,slot],"position":Vector3(point.x,0,point.y),"kind":kind,"variant":variant,"hits":3,"yield":4}
  if kind==2:record.design=design;record.height=Nature.profile(2,variant).size*UNIT
  elif kind==1:
   record.height=1.0;record.hand_collectable=false
   record.hits=[1,4,8,12][variant%4];record.yield=[2,4,10,15][variant%4]
  elif kind==4:record.hits=2;record.yield=3
  else:record.variant=1+variant%2;record.hits=1;record.yield=5 if record.variant==1 else 3
  if include_reserved or reservations.allows_resource(record):resources.append(record)
 if not include_grass:return {"resources":resources,"grass":grass}
 for slot in 64:
  var point:=Vector2(key)*CHUNK_SIZE+Vector2(slot%8,slot/8)*4+Vector2(rng.randf_range(.5,3.5),rng.randf_range(.5,3.5))
  var variant:=posmod(key.x*31+key.y*17,5)*3+rng.randi_range(0,2);var width:=rng.randf_range(10,18)
  if base.bounds.has_point(point) or not BOUNDS.has_point(point):continue
  if Hash.hash_at(key.x*8+slot%8,key.y*8+slot/8,seed_value)>sampler.vegetation_density(point/UNIT):continue
  var tuft:Dictionary={"position":point/UNIT,"variant":variant,"width":width}
  if include_reserved or reservations.allows_grass(tuft):grass.append(tuft)
 return {"resources":resources,"grass":grass}
func record_for(id:String) -> Dictionary:return lookup_record(id,{})
func lookup_record(id:String,chunks:Dictionary) -> Dictionary:
 if base_records.has(id):return base_records[id]
 var parts:=id.split(":")
 if parts.size()!=4 or parts[0]!="w2":return {}
 for i in range(1,4):
  if not parts[i].is_valid_int():return {}
 var key:=Vector2i(int(parts[1]),int(parts[2]))
 if not rect(key).intersects(BOUNDS):return {}
 if not chunks.has(key):
  var records:Dictionary={}
  for record in chunk(key,false,true).resources:records[record.id]=record
  chunks[key]=records
 return chunks[key].get(id,{})
