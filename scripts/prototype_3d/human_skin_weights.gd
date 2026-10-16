extends RefCounted
## Partition torso and arm surfaces independently. In the imported rest pose
## the inner biceps lie beside the ribs, inside the torso's overall X extent.
## A box mask freezes those vertices to the chest and stretches the arm on lift.
static func arm_share(point:Vector3) -> float:
 var shoulder:=smoothstep(42,48,point.y)
 var lower:=smoothstep(34,42,point.y)
 var inner:=lerpf(lerpf(6.1,4.9,lower),4.0,shoulder)
 var outer:=lerpf(lerpf(6.7,5.35,lower),6.65,shoulder)
 var lateral:=smoothstep(inner,outer,absf(point.x))
 # Protect the scapular surface, while the outer deltoid and the entire
 # detached upper-arm ring remain free to follow the humerus.
 var scapula:=smoothstep(43,46,point.y)*(1-smoothstep(4.7,6.5,absf(point.x)))*(1-smoothstep(.2,1.8,point.z))
 var original:=lateral*(1-smoothstep(46,51.5,point.y))*(1-.95*scapula)
 # The inner axillary strip has very short edges. A sub-unit X transition
 # made adjacent vertices follow radically different transforms during a jab.
 # Spread that change over the local fold, without changing the arm/elbow rings.
 var fold:=smoothstep(41.5,43,point.y)*(1-smoothstep(45,47,point.y))*smoothstep(3.8,5.2,absf(point.x))
 var broad:=smoothstep(3.6,7.2,absf(point.x))*(1-.95*scapula)
 return lerpf(original,broad,fold)

static func correct(arrays:Array) -> int:
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
 var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var changed:=0
 for i in vertices.size():
  var point:=vertices[i]
  if point.y<34 or point.y>54:continue
  var influence:Dictionary={}
  for slot in 4:
   var id:=bones[i*4+slot]
   influence[id]=float(influence.get(id,0.0))+weights[i*4+slot]
  var side:=0 if point.x<0 else 1
  var start:=4+side*3
  var arm_ids:=[start,start+1,start+2,20+side]
  var arm_total:=0.0;var total:=0.0
  for id in [0,1,4,5,6,7,8,9,20,21]:
   var amount:float=influence.get(id,0.0);total+=amount
   if id in arm_ids:arm_total+=amount
  if total<.0001:continue
  # Bound the pelvis contribution once; applying the bake twice must be inert.
  var pelvis:=minf(float(influence.get(0,0)),total*(1-smoothstep(34,37,point.y)))
  var wanted:=(total-pelvis)*arm_share(point)
  if absf(wanted-arm_total)<.00005 and absf(float(influence.get(0,0))-pelvis)<.00005:continue
  for id in [0,1,4,5,6,7,8,9,20,21]:
   if id in arm_ids:
    influence[id]=float(influence.get(id,0.0))*wanted/arm_total if arm_total>.0001 else (wanted if id==start else 0.0)
   else:influence[id]=0.0
  influence[0]=pelvis
  influence[1]=maxf(0,total-wanted-pelvis)
  var order:Array=influence.keys()
  order.sort_custom(func(a,b):return influence[a]>influence[b])
  var weight_sum:=0.0
  for slot in mini(4,order.size()):weight_sum+=influence[order[slot]]
  for slot in 4:
   bones[i*4+slot]=order[slot] if slot<order.size() else 0
   weights[i*4+slot]=influence[order[slot]]/weight_sum if slot<order.size() else 0.0
  changed+=1
 arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=weights
 return changed
