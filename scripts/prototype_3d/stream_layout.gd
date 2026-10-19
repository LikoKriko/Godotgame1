extends RefCounted
## Chunk-local random streams: exploration order never affects generated content.
const UNIT:=1.75/64.0
const CHUNK_SIZE:=32.0
const BOUNDS:=Rect2(-3200,-3200,6400,6400)
const Random=preload("res://scripts/world/world_random.gd")
const Hash=preload("res://scripts/terrain_sampler.gd")
const Nature=preload("res://scripts/nature_variants.gd")
var base=preload("res://scripts/prototype_3d/world_layout.gd").new()
var base_records:Dictionary={}
var base_chunks:Dictionary={}
var base_grass:Dictionary={}
const Relief=preload("res://scripts/prototype_3d/initial_relief.gd")
var relief_enabled:=false
var relief_supports:Dictionary={}
var seed_value:=0
var sampler
var reservations=preload("res://scripts/prototype_3d/story_zone_catalog.gd").new()
static func coordinate(point:Vector2) -> Vector2i:return Vector2i(floori(point.x/CHUNK_SIZE),floori(point.y/CHUNK_SIZE))
static func rect(key:Vector2i) -> Rect2:return Rect2(Vector2(key)*CHUNK_SIZE,Vector2.ONE*CHUNK_SIZE)
static func window(point:Vector3,radius:float) -> Rect2:
 # Cell centering plus half a cell covers the chosen radius before crossing.
 var center:=rect(coordinate(Vector2(point.x,point.z))).get_center()
 return Rect2(center-Vector2.ONE*(radius+CHUNK_SIZE*.5),Vector2.ONE*(radius*2+CHUNK_SIZE))
static func render_distance(radius:float,camera_offset:float) -> float:
 # Include both diagonals, cell centering, padding, retention and the final
 # intersecting chunk. The vertical allowance covers the current relief/trees.
 var extent:=radius+CHUNK_SIZE*3
 return Vector3(extent,32.0,extent).length()+camera_offset
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
 if relief_enabled:
  sampler.existing_paths=true
  for influence in base.source.terrain_influences:sampler.add_influence(influence.id,&"dirt",influence.rect,.65)
  relief_supports={}
  var support_records:Array=[]
  var area:=Relief.AREA.grow(8.0)
  var first:=coordinate(area.position);var last:=coordinate(area.end)
  for z in range(first.y,last.y+1):
   for x in range(first.x,last.x+1):support_records.append_array(chunk(Vector2i(x,z),false).resources)
  relief_supports=Relief.prepare_supports(support_records)
func chunk(key:Vector2i,include_grass:bool=true,include_reserved:bool=false) -> Dictionary:
 var resources:Array=[];var grass:Array=[]
 if not rect(key).intersects(BOUNDS):return {"resources":resources,"grass":grass}
 for record in base_chunks.get(key,[]):
  if include_reserved or reservations.allows_resource(record):resources.append(record)
 if include_grass:
  for record in base_grass.get(key,[]):
   if include_reserved or reservations.allows_grass(record):grass.append(record)
 var rng:=RandomNumberGenerator.new()
 rng.seed=Random.chunk_seed(seed_value,key)
 # The original clearing is preserved exactly; extend its existing species,
 # dimensions and resource rules outside that authored starting area.
 for slot in 16:
  var point:=Vector2(key)*CHUNK_SIZE+Vector2(slot%4,slot/4)*8+Vector2(rng.randf_range(2,6),rng.randf_range(2,6))
  var roll:=rng.randf();var variant:=rng.randi_range(0,29);var design:=rng.randi_range(0,8)
  if base.bounds.grow(3).has_point(point) or not BOUNDS.grow(-3).has_point(point):continue
  var density:float=sampler.vegetation_density(point/UNIT)
  if sampler.path_mask(point/UNIT)>sampler.profile.biome.path_clearance:continue
  var kind:int=sampler.profile.biome.resource_kind(roll,density)
  if kind==0:continue
  var record:Dictionary={"id":"w2:%d:%d:%d"%[key.x,key.y,slot],"position":Vector3(point.x,0,point.y),"kind":kind,"variant":variant,"hits":3,"yield":4}
  if kind==2:record.design=design;record.height=Nature.profile(2,variant).size*UNIT
  elif kind==1:
   record.height=1.0;record.hand_collectable=false
   record.hits=[1,4,8,12][variant%4];record.yield=[2,4,10,15][variant%4]
  elif kind==4:record.hits=2;record.yield=3
  else:record.variant=1+variant%2;record.hits=1;record.yield=5 if record.variant==1 else 3
  if include_reserved or reservations.allows_resource(record):resources.append(record)
 if not include_grass:return apply_relief(resources,grass,include_reserved)
 for slot in 64:
  var point:=Vector2(key)*CHUNK_SIZE+Vector2(slot%8,slot/8)*4+Vector2(rng.randf_range(.5,3.5),rng.randf_range(.5,3.5))
  var variant:=posmod(key.x*31+key.y*17,5)*3+rng.randi_range(0,2);var width:=rng.randf_range(10,18)
  if base.bounds.has_point(point) or not BOUNDS.has_point(point):continue
  if Hash.hash_at(key.x*8+slot%8,key.y*8+slot/8,seed_value)>sampler.vegetation_density(point/UNIT):continue
  var tuft:Dictionary={"position":point/UNIT,"variant":variant,"width":width}
  if include_reserved or reservations.allows_grass(tuft):grass.append(tuft)
 return apply_relief(resources,grass,include_reserved)
func apply_relief(resources:Array,grass:Array,raw:bool) -> Dictionary:
 if not relief_enabled or raw:return {"resources":resources,"grass":grass}
 var placed:Array=[];var tufts:Array=[]
 for record in resources:
  var point:=Vector2(record.position.x,record.position.z)
  if not Relief.clear_of_path(point,reservations.resource_radius(record)):continue
  var copy:Dictionary=record.duplicate();copy.position.y=Relief.height(point,relief_supports);placed.append(copy)
 for record in grass:
  var point:Vector2=record.position*UNIT
  if not Relief.clear_of_path(point,record.width*UNIT):continue
  var copy:Dictionary=record.duplicate();copy.ground_y=Relief.height(point,relief_supports);tufts.append(copy)
 return {"resources":placed,"grass":tufts}
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
