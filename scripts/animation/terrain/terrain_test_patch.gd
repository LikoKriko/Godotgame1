extends RefCounted
## Plain triangulated test surfaces; visual mesh and static collision share vertices.
const CELL:=.25

static func height_at(x:float,z:float,size:Vector2,forest:bool) -> float:
 var edge:float=minf(size.x*.5-absf(x),size.y*.5-absf(z))
 var blend:=smoothstep(0,3,edge)
 var height:=.16+.045*sin(z*1.7)+.025*sin(z*.7+x*.8)+.018*cos(x*2.2-z*.5)
 if forest:
  height=.55+.12*sin(z*.31)+.07*sin(x*.65+z*.23)+.04*sin(x*3.5+z*.6)*cos(z*1.7-x*.3)
  height+=.22*exp(-(pow(x+2,2)/3+pow(z+5,2)/5))
  height+=.18*exp(-(pow(x-2.5,2)/4+pow(z-4,2)/3))
  height-=.22*exp(-(pow(x-1.2,2)/3+pow(z+1,2)/4))
  height-=.16*exp(-(pow(x+2.8,2)/2+pow(z-7,2)/3))
 return height*blend

static func build(zone_name:String,size:Vector2,forest:bool) -> StaticBody3D:
 var columns:=roundi(size.x/CELL)
 var rows:=roundi(size.y/CELL)
 var vertices:=PackedVector3Array()
 var normals:=PackedVector3Array()
 var indices:=PackedInt32Array()
 for row in rows+1:
  for column in columns+1:
   var x:float=column*CELL-size.x*.5
   var z:float=row*CELL-size.y*.5
   var dx:float=(height_at(x+.01,z,size,forest)-height_at(x-.01,z,size,forest))/.02
   var dz:float=(height_at(x,z+.01,size,forest)-height_at(x,z-.01,size,forest))/.02
   vertices.append(Vector3(x,height_at(x,z,size,forest),z))
   normals.append(Vector3(-dx,1,-dz).normalized())
 for row in rows:
  for column in columns:
   var a:int=row*(columns+1)+column
   var b:=a+1
   var c:=a+columns+1
   var d:=c+1
   # The existing plane fills zero-height corner triangles; omit duplicates
   # to avoid coplanar flicker without opening a collision gap.
   if vertices[a].y>0 or vertices[b].y>0 or vertices[c].y>0:
    indices.append_array(PackedInt32Array([a,b,c]))
   if vertices[b].y>0 or vertices[d].y>0 or vertices[c].y>0:
    indices.append_array(PackedInt32Array([b,d,c]))
 var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var material:=StandardMaterial3D.new();material.albedo_color=Color(.48,.5,.52)
 var visual:=MeshInstance3D.new();visual.mesh=mesh;visual.material_override=material
 var collision:=CollisionShape3D.new();collision.shape=mesh.create_trimesh_shape()
 var solid:=StaticBody3D.new();solid.name=zone_name;solid.add_child(visual);solid.add_child(collision)
 # Store the exact collision triangles, not the smooth generating function.
 # Static, axis-aligned patches can answer vertical sole samples without
 # repeating a physics-server ray for every skinned vertex.
 var planes:Array[Plane]=[]
 var present:=PackedByteArray()
 for row in rows:
  for column in columns:
   var a:int=row*(columns+1)+column
   var b:=a+1;var c:=a+columns+1;var d:=c+1
   planes.append(Plane(vertices[a],vertices[b],vertices[c]))
   planes.append(Plane(vertices[b],vertices[d],vertices[c]))
   present.append(1 if vertices[a].y>0 or vertices[b].y>0 or vertices[c].y>0 else 0)
   present.append(1 if vertices[b].y>0 or vertices[d].y>0 or vertices[c].y>0 else 0)
 solid.set_meta(&"sole_height_grid",{"size":size,"columns":columns,"rows":rows,"planes":planes,"present":present})
 return solid

static func sample_grid(grid:Dictionary,point:Vector3) -> Vector4:
 var x:float=(point.x+grid.size.x*.5)/CELL
 var z:float=(point.z+grid.size.y*.5)/CELL
 var column:=floori(x);var row:=floori(z)
 if column<0 or row<0 or column>=grid.columns or row>=grid.rows:return Vector4.ZERO
 var index:int=(row*grid.columns+column)*2+(1 if x-column+z-row>1 else 0)
 if grid.present[index]==0:return Vector4.ZERO
 var plane:Plane=grid.planes[index]
 var normal:=plane.normal
 return Vector4(normal.x,normal.y,normal.z,(plane.d-normal.x*point.x-normal.z*point.z)/normal.y)
