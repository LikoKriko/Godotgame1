extends RefCounted
## Immutable world-space reservations, independent of the procedural seed.
const PATH:="res://data/world/story_zones.json"
const DATA:JSON=preload("res://data/world/story_zones.json")
const BOUNDS:=Rect2(-3200,-3200,6400,6400)
const UNIT:=1.75/64.0
var records:Array[Dictionary]=[]
var by_id:Dictionary={}
func _init() -> void:
 var data=DATA.data
 if not data is Dictionary or data.get("version")!=1 or not configure(data.get("zones")):push_error("Invalid story-zone catalogue: "+PATH)
static func number(value,low:float,high:float) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and value>=low and value<=high
static func vector(value,low:float,high:float) -> bool:
 if not value is Array or value.size()!=3:return false
 for component in value:
  if not number(component,low,high):return false
 return true
static func identifier(value) -> bool:return value is String and value.length()<=64 and value.is_valid_identifier()
func configure(definitions) -> bool:
 if not definitions is Array or definitions.size()>256:return false
 var checked:Array[Dictionary]=[];var ids:Dictionary={}
 for entry in definitions:
  if not entry is Dictionary or not identifier(entry.get("id")) or ids.has(entry.id):return false
  if not vector(entry.get("position"),-3200,3200) or not number(entry.position[1],-2,24):return false
  var size=entry.get("size")
  if not size is Array or size.size()!=2 or not number(size[0],1,512) or not number(size[1],1,512):return false
  if not number(entry.get("buffer"),0,64) or not entry.get("floor_color") is String or not Color.html_is_valid(entry.floor_color):return false
  if not entry.get("boxes") is Array or entry.boxes.size()>128:return false
  var position:=Vector3(entry.position[0],entry.position[1],entry.position[2])
  var area:=Rect2(Vector2(position.x,position.z)-Vector2(size[0],size[1])*.5,Vector2(size[0],size[1]))
  var reserved:=area.grow(entry.buffer)
  if not BOUNDS.encloses(reserved):return false
  for previous in checked:
   if previous.reserved.intersects(reserved,true):return false
  var boxes:Array[Dictionary]=[];var box_ids:Dictionary={}
  for box in entry.boxes:
   if not box is Dictionary or not identifier(box.get("id")) or box_ids.has(box.id) or box.id=="floor":return false
   if not vector(box.get("offset"),-512,512) or not vector(box.get("size"),.1,512):return false
   if box.offset[1]<0 or position.y+box.offset[1]+box.size[1]>30:return false
   if absf(box.offset[0])+box.size[0]*.5>size[0]*.5 or absf(box.offset[2])+box.size[2]*.5>size[1]*.5:return false
   if not box.get("color") is String or not Color.html_is_valid(box.color):return false
   boxes.append({"id":box.id,"offset":Vector3(box.offset[0],box.offset[1],box.offset[2]),"size":Vector3(box.size[0],box.size[1],box.size[2]),"color":Color(box.color)})
   box_ids[box.id]=true
  checked.append({"id":entry.id,"position":position,"rect":area,"reserved":reserved,"buffer":float(entry.buffer),"floor_color":Color(entry.floor_color),"boxes":boxes})
  ids[entry.id]=checked[-1]
 records=checked;by_id=ids;return true
func intersects(area:Rect2) -> bool:
 for zone in records:
  if zone.reserved.intersects(area,true):return true
 return false
func allows(point:Vector2,radius:float=0.0) -> bool:
 var extent:=maxf(.001,radius)
 return not intersects(Rect2(point-Vector2.ONE*extent,Vector2.ONE*extent*2))
static func resource_radius(record:Dictionary) -> float:
 if record.kind==2:return maxf(.75,record.get("height",3.5)*.65)
 if record.kind==1:return 1.5
 return .75
func allows_resource(record:Dictionary) -> bool:return allows(Vector2(record.position.x,record.position.z),resource_radius(record))
func allows_grass(record:Dictionary) -> bool:return allows(record.position*UNIT,record.width*UNIT)
