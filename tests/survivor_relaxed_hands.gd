extends SceneTree
## Verify the rendered native finger skin, not only the curl parameters.
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:
  failures+=1
  if failures<15:push_error(message)
func _initialize():call_deferred('run')
func triangles_cross(a:Array,b:Array) -> bool:
 for edge in 3:
  if Geometry3D.segment_intersects_triangle(a[edge],a[(edge+1)%3],b[0],b[1],b[2])!=null:return true
  if Geometry3D.segment_intersects_triangle(b[edge],b[(edge+1)%3],a[0],a[1],a[2])!=null:return true
 return false
func run():
 var actor=load('res://scripts/prototype_3d/survivor_model.gd').new();root.add_child(actor)
 var n=actor.native
 actor.family_override=&'';actor.animate(&'idle',0,false)
 var reference:Array=[]
 for side in 2:
  var shapes:Array=[]
  for chain in n.grip.fingers[side]:
   for bone in chain:shapes.append(n.posed[n.arms[side].ids[3]].affine_inverse()*n.posed[bone])
  reference.append(shapes)
 for state in [&'idle',&'walk',&'run',&'crouch',&'crouch_walk']:
  for direction in [Vector3.BACK,Vector3.FORWARD,Vector3.LEFT,Vector3.RIGHT,Vector3(-.574,0,.819),Vector3(.574,0,.819),Vector3(-.574,0,-.819),Vector3(.574,0,-.819)]:
   for phase in [0.,.25,.5,.75,1.]:
    actor.animate(state,phase,false,0,phase,direction if state!=&'idle' else Vector3.ZERO)
    for side in 2:
     var index:=0
     for chain in n.grip.fingers[side]:
      for bone in chain:
       var actual:Transform3D=n.posed[n.arms[side].ids[3]].affine_inverse()*n.posed[bone]
       require(actual.origin.distance_to(reference[side][index].origin)<.0001,'Relaxed fingers follow their palm in every locomotion direction')
       require(actual.basis.orthonormalized().get_rotation_quaternion().angle_to(reference[side][index].basis.orthonormalized().get_rotation_quaternion())<.002,'Finger curvature stays stable through the gait cycle')
       var parent:int=n.parents[bone]
       require(absf(n.posed[bone].origin.distance_to(n.posed[parent].origin)-n.rest[bone].origin.distance_to(n.rest[parent].origin)*(n.grip.HAND_SCALE if n.grip.relaxed.has(bone) else 1.0))<.0001,'Relaxed posing cannot stretch native fingers')
       index+=1
 # Classify actual skin triangles by native bind weights. Distal finger skin
 # must not intersect the palm or another finger. Exclude shared webbing.
 actor.animate(&'idle',0,false)
 var arrays:Array=n.mesh.mesh.surface_get_arrays(0)
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
 var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 var skin:Skin=n.mesh.skin
 var slots:int=bones.size()/vertices.size()
 var matrices:Array[Transform3D]=[]
 for bind in skin.get_bind_count():matrices.append(n.posed[skin.get_bind_bone(bind)]*skin.get_bind_pose(bind))
 var groups:Dictionary={}
 for side in 2:
  groups[n.arms[side].ids[3]]=side*6
  for finger in 5:
   var chain:Array=n.grip.fingers[side][finger]
   for segment in range(1,4):groups[chain[segment]]=side*6+finger+1
 var positions:PackedVector3Array=[];var labels:PackedInt32Array=[]
 for vertex in vertices.size():
  var totals:Dictionary={};var point:=Vector3.ZERO
  for slot in slots:
   var bind:int=bones[vertex*slots+slot];var weight:float=weights[vertex*slots+slot]
   if weight<=0:continue
   point+=(matrices[bind]*vertices[vertex])*weight
   var bone:int=skin.get_bind_bone(bind)
   if groups.has(bone):totals[groups[bone]]=totals.get(groups[bone],0.0)+weight
  var label:=-1
  for group in totals:
   if totals[group]>.70:label=group
  labels.append(label);positions.append(point)
 var triangles:Array=[]
 for group in 12:triangles.append([])
 for triangle in indices.size()/3:
  var a:int=indices[triangle*3];var b:int=indices[triangle*3+1];var c:int=indices[triangle*3+2]
  if labels[a]<0 or labels[a]!=labels[b] or labels[b]!=labels[c]:continue
  triangles[labels[a]].append([positions[a],positions[b],positions[c]])
 for side in 2:
  for finger in 6:require(triangles[side*6+finger].size()>10,'Collision validation includes visible palm and every distal finger')
  for first in 6:
   for second in range(first+1,6):
    var collisions:=0
    for a in triangles[side*6+first]:
     var bounds:=AABB(a[0],Vector3.ZERO).expand(a[1]).expand(a[2]).grow(.00001)
     for b in triangles[side*6+second]:
      if not bounds.intersects(AABB(b[0],Vector3.ZERO).expand(b[1]).expand(b[2]).grow(.00001)):continue
      if triangles_cross(a,b):collisions+=1
    require(collisions==0,'Native relaxed skin must not intersect itself: hand %d groups %d/%d (%d)'%[side,first,second,collisions])
 actor.free();print('%s: %d relaxed hand, length and native skin intersection checks'%['PASS' if failures==0 else 'FAIL',checks]);quit(1 if failures else 0)
