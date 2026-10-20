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
 return solid
