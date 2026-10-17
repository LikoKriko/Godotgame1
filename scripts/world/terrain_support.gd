extends RefCounted
## Spatially indexed support pads, independent from the initial trial or a species.
static func build(records:Array,base_height:Callable,radius_for:Callable,area:Rect2,margin:float=.05,blend:float=.75) -> Dictionary:
 if not base_height.is_valid() or not radius_for.is_valid() or not area.position.is_finite() or not area.size.is_finite() or not area.has_area() or not is_finite(margin) or margin<0 or not is_finite(blend) or blend<=0:return {}
 var pads:Array=[]
 for record in records:
  var point:=Vector2(record.position.x,record.position.z);var radius:=float(radius_for.call(record))
  if not is_finite(radius) or radius<=0:continue
  var core:=radius+2.0*radius*margin
  if not area.grow(core+blend).has_point(point):continue
  var altitude:=float(base_height.call(point))
  if not is_finite(altitude):continue
  var edge:=not area.grow(-core-blend).has_point(point)
  if edge:altitude=0.0
  pads.append({"point":point,"radius":radius,"core":core,"altitude":altitude,"cluster":pads.size(),"edge":edge})
 # Overlapping bases share one elevation, avoiding contradictory flat supports.
 for i in pads.size():
  for j in i:
   if pads[i].point.distance_to(pads[j].point)>pads[i].core+pads[j].core:continue
   var old:int=pads[i].cluster;var target:int=pads[j].cluster
   for pad in pads:
    if pad.cluster==old:pad.cluster=target
 var sums:Dictionary={};var counts:Dictionary={};var edges:Dictionary={}
 for pad in pads:
  if pad.edge:edges[pad.cluster]=true
  sums[pad.cluster]=sums.get(pad.cluster,0.0)+pad.altitude;counts[pad.cluster]=counts.get(pad.cluster,0)+1
 var index:Dictionary={}
 for pad in pads:
  pad.altitude=0.0 if edges.has(pad.cluster) else sums[pad.cluster]/counts[pad.cluster]
  var extent:float=pad.core+blend
  var first:=Vector2i(floori((pad.point.x-extent)/8),floori((pad.point.y-extent)/8))
  var last:=Vector2i(floori((pad.point.x+extent)/8),floori((pad.point.y+extent)/8))
  for z in range(first.y,last.y+1):
   for x in range(first.x,last.x+1):
    var cell:=Vector2i(x,z)
    if not index.has(cell):index[cell]=[]
    index[cell].append(pad)
 return index
static func sample(point:Vector2,original:float,supports:Dictionary,blend:float=.75) -> float:
 var p:=point
 var weighted:=original;var total:=1.0
 for pad in supports.get(Vector2i(floori(p.x/8),floori(p.y/8)),[]):
  var amount:=1.0-smoothstep(pad.core,pad.core+blend,p.distance_to(pad.point))
  if amount>=.99999:return pad.altitude
  var weight:float=amount/maxf(.00001,1.0-amount)
  weighted+=pad.altitude*weight;total+=weight
 return weighted/total
