extends RefCounted
## Prebaked radial oak. Generation records retain their canonical height slots.
const HEIGHTS=[2.65,2.79,3.20,3.28,2.57,1.8375,2.62,2.74,3.24]
const SOURCE:Mesh=preload("res://assets/models/meshy/twisted_oak/model.res")
const CONTROLS:JSON=preload("res://assets/models/meshy/twisted_oak/branches.json")
static var shape_cache:Dictionary={}
static func height_for(design:int) -> float:return HEIGHTS[posmod(design,HEIGHTS.size())]
static func orientation(variation:int) -> Basis:return Basis(Vector3.UP,posmod(variation,4)*PI*.5)
static func point(p:Array) -> Vector3:return Vector3(p[0],p[1],p[2])
static func branch_point(p:Array) -> Vector3:return Vector3(p[0],p[2],-p[1])
static func capsule(a:Vector3,b:Vector3,radius:float) -> Dictionary:
 var shape:=CapsuleShape3D.new();shape.radius=radius;shape.height=maxf(radius*2,a.distance_to(b)+radius*2)
 return {"shape":shape,"transform":Transform3D(Basis(Quaternion(Vector3.UP,a.direction_to(b))),(a+b)*.5)}
static func colliders(design:int) -> Dictionary:
 var key:=posmod(design,HEIGHTS.size())
 if shape_cache.has(key):return shape_cache[key]
 var height:=height_for(design);var result:Dictionary={"physical":[],"aim":[],"camera":[]}
 var spine:Array=CONTROLS.data.collision_spine
 # Roots remain walkable. Capsules follow the actual delivered lean and leader.
 for i in range(2,spine.size()-1,2):
  var a:=point(spine[i].point)*height;var b:=point(spine[mini(i+2,spine.size()-1)].point)*height
  var radius:float=maxf(spine[i].radius,spine[mini(i+2,spine.size()-1)].radius)*height
  result.physical.append(capsule(a,b,radius));result.aim.append(capsule(a,b,radius+.15))
 # Leafless branches do not create the old invisible, solid crown spheres.
 # Only the fifteen principal boughs block the camera; one static body owns them.
 for branch:Dictionary in CONTROLS.data.branches:
  if int(branch.level)!=1:continue
  var points:Array=branch.points;var first:=2;var last:=points.size()-1
  var a:=branch_point(points[first])*height;var b:=branch_point(points[last])*height
  var radius:float=branch.radii[first]*height
  for i in range(first+1,last):
   var p:=branch_point(points[i])*height;var d:=b-a
   var projection:=a+d*clampf((p-a).dot(d)/d.length_squared(),0,1)
   radius=maxf(radius,p.distance_to(projection)+float(branch.radii[i])*height)
  result.camera.append(capsule(a,b,radius))
 shape_cache[key]=result;return result
func build(design:int,variation:int) -> ArrayMesh:
 # Review/quality-authoring helper. Runtime instances share SOURCE directly.
 var mesh:=ArrayMesh.new();var rotation:=orientation(variation);var height:=height_for(design)
 for surface in SOURCE.get_surface_count():
  var arrays:=SOURCE.surface_get_arrays(surface)
  var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
  var tangents:PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
  for i in points.size():
   points[i]=rotation*points[i]*height;normals[i]=rotation*normals[i]
   var tangent:=rotation*Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])
   tangents[i*4]=tangent.x;tangents[i*4+1]=tangent.y;tangents[i*4+2]=tangent.z
  arrays[Mesh.ARRAY_VERTEX]=points;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TANGENT]=tangents
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  mesh.surface_set_material(surface,SOURCE.surface_get_material(surface))
 return mesh
