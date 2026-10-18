extends RefCounted
## Small baked set of actual skin supports. Only evaluated during a death fall;
## no mesh rebuild, full-mesh scan or collision query occurs at runtime.
const PROFILE=preload("res://assets/characters/prototype_3d/motion/ground_supports.res")
var supports:Array[Array]=[]
func configure(mesh:Mesh,rest:Array[Transform3D],profile:Resource=PROFILE,skin:Skin=null) -> void:
 supports.clear()
 if skin!=null:
  var surfaces:Array=[]
  for surface in mesh.get_surface_count():surfaces.append(mesh.surface_get_arrays(surface))
  for record:Vector2i in profile.get_meta("vertices",[]):
   var arrays:Array=surfaces[record.x];var index:int=record.y
   var slots:int=arrays[Mesh.ARRAY_BONES].size()/arrays[Mesh.ARRAY_VERTEX].size()
   var point:Array=[]
   for slot in slots:
    var weight:float=arrays[Mesh.ARRAY_WEIGHTS][index*slots+slot]
    if weight<=0:continue
    var bind:int=arrays[Mesh.ARRAY_BONES][index*slots+slot]
    point.append([skin.get_bind_bone(bind),(skin.get_bind_pose(bind)*arrays[Mesh.ARRAY_VERTEX][index])*weight,weight])
   supports.append(point)
  return
 var arrays:Array=mesh.surface_get_arrays(0)
 for index in profile.get_meta("vertices"):
  if int(index)>=arrays[Mesh.ARRAY_VERTEX].size():continue
  var point:Array=[]
  for slot in 4:
   var weight:float=arrays[Mesh.ARRAY_WEIGHTS][int(index)*4+slot]
   if weight==0:continue
   var bone:int=arrays[Mesh.ARRAY_BONES][int(index)*4+slot]
   point.append([bone,(rest[bone].affine_inverse()*arrays[Mesh.ARRAY_VERTEX][int(index)])*weight,weight])
  supports.append(point)
func correction(pose:Array[Transform3D]) -> float:
 var low:=INF
 for support in supports:
  var point:=Vector3.ZERO
  for influence in support:point+=pose[influence[0]].basis*influence[1]+pose[influence[0]].origin*influence[2]
  low=minf(low,point.y)
 return maxf(0,.025-low)
