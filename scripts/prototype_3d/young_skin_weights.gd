extends RefCounted
## The supplied long tail needs its own hinge to rest beside a fallen body.
const TAIL_ANCHOR:=Vector3(0,14,-13)
static func correct(arrays:Array) -> int:
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
 var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var changed:=0
 for i in vertices.size():
  var point:=vertices[i]
  var share:=smoothstep(13.5,17,-point.z)*(1-smoothstep(3,5,absf(point.x)))*smoothstep(8,10,point.y)*(1-smoothstep(18,22,point.y))
  if share<=.0001:continue
  var influence:Dictionary={}
  for slot in 4:
   var id:=bones[4*i+slot];influence[id]=float(influence.get(id,0.0))+weights[4*i+slot]
  var total:float=float(influence.get(0,0.0))+float(influence.get(14,0.0))
  var wanted:=total*share
  if absf(wanted-float(influence.get(14,0.0)))<.00005:continue
  influence[0]=total-wanted;influence[14]=wanted
  var order:Array=influence.keys();order.sort_custom(func(a,b):return influence[a]>influence[b])
  var sum:=0.0
  for slot in mini(4,order.size()):sum+=influence[order[slot]]
  for slot in 4:
   bones[4*i+slot]=order[slot] if slot<order.size() else 0
   weights[4*i+slot]=influence[order[slot]]/sum if slot<order.size() else 0.0
  changed+=1
 arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=weights
 return changed
