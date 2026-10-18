extends SceneTree
## Local, conforming support loops for the axillary fold. The supplied FBX,
## source skin and texture maps stay intact; this is a derived runtime surface.
const SOURCE="res://assets/characters/prototype_3d/meshy/survivor_skin.res"
const OUTPUT="res://assets/characters/prototype_3d/meshy/survivor_axilla.res"
var arrays:Array
var indices:PackedInt32Array
var patch:Dictionary={}
func _initialize():
 var source:Mesh=load(SOURCE);arrays=source.surface_get_arrays(0).duplicate(true)
 var old_count:int=arrays[Mesh.ARRAY_VERTEX].size()
 var old_faces:int=arrays[Mesh.ARRAY_INDEX].size()/3
 # Subdivide actual connecting faces, rather than overlaying another skin sheet.
 # Only the fold between ribs and proximal humerus receives extra support loops.
 for pass_index in 1:refine()
 smooth_weights()
 var mesh:=ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},source.surface_get_format(0))
 mesh.surface_set_material(0,source.surface_get_material(0))
 for key in source.get_meta_list():mesh.set_meta(key,source.get_meta(key))
 mesh.set_meta("source_skin_sha256",FileAccess.get_sha256(SOURCE))
 mesh.set_meta("axilla_profile",&"support_fold_v1")
 mesh.set_meta("source_vertices",old_count);mesh.set_meta("source_triangles",old_faces)
 mesh.set_meta("axilla_vertices",patch.keys())
 assert(ResourceSaver.save(mesh,OUTPUT,ResourceSaver.FLAG_COMPRESS)==OK)
 print("Axillary support loops: ",arrays[Mesh.ARRAY_VERTEX].size()-old_count," added vertices; ",arrays[Mesh.ARRAY_INDEX].size()/3-old_faces," added triangles; ",patch.size()," local skin vertices")
 quit()
func mask(p:Vector3) -> float:
 if p.y<40.5 or p.y>47.3 or absf(p.x)<3.8 or absf(p.x)>7.6 or p.z<-.8 or p.z>5.5:return 0.0
 var border:float=smoothstep(40.5,42,p.y)*(1-smoothstep(46,47.3,p.y))*smoothstep(3.8,4.6,absf(p.x))*(1-smoothstep(6.9,7.6,absf(p.x)))
 return border
func edge_key(a:int,b:int) -> Vector2i:return Vector2i(mini(a,b),maxi(a,b))
func refine():
 var v:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];indices=arrays[Mesh.ARRAY_INDEX]
 var marked:Dictionary={}
 for i in range(0,indices.size(),3):
  var ids:Array[int]=[indices[i],indices[i+1],indices[i+2]]
  var center:Vector3=(v[ids[0]]+v[ids[1]]+v[ids[2]])/3
  if mask(center)<.04:continue
  for edge in 3:
   var a:int=ids[edge];var b:int=ids[(edge+1)%3]
   if v[a].distance_to(v[b])>.80:marked[edge_key(a,b)]=-1
 var result:=PackedInt32Array()
 for i in range(0,indices.size(),3):
  var triangle:Array[int]=[indices[i],indices[i+1],indices[i+2]];var polygon:Array[int]=[];var divided:=false
  for edge in 3:
   var a:int=triangle[edge];var b:int=triangle[(edge+1)%3];polygon.append(a)
   var key:=edge_key(a,b)
   if marked.has(key):
    if marked[key]<0:marked[key]=vertex([a,b],[.5,.5])
    polygon.append(marked[key]);divided=true
  if not divided:result.append_array(PackedInt32Array(triangle));continue
  var center:=vertex(triangle,[1.0/3,1.0/3,1.0/3])
  for edge in polygon.size():result.append_array(PackedInt32Array([polygon[edge],polygon[(edge+1)%polygon.size()],center]))
 arrays[Mesh.ARRAY_INDEX]=result
func vertex(ids:Array,parts:Array) -> int:
 var index:int=arrays[Mesh.ARRAY_VERTEX].size()
 for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2,Mesh.ARRAY_COLOR]:
  if arrays[channel]==null:continue
  var value=arrays[channel][ids[0]]*0
  for i in ids.size():value+=arrays[channel][ids[i]]*parts[i]
  if channel==Mesh.ARRAY_NORMAL:value=value.normalized()
  arrays[channel].append(value)
 if arrays[Mesh.ARRAY_TANGENT]!=null:
  var direction:=Vector3.ZERO
  for i in ids.size():direction+=Vector3(arrays[Mesh.ARRAY_TANGENT][ids[i]*4],arrays[Mesh.ARRAY_TANGENT][ids[i]*4+1],arrays[Mesh.ARRAY_TANGENT][ids[i]*4+2])*parts[i]
  direction=direction.normalized()
  for value in [direction.x,direction.y,direction.z,arrays[Mesh.ARRAY_TANGENT][ids[0]*4+3]]:arrays[Mesh.ARRAY_TANGENT].append(value)
 var influence:Dictionary={}
 for i in ids.size():
  for slot in 4:
   var bone:int=arrays[Mesh.ARRAY_BONES][ids[i]*4+slot]
   influence[bone]=float(influence.get(bone,0))+arrays[Mesh.ARRAY_WEIGHTS][ids[i]*4+slot]*parts[i]
 var order:=influence.keys();order.sort_custom(func(a,b):return influence[a]>influence[b])
 var sum:=0.0
 for slot in mini(4,order.size()):sum+=influence[order[slot]]
 for slot in 4:
  arrays[Mesh.ARRAY_BONES].append(order[slot] if slot<order.size() else 0)
  arrays[Mesh.ARRAY_WEIGHTS].append(influence[order[slot]]/sum if slot<order.size() else 0.0)
 patch[index]=true
 return index
func smooth_weights():
 var v:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var ids:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 var neighbours:Dictionary={};var share:=PackedFloat32Array();share.resize(v.size())
 for i in v.size():
  var start:=4 if v[i].x<0 else 7
  for slot in 4:
   if arrays[Mesh.ARRAY_BONES][i*4+slot] in [start,start+1,start+2,20 if start==4 else 21]:share[i]+=arrays[Mesh.ARRAY_WEIGHTS][i*4+slot]
  if mask(v[i])>.001:patch[i]=true
 for i in range(0,ids.size(),3):
  for edge in 3:
   var a:int=ids[i+edge];var b:int=ids[i+(edge+1)%3]
   if not neighbours.has(a):neighbours[a]=[]
   if not neighbours.has(b):neighbours[b]=[]
   neighbours[a].append(b);neighbours[b].append(a)
 for iteration in 4:
  var next:=share.duplicate()
  for i in patch:
   if not neighbours.has(i) or share[i]>.96 or share[i]<.025:continue
   var amount:=mask(v[i])*.60
   var average:=0.0;var count:=0.0
   for j in neighbours[i]:
    var weight:float=1/maxf(.15,v[i].distance_to(v[j]));average+=share[j]*weight;count+=weight
   next[i]=lerpf(share[i],average/count,amount)
  share=next
 for i in patch:
  if mask(v[i])<.001:continue
  var back_width:=4.65 if v[i].y<43 else (4.4 if v[i].y<47 else 3.8)
  if v[i].z<.6 and absf(v[i].x)<back_width:share[i]=0.0
  var start:=4 if v[i].x<0 else 7
  var original:=0.0
  for slot in 4:
   if arrays[Mesh.ARRAY_BONES][i*4+slot] in [start,start+1,start+2,20 if start==4 else 21]:original+=arrays[Mesh.ARRAY_WEIGHTS][i*4+slot]
  if absf(share[i]-original)<.00001:continue
  # The proximal fold blends ribs and humerus; no distal joint may pull it.
  arrays[Mesh.ARRAY_BONES][i*4]=1;arrays[Mesh.ARRAY_WEIGHTS][i*4]=1-share[i]
  arrays[Mesh.ARRAY_BONES][i*4+1]=start;arrays[Mesh.ARRAY_WEIGHTS][i*4+1]=share[i]
  for slot in [2,3]:arrays[Mesh.ARRAY_BONES][i*4+slot]=0;arrays[Mesh.ARRAY_WEIGHTS][i*4+slot]=0
