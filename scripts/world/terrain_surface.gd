extends RefCounted
## Pure height-field meshing: metre coordinates, shared seams and collision topology.
static func normal_at(point:Vector2,height:Callable) -> Vector3:
 return Vector3(height.call(point-Vector2(.1,0))-height.call(point+Vector2(.1,0)),.2,height.call(point-Vector2(0,.1))-height.call(point+Vector2(0,.1))).normalized()
static func build_mesh(area:Rect2,height:Callable,grid:float=.5) -> ArrayMesh:
 if not area.position.is_finite() or not area.size.is_finite() or not area.has_area() or not is_finite(grid) or grid<=0 or not height.is_valid():return null
 var nx:=ceili(area.size.x/grid);var nz:=ceili(area.size.y/grid)
 # Chunk-sized calls prevent accidental allocation of a complete world mesh.
 if nx>2048 or nz>2048 or (nx+1)*(nz+1)>1000000:return null
 var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var indices:=PackedInt32Array()
 var center:=area.get_center()
 for z in nz+1:
  for x in nx+1:
   var point:=area.position+Vector2(float(x)/nx,float(z)/nz)*area.size
   var altitude:float=height.call(point)
   if not is_finite(altitude):return null
   var normal:=normal_at(point,height)
   if not normal.is_finite():return null
   vertices.append(Vector3(point.x-center.x,altitude,point.y-center.y));normals.append(normal)
 for z in nz:
  for x in nx:
   var i:=z*(nx+1)+x
   indices.append_array(PackedInt32Array([i,i+1,i+nx+1,i+1,i+nx+2,i+nx+1]))
 var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices
 var result:=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return result
