extends RefCounted
## The existing 2D generator remains the single source of seeded placement rules.
const UNIT:=1.75/64.0
var source=preload("res://scripts/test_world.gd").new()
var resources=preload("res://scripts/harvesting.gd").new()
var bounds:Rect2
var records:Array[Dictionary]=[]
func generate(seed_value:int) -> void:
 source.generate(seed_value);resources.configure(source)
 bounds=Rect2(source.bounds.position*UNIT,source.bounds.size*UNIT);records.clear()
 for cell in source.props:
  var kind:int=source.props[cell]
  if not resources.nodes.has(cell):continue
  var node:Dictionary=resources.nodes[cell]
  var point:Vector2=(source.center(cell)+(Vector2(32,60) if source.large_rocks.has(cell) else Vector2(0,26)))*UNIT
  var record:Dictionary={"id":str(cell),"position":Vector3(point.x,0,point.y),"kind":kind,"variant":source.prop_variants.get(cell,0),"hits":node.hits,"yield":node.yield}
  if kind==2:
   record.design=source.tree_designs.get(cell,0);record.height=source.tree_dimensions(cell).y*UNIT
  if kind==1:
   record.height=source.physical_height(cell)*UNIT;record.hand_collectable=node.hand_collectable
  if kind==5:record.variant=source.burdock[cell]
  if kind==4:record.variant=posmod(cell.x*31+cell.y*17,5)
  records.append(record)
