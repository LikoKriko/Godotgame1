extends RefCounted
## Cache the native skinned sole envelope in ankle space, independent of scale.
var soles:Array[Array]=[]
var skin_samples:Array[Array]=[]
func configure(native:RefCounted) -> void:
 soles=[[],[]];skin_samples=[[],[]]
 var influences:Array[Array]=[[],[]]
 var records:Array[Array]=[[],[]]
 var owners:Array[int]=[]
 for bone in native.parents.size():
  var owner:=-1
  var ancestor:int=bone
  while ancestor>=0:
   for side in 2:
    if ancestor==native.legs[side].ids[2]:owner=side
   ancestor=native.parents[ancestor]
  owners.append(owner)
 for surface in native.mesh.mesh.get_surface_count():
  var arrays:Array=native.mesh.mesh.surface_get_arrays(surface)
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var ids:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
  var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
  var slots:int=ids.size()/vertices.size()
  for vertex in vertices.size():
   var total:=[0.0,0.0]
   var point:=Vector3.ZERO
   var record:Array=[]
   for slot in slots:
    var index:int=vertex*slots+slot
    var weight:float=weights[index]
    if weight<=0:continue
    var bind:int=ids[index]
    var bone:int=native.mesh.skin.get_bind_bone(bind)
    if owners[bone]>=0:total[owners[bone]]+=weight
    var local:Vector3=(native.mesh.skin.get_bind_pose(bind)*vertices[vertex])*weight
    record.append([bone,local,weight])
    point+=native.posed[bone].basis*local+native.posed[bone].origin*weight
   for side in 2:
    if total[side]>=.75:
     records[side].append(point);influences[side].append(record)
 for side in 2:
  var low:=INF
  for point in records[side]:low=minf(low,point.y)
  skin_samples[side]=influences[side]
  var inverse:Transform3D=native.posed[native.legs[side].ids[2]].affine_inverse()
  for direction in [Vector3(1,0,1),Vector3(-1,0,1),Vector3(1,0,-1),Vector3(-1,0,-1),Vector3.DOWN]:
   var best:=-INF
   var selected:=Vector3.ZERO
   for point in records[side]:
    if point.y>low+.02/(1.75/64.0):continue
    var score:float=point.dot(direction)
    if score>best:best=score;selected=point
   soles[side].append(inverse*selected)

func clearance(side:int,goal:Transform3D) -> float:
 var lowest:=INF
 for point in soles[side]:lowest=minf(lowest,(goal*point).y*(1.75/64.0))
 return maxf(0,lowest)

func skinned_points(native:RefCounted,side:int) -> Array[Vector3]:
 var points:Array[Vector3]=[]
 var cells:Dictionary={}
 for record in skin_samples[side]:
  var point:=Vector3.ZERO
  for influence in record:point+=native.posed[influence[0]].basis*influence[1]+native.posed[influence[0]].origin*influence[2]
  # Recompute the lower surface after articulation: the upper toe vertices
  # can become the lowest during plantar flexion. A 3 mm grid retains edges.
  var cell:=Vector2i(floori(point.x*(1.75/64.0)/.003),floori(point.z*(1.75/64.0)/.003))
  if not cells.has(cell) or point.y<cells[cell].y:cells[cell]=point
 for point in cells.values():points.append(point)
 return points
