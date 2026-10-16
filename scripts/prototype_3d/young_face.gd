extends RefCounted
## A cut lip seam and a recessed, skinned lining; all source assets stay intact.
const SECONDS:=2.0
const CONTROL_SCALE:=5.0
const JAW_ANGLE:=.11
const LIP_Y:=14.8
const THROAT_Z:=14.5
const PIVOT:=Vector3(0,14.0,11.0)
const CONTROLS:Array[StringName]=[&"jaw_left",&"jaw_right",&"cheek_left",&"cheek_right",&"nose_lift"]
static var cached:ArrayMesh
static var source_count:=0
static var seam_segments:Array=[]
static func amount(_state:StringName,phase:float) -> float:
 return smoothstep(0,.34,phase)*(1-smoothstep(.55,1,phase))
static func weights(seconds:float) -> PackedFloat32Array:
 var t:=clampf(seconds/SECONDS,0,1)
 var opening:=amount(&"attack",t)
 var cheeks:=smoothstep(0,.27,t)*(1-smoothstep(.60,1,t))
 var nose:=smoothstep(.08,.40,t)*(1-smoothstep(.58,1,t))
 return PackedFloat32Array([opening/CONTROL_SCALE,opening/CONTROL_SCALE,cheeks/CONTROL_SCALE,cheeks/CONTROL_SCALE,nose/CONTROL_SCALE])
static func side_weight(point:Vector3,left:bool) -> float:
 var right:=smoothstep(-1,1,point.x)
 return 1-right if left else right
static func jaw(point:Vector3,role:int=0) -> float:
 # The upper fangs stay fixed to the maxilla. The two upturned lower
 # fangs and their surrounding tissue share one continuous mask.
 var front:=smoothstep(12.0,15.2,point.z)
 var lane:=1-smoothstep(2.9,4.3,absf(point.x))
 var lower:=1.0 if point.y<LIP_Y or role<0 else 0.0
 if role>0:lower=0.0
 var center:=front*lane*lower*smoothstep(9.5,12.0,point.y)
 var lateral:=smoothstep(3.2,4.8,absf(point.x))*(1-smoothstep(8.6,13,absf(point.x)))*smoothstep(13,14,point.y)*(1-smoothstep(15.3,20.2,point.y))*smoothstep(9,16,point.z)
 # The two long maxillary tusks sit below the snout, not on the fists.
 # Keep their entire volume rigid and spread the transition into nearby skin.
 var upper_tusks:=smoothstep(15,16,point.z)*(1-smoothstep(17.9,19.5,point.z))*(1-smoothstep(14.7,15.8,point.y))*(1-smoothstep(3.1,4.8,absf(point.x)))
 return maxf(center,lateral)*(1-upper_tusks)
static func offset(point:Vector3,control:int,role:int=0) -> Vector3:
 if role==2:return Vector3.ZERO
 if control<2:
  var turn:=Basis(Vector3.RIGHT,JAW_ANGLE)*(point-PIVOT)+PIVOT-point
  return turn*jaw(point,role)*side_weight(point,control==0)
 if control<4:
  var lane:=smoothstep(2.5,4.2,absf(point.x))*(1-smoothstep(6.5,8.0,absf(point.x)))
  var mask:=lane*smoothstep(18.3,19.3,point.y)*(1-smoothstep(21,22,point.y))*smoothstep(12,15,point.z)
  return Vector3(signf(point.x)*.04,.045,-.015)*mask*side_weight(point,control==2)
 var nose:float=(1-smoothstep(1.6,2.6,absf(point.x)))*smoothstep(15,19,point.z)*smoothstep(15,16.2,point.y)*(1-smoothstep(19,21,point.y))
 return Vector3(0,.10,-.02)*nose
static func append_edge(arrays:Array,a:int,b:int,t:float,roles:PackedInt32Array,role:int) -> int:
 var index:int=arrays[Mesh.ARRAY_VERTEX].size()
 for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV]:arrays[channel].append(arrays[channel][a].lerp(arrays[channel][b],t))
 arrays[Mesh.ARRAY_NORMAL][index]=arrays[Mesh.ARRAY_NORMAL][index].normalized()
 var tangent:=Vector3(arrays[Mesh.ARRAY_TANGENT][4*a],arrays[Mesh.ARRAY_TANGENT][4*a+1],arrays[Mesh.ARRAY_TANGENT][4*a+2]).lerp(Vector3(arrays[Mesh.ARRAY_TANGENT][4*b],arrays[Mesh.ARRAY_TANGENT][4*b+1],arrays[Mesh.ARRAY_TANGENT][4*b+2]),t).normalized()
 for value in [tangent.x,tangent.y,tangent.z,arrays[Mesh.ARRAY_TANGENT][4*a+3]]:arrays[Mesh.ARRAY_TANGENT].append(value)
 var influence:Dictionary={}
 for pair in [[a,1-t],[b,t]]:
  for slot in 4:
   var id:int=arrays[Mesh.ARRAY_BONES][4*pair[0]+slot]
   influence[id]=float(influence.get(id,0))+arrays[Mesh.ARRAY_WEIGHTS][4*pair[0]+slot]*pair[1]
 var order:=influence.keys();order.sort_custom(func(x,y):return influence[x]>influence[y])
 var sum:=0.0
 for slot in mini(4,order.size()):sum+=influence[order[slot]]
 for slot in 4:
  arrays[Mesh.ARRAY_BONES].append(order[slot] if slot<order.size() else 0)
  arrays[Mesh.ARRAY_WEIGHTS].append(influence[order[slot]]/sum if slot<order.size() else 0.0)
 roles.append(role)
 return index
static func cut(arrays:Array,roles:PackedInt32Array) -> void:
 var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX];var result:=PackedInt32Array()
 for start in range(0,indices.size(),3):
  var triangle:Array[int]=[indices[start],indices[start+1],indices[start+2]];var crossing:Array=[]
  for edge in 3:
   var a:int=triangle[edge];var b:int=triangle[(edge+1)%3]
   var pa:Vector3=arrays[Mesh.ARRAY_VERTEX][a];var pb:Vector3=arrays[Mesh.ARRAY_VERTEX][b]
   if (pa.y<LIP_Y)!=(pb.y<LIP_Y):
    var t:float=(LIP_Y-pa.y)/(pb.y-pa.y);crossing.append([a,b,t,pa.lerp(pb,t)])
  var facial:=crossing.size()==2
  if facial:
   facial=(crossing[0][3].z>14.8 and crossing[1][3].z>14.8 and minf(absf(crossing[0][3].x),absf(crossing[1][3].x))<4.8)
  if not facial:result.append_array(PackedInt32Array(triangle));continue
  var rim:Array=[]
  for role in [-1,1]:
   var polygon:Array[int]=[];var seam:Array[int]=[]
   for edge in 3:
    var a:int=triangle[edge];var b:int=triangle[(edge+1)%3]
    var pa:Vector3=arrays[Mesh.ARRAY_VERTEX][a];var pb:Vector3=arrays[Mesh.ARRAY_VERTEX][b]
    if (pa.y-LIP_Y)*role>=0:polygon.append(a)
    if (pa.y<LIP_Y)!=(pb.y<LIP_Y):
     var id:=append_edge(arrays,a,b,(LIP_Y-pa.y)/(pb.y-pa.y),roles,role);polygon.append(id);seam.append(id)
   for i in range(1,polygon.size()-1):result.append_array(PackedInt32Array([polygon[0],polygon[i],polygon[i+1]]))
   rim.append(seam)
  seam_segments.append(rim)
 arrays[Mesh.ARRAY_INDEX]=result
static func blend_shapes(arrays:Array,roles:PackedInt32Array) -> Array:
 var shapes:Array=[]
 for control in 5:
  var shape:Array=[];shape.resize(Mesh.ARRAY_MAX)
  var delta:=PackedVector3Array();delta.resize(arrays[Mesh.ARRAY_VERTEX].size())
  for i in delta.size():delta[i]=arrays[Mesh.ARRAY_VERTEX][i]+offset(arrays[Mesh.ARRAY_VERTEX][i],control,roles[i])*CONTROL_SCALE
  # Godot octahedrally encodes these directions, including relative shapes:
  # a zero vector cannot survive that encoding as a zero normal/tangent.
  # Absolute shapes with normalized blending preserve source shading, even
  # with control weights scaled so their sum never exceeds one.
  shape[Mesh.ARRAY_VERTEX]=delta;shape[Mesh.ARRAY_NORMAL]=arrays[Mesh.ARRAY_NORMAL].duplicate();shape[Mesh.ARRAY_TANGENT]=arrays[Mesh.ARRAY_TANGENT].duplicate();shapes.append(shape)
 return shapes
static func lining(arrays:Array,shapes:Array) -> Array:
 var inner:Array=[];inner.resize(Mesh.ARRAY_MAX)
 inner[Mesh.ARRAY_VERTEX]=PackedVector3Array();inner[Mesh.ARRAY_NORMAL]=PackedVector3Array();inner[Mesh.ARRAY_TANGENT]=PackedFloat32Array();inner[Mesh.ARRAY_TEX_UV]=PackedVector2Array();inner[Mesh.ARRAY_BONES]=PackedInt32Array();inner[Mesh.ARRAY_WEIGHTS]=PackedFloat32Array();inner[Mesh.ARRAY_INDEX]=PackedInt32Array()
 var inner_shapes:Array=[]
 for control in 5:
  var shape:Array=[];shape.resize(Mesh.ARRAY_MAX);shape[Mesh.ARRAY_VERTEX]=PackedVector3Array();shape[Mesh.ARRAY_NORMAL]=PackedVector3Array();shape[Mesh.ARRAY_TANGENT]=PackedFloat32Array();inner_shapes.append(shape)
 for segment in seam_segments:
  var base:int=inner[Mesh.ARRAY_VERTEX].size()
  for row in 5:
   var v:float=[0.0,0.0,.5,1.0,1.0][row]
   for end in 2:
    var low:int=segment[0][end];var high:int=segment[1][end]
    var point:Vector3=arrays[Mesh.ARRAY_VERTEX][low]
    # At rest every row collapses onto the lip: no exposed dark sheet.
    inner[Mesh.ARRAY_VERTEX].append(point)
    var normal:=Vector3.DOWN if row==0 else (Vector3.UP if row==4 else Vector3.BACK)
    inner[Mesh.ARRAY_NORMAL].append(normal);inner[Mesh.ARRAY_TANGENT].append_array(PackedFloat32Array([1,0,0,1]));inner[Mesh.ARRAY_TEX_UV].append(Vector2((point.x+4.8)/9.6,row/4.0))
    for slot in 4:inner[Mesh.ARRAY_BONES].append(arrays[Mesh.ARRAY_BONES][4*low+slot]);inner[Mesh.ARRAY_WEIGHTS].append(arrays[Mesh.ARRAY_WEIGHTS][4*low+slot])
    var gaps:=PackedFloat32Array()
    for control in 2:gaps.append((shapes[control][Mesh.ARRAY_VERTEX][low] as Vector3).distance_to(shapes[control][Mesh.ARRAY_VERTEX][high])/CONTROL_SCALE)
    var total:=gaps[0]+gaps[1]
    # Closed ceiling, back and floor. The tiny depth slope separates
    # overlapping source contours; the open back wall stays behind the teeth.
    var full_depth:=maxf(0,point.z-(THROAT_Z+.01*point.z))
    for control in 5:
     var depth:=full_depth*gaps[control]/maxf(total,.000001) if control<2 else 0.0
     inner_shapes[control][Mesh.ARRAY_VERTEX].append((shapes[control][Mesh.ARRAY_VERTEX][high] as Vector3).lerp(shapes[control][Mesh.ARRAY_VERTEX][low],v)+Vector3.FORWARD*depth*CONTROL_SCALE*(1.0 if row in [1,2,3] else 0.0))
     inner_shapes[control][Mesh.ARRAY_NORMAL].append(normal);inner_shapes[control][Mesh.ARRAY_TANGENT].append_array(PackedFloat32Array([1,0,0,1]))
  for row in 4:
   var i:=base+row*2;inner[Mesh.ARRAY_INDEX].append_array(PackedInt32Array([i,i+1,i+2,i+1,i+3,i+2]))
 # Show the lining toward the opening, never as the outside of a dark flap.
 # Segment traversal follows source triangles, so alternate strips need winding
 # correction. Clockwise normals must face the oral cavity, not its exterior.
 var peak:=PackedVector3Array()
 for i in inner[Mesh.ARRAY_VERTEX].size():
  var point:Vector3=inner[Mesh.ARRAY_VERTEX][i]
  for control in 5:point+=(inner_shapes[control][Mesh.ARRAY_VERTEX][i]-inner[Mesh.ARRAY_VERTEX][i])/CONTROL_SCALE
  peak.append(point)
 for i in range(0,inner[Mesh.ARRAY_INDEX].size(),3):
  var a:int=inner[Mesh.ARRAY_INDEX][i];var b:int=inner[Mesh.ARRAY_INDEX][i+1];var c:int=inner[Mesh.ARRAY_INDEX][i+2]
  var row:=int(i/6)%4
  var inward:=Vector3.DOWN if row==0 else (Vector3.UP if row==3 else Vector3.BACK)
  if (peak[b]-peak[a]).cross(peak[c]-peak[a]).dot(inward)>0:
   inner[Mesh.ARRAY_INDEX][i+1]=c;inner[Mesh.ARRAY_INDEX][i+2]=b
 return [inner,inner_shapes]
static func lining_material() -> StandardMaterial3D:
 var image:=Image.create(16,16,false,Image.FORMAT_RGB8)
 var palette:Array[Color]=[Color("512f2d"),Color("462a28"),Color("3b2423"),Color("302020"),Color("251a1b")]
 for y in 16:
  for x in 16:
   var depth:=mini(y,15-y)
   var tone:=roundi(depth*4.0/7.0)
   image.set_pixel(x,y,palette[tone])
 var material:=StandardMaterial3D.new();material.albedo_texture=ImageTexture.create_from_image(image);material.roughness=1;material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;material.cull_mode=BaseMaterial3D.CULL_BACK
 return material
static func mesh(source:Mesh) -> ArrayMesh:
 if cached!=null:return cached
 var arrays:=source.surface_get_arrays(0).duplicate(true);source_count=arrays[Mesh.ARRAY_VERTEX].size()
 var roles:=PackedInt32Array();roles.resize(source_count)
 # Source skin membership prevents facial masks from reaching the stone fists.
 for i in source_count:
  var head:=0.0
  for slot in 4:
   if arrays[Mesh.ARRAY_BONES][4*i+slot]==1:head+=arrays[Mesh.ARRAY_WEIGHTS][4*i+slot]
  if head<.5:roles[i]=2
 cut(arrays,roles)
 var shapes:=blend_shapes(arrays,roles);var interior:=lining(arrays,shapes)
 cached=ArrayMesh.new();cached.blend_shape_mode=Mesh.BLEND_SHAPE_MODE_NORMALIZED
 for label in CONTROLS:cached.add_blend_shape(label)
 cached.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,shapes,{},source.surface_get_format(0));cached.surface_set_material(0,source.surface_get_material(0))
 cached.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,interior[0],interior[1]);cached.surface_set_material(1,lining_material())
 var surfaces:Array=cached.get("_surfaces")
 # Godot stores uncompressed positions followed by packed normal/tangent data.
 # Keep the original packed prefix instead of quantizing those normals twice.
 var original_bytes:PackedByteArray=source.get("_surfaces")[0].vertex_data
 var packed:PackedByteArray=surfaces[0].vertex_data
 var positions_end:int=arrays[Mesh.ARRAY_VERTEX].size()*12
 surfaces[0].vertex_data=packed.slice(0,positions_end)+original_bytes.slice(source_count*12)+packed.slice(positions_end+source_count*8)
 surfaces[0].aabb=source.get_aabb();surfaces[1].aabb=source.get_aabb()
 var rebuilt:=ArrayMesh.new();rebuilt.blend_shape_mode=Mesh.BLEND_SHAPE_MODE_NORMALIZED
 for label in CONTROLS:rebuilt.add_blend_shape(label)
 rebuilt.set("_surfaces",surfaces);cached=rebuilt;cached.custom_aabb=source.get_aabb()
 for label in source.get_meta_list():cached.set_meta(label,source.get_meta(label))
 return cached
