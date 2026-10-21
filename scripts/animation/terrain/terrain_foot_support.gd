extends RefCounted
const Patch=preload("res://scripts/animation/terrain/terrain_test_patch.gd")
## Cache the native skinned sole envelope in ankle space, independent of scale.
var soles:Array[Array]=[]
var skin_samples:Array[Array]=[]
var bone_bounds:Array[Dictionary]=[{},{}]
var skin_query:=PhysicsShapeQueryParameters3D.new()
var skin_box:=BoxShape3D.new()
var plane_valid:=false
var skin_plane:=Plane()
var accept_surface:=Callable()
var grid_valid:=false
var height_grid:Dictionary={}
var grid_origin:=Vector3.ZERO
var packed_points:Array[PackedVector3Array]=[]
var packed_bones:Array[PackedInt32Array]=[]
var packed_weights:Array[PackedFloat32Array]=[]
var packed_offsets:Array[PackedInt32Array]=[]
var boxes_valid:=false
var box_frames:Array[Transform3D]=[]
var box_inverses:Array[Transform3D]=[]
var box_bounds:Array[AABB]=[]
func configure(native:RefCounted,exclude:Array[RID]=[],accept:Callable=Callable()) -> void:
 accept_surface=accept
 soles=[[],[]];skin_samples=[[],[]];bone_bounds=[{},{}]
 packed_points=[PackedVector3Array(),PackedVector3Array()]
 packed_bones=[PackedInt32Array(),PackedInt32Array()]
 packed_weights=[PackedFloat32Array(),PackedFloat32Array()]
 packed_offsets=[PackedInt32Array(),PackedInt32Array()]
 skin_query.shape=skin_box;skin_query.collision_mask=1
 skin_query.exclude=exclude;skin_query.margin=.0002
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
  for record in skin_samples[side]:
   packed_offsets[side].append(packed_points[side].size())
   for influence in record:
    packed_bones[side].append(influence[0]);packed_points[side].append(influence[1]);packed_weights[side].append(influence[2])
  packed_offsets[side].append(packed_points[side].size())
  # Each skin vertex is a convex combination of these bone-space points.
  # Their transformed union therefore bounds the entire sampled foot, even
  # when toes rotate or shin weights move its lowest surface during running.
  for record in skin_samples[side]:
   for influence in record:
    var bone:int=influence[0]
    var point:Vector3=influence[1]/influence[2]
    var bounds:AABB=bone_bounds[side].get(bone,AABB(point,Vector3.ZERO))
    bone_bounds[side][bone]=bounds.expand(point)
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

func pose_bounds(native:RefCounted,side:int,frame:Transform3D) -> AABB:
 var bounds:=AABB()
 var first:=true
 for bone in bone_bounds[side]:
  var transformed:AABB=(frame*native.posed[bone])*bone_bounds[side][bone]
  bounds=transformed if first else bounds.merge(transformed)
  first=false
 return bounds

func may_penetrate(native:RefCounted,side:int,frame:Transform3D,space:PhysicsDirectSpaceState3D) -> bool:
 plane_valid=false
 grid_valid=false
 boxes_valid=false
 if bone_bounds[side].is_empty():return true
 var bounds:=pose_bounds(native,side,frame)
 # Match the detail rays' upward reach: a foot already below a surface must
 # still find it. Below the 3 mm skin margin, ground cannot require a lift.
 var foot_bounds:=bounds
 bounds=bounds.grow(.0032)
 bounds.size.y+=.65
 skin_box.size=bounds.size
 skin_query.transform=Transform3D(Basis.IDENTITY,bounds.get_center())
 var hits:=space.intersect_shape(skin_query,2)
 if hits.is_empty():return false
 if hits.size()==2:hits=space.intersect_shape(skin_query,16)
 if hits.size()==1:
  cache_plane(hits[0],foot_bounds)
  var collider:CollisionObject3D=hits[0].collider as CollisionObject3D
  if collider!=null and collider.has_meta(&"sole_height_grid") and collider.global_basis.is_equal_approx(Basis.IDENTITY):
   # The broad-phase query still checks for overlapping obstacles. Restrict
   # this path to the immutable grid face that contains the whole foot.
   var candidate:Dictionary=collider.get_meta(&"sole_height_grid")
   var low:=foot_bounds.position-collider.global_position
   var high:=foot_bounds.end-collider.global_position
   if low.x> -candidate.size.x*.5+.001 and high.x<candidate.size.x*.5-.001 and low.z> -candidate.size.y*.5+.001 and high.z<candidate.size.y*.5-.001:
    height_grid=candidate;grid_origin=collider.global_position;grid_valid=true
 if not plane_valid and not grid_valid and hits.size()<16:cache_boxes(hits)
 return true

func cache_boxes(hits:Array[Dictionary]) -> void:
 box_frames.clear();box_inverses.clear();box_bounds.clear()
 for hit in hits:
  var collider:CollisionObject3D=hit.collider as CollisionObject3D
  if collider==null:return
  var owner:=collider.shape_find_owner(hit.shape)
  var shape:Shape3D
  for index in collider.shape_owner_get_shape_count(owner):
   if collider.shape_owner_get_shape_index(owner,index)==hit.shape:shape=collider.shape_owner_get_shape(owner,index);break
  if not shape is BoxShape3D:return
  var transform:Transform3D=collider.global_transform*collider.shape_owner_get_transform(owner)
  box_frames.append(transform);box_inverses.append(transform.affine_inverse());box_bounds.append(AABB(-shape.size*.5,shape.size))
 boxes_valid=not box_frames.is_empty()

func world_skin_points(native:RefCounted,side:int,frame:Transform3D) -> PackedVector3Array:
 var poses:Array[Transform3D]=native.posed
 var points:PackedVector3Array=packed_points[side]
 var bones:PackedInt32Array=packed_bones[side]
 var weights:PackedFloat32Array=packed_weights[side]
 var offsets:PackedInt32Array=packed_offsets[side]
 var result:=PackedVector3Array();result.resize(offsets.size()-1)
 for vertex in result.size():
  var point:=Vector3.ZERO
  for index in range(offsets[vertex],offsets[vertex+1]):
   var pose:Transform3D=poses[bones[index]]
   point+=pose.basis*points[index]+pose.origin*weights[index]
  # Skin weights from the approved mesh are quantized, not exactly unit-sum.
  # Blend in model space, then apply the actor transform once, as the mesh
  # and detailed probes do. Distributing frame.origin over the influences
  # moves vertices across step edges when the actor translates or rotates.
  result[vertex]=frame*point
 return result

func boxes_lift(native:RefCounted,side:int,frame:Transform3D) -> float:
 var lift:=0.0
 for point in world_skin_points(native,side,frame):
  var height:=-INF
  var normal:=Vector3.ZERO
  for box in box_frames.size():
   var inverse:Transform3D=box_inverses[box]
   var start:Vector3=inverse*(point+Vector3.UP*.65)
   var end:Vector3=inverse*(point-Vector3.UP*.85)
   var bounds:AABB=box_bounds[box]
   if bounds.has_point(start):continue # Same hit_from_inside=false ray policy.
   var hit=bounds.intersects_segment(start,end)
   if not hit is Vector3:continue
   var world:Vector3=box_frames[box]*hit
   if world.y<=height:continue
   var half:=bounds.size*.5
   var distance:Vector3=(hit.abs()-half).abs()
   var local_normal:=Vector3.ZERO
   if distance.x<=distance.y and distance.x<=distance.z:local_normal.x=signf(hit.x)
   elif distance.y<=distance.z:local_normal.y=signf(hit.y)
   else:local_normal.z=signf(hit.z)
   height=world.y;normal=(inverse.basis.transposed()*local_normal).normalized()
  if height+.003<=point.y:continue
  if accept_surface.is_valid() and not accept_surface.call(Vector3(point.x,height,point.z),normal):continue
  lift=maxf(lift,height+.003-point.y)
 return lift

func edge_minima(native:RefCounted,side:int,frame:Transform3D,normal:Vector3,origin:Vector3) -> Vector2:
 var gap:=INF;var low:=INF
 for point in world_skin_points(native,side,frame):
  gap=minf(gap,normal.dot(point-origin));low=minf(low,point.y)
 return Vector2(gap,low)

func grid_lift(native:RefCounted,side:int,frame:Transform3D) -> float:
 var lift:=0.0
 for point in world_skin_points(native,side,frame):
  var sample:=Patch.sample_grid(height_grid,point-grid_origin)
  # Missing triangles retain the existing detailed collision path.
  if sample.y<=0:return -1.0
  var height:=sample.w+grid_origin.y
  if height-point.y>.65:continue
  if height+.003<=point.y:continue
  var normal:=Vector3(sample.x,sample.y,sample.z)
  if accept_surface.is_valid() and not accept_surface.call(Vector3(point.x,height,point.z),normal):continue
  lift=maxf(lift,height+.003-point.y)
 return lift

func cache_plane(hit:Dictionary,bounds:AABB) -> void:
 var collider:CollisionObject3D=hit.collider as CollisionObject3D
 if collider==null:return
 var owner:=collider.shape_find_owner(hit.shape)
 var shape:Shape3D
 for index in collider.shape_owner_get_shape_count(owner):
  if collider.shape_owner_get_shape_index(owner,index)==hit.shape:shape=collider.shape_owner_get_shape(owner,index);break
 if not shape is BoxShape3D:return
 var transform:Transform3D=collider.global_transform*collider.shape_owner_get_transform(owner)
 var inverse:=transform.affine_inverse()
 var normal:Vector3=(inverse.basis.transposed()*Vector3.UP).normalized()
 if normal.y<cos(deg_to_rad(42)):return
 var half:Vector3=shape.size*.5
 var plane:=Plane(normal,transform*(Vector3.UP*half.y))
 # Only use the top plane when every possible vertical sample lies within
 # this face and can reach it. Edges, multiple surfaces and meshes retain rays.
 for corner in 8:
  var p:Vector3=bounds.position+Vector3(corner&1,(corner>>1)&1,(corner>>2)&1)*bounds.size
  var y:float=(plane.d-normal.x*p.x-normal.z*p.z)/normal.y
  if y-p.y>.65:return
  if accept_surface.is_valid() and not accept_surface.call(Vector3(p.x,y,p.z),normal):return
  var local:Vector3=inverse*Vector3(p.x,y,p.z)
  if absf(local.x)>half.x-.0002 or absf(local.z)>half.z-.0002:return
 skin_plane=plane;plane_valid=true

func plane_lift(native:RefCounted,side:int,frame:Transform3D) -> float:
 if skin_plane.normal==Vector3.UP and frame.basis.x.y==0 and frame.basis.z.y==0 and frame.basis.y.y>0:
  # On a horizontal face, the grid's minimum is exactly the minimum of all
  # vertices. Project skinning to Y directly: no XZ grid or per-vertex rays.
  var rows:Dictionary={};var heights:Dictionary={}
  for bone in bone_bounds[side]:
   var posed:Transform3D=native.posed[bone]
   rows[bone]=Vector3(posed.basis.x.y,posed.basis.y.y,posed.basis.z.y)*frame.basis.y.y
   heights[bone]=posed.origin.y*frame.basis.y.y
  var low:=INF
  for record in skin_samples[side]:
   var y:=frame.origin.y
   for influence in record:y+=rows[influence[0]].dot(influence[1])+heights[influence[0]]*influence[2]
   low=minf(low,y)
  return maxf(0,skin_plane.d+.003-low)
 var lift:=0.0
 for p in world_skin_points(native,side,frame):
  var height:float=(skin_plane.d-skin_plane.normal.x*p.x-skin_plane.normal.z*p.z)/skin_plane.normal.y
  lift=maxf(lift,height+.003-p.y)
 return lift

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
