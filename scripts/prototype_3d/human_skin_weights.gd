extends RefCounted
## Correct heat-weight leakage onto the rib cage without changing source shape.
## The central chest/back follow the chest, with a smooth deltoid transition.
static func correct(arrays:Array) -> int:
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
 var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var changed:=0
 for i in vertices.size():
  var point:=vertices[i]
  var torso:float=(1-smoothstep(5.9,7.5,absf(point.x)))*smoothstep(34,38,point.y)*(1-smoothstep(49,51,point.y))
  if torso<=.0001:continue
  var influence:Dictionary={}
  var moving:=0.0
  for slot in 4:
   var id:=bones[i*4+slot];var amount:=weights[i*4+slot]
   influence[id]=float(influence.get(id,0.0))+amount
   if id in [0,4,5,6,7,8,9,20,21]:moving+=amount
  var maximum:=1-torso
  if moving<=maximum+.00005:continue
  var ratio:=maximum/moving
  for id in [0,4,5,6,7,8,9,20,21]:
   if influence.has(id):influence[id]*=ratio
  influence[1]=float(influence.get(1,0.0))+moving-maximum
  var order:Array=influence.keys()
  order.sort_custom(func(a,b):return influence[a]>influence[b])
  var total:=0.0
  for slot in mini(4,order.size()):total+=influence[order[slot]]
  for slot in 4:
   bones[i*4+slot]=order[slot] if slot<order.size() else 0
   weights[i*4+slot]=influence[order[slot]]/total if slot<order.size() else 0.0
  changed+=1
 arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=weights
 return changed
