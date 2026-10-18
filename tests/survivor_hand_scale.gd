extends SceneTree
## Hand proportions, rendered wrist seams and held contacts; no gait/strike review.
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:
  failures+=1
  if failures<15:push_error(message)
func _initialize():call_deferred('run')
func run():
 var actor=load('res://scripts/prototype_3d/survivor_model.gd').new();root.add_child(actor)
 var n=actor.native
 var skin:Skin=n.mesh.skin
 var arrays:Array=n.mesh.mesh.surface_get_arrays(0)
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
 var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var slots:int=bones.size()/vertices.size()
 var wrist_vertices:Array=[];var palm_vertices:Array=[]
 for side in 2:
  var hand:int=n.arms[side].ids[3]
  var wrist:Vector3=n.rest[hand].origin
  var seams:Dictionary={};var palms:Array=[]
  for vertex in vertices.size():
   var point:Vector3=n.frame*vertices[vertex]
   if point.distance_to(wrist)<1.7:
    var key:Vector3=point.snapped(Vector3.ONE*.0001)
    if not seams.has(key):seams[key]=[]
    seams[key].append(vertex)
   var hand_weight:=0.0
   for slot in slots:
    var bone:int=skin.get_bind_bone(bones[vertex*slots+slot])
    if bone==hand or n.grip.relaxed.has(bone) and ('Right' in n.skeleton.get_bone_name(bone))==(side==0):hand_weight+=weights[vertex*slots+slot]
   if hand_weight>.9999 and vertex%8==0:palms.append(vertex)
  var pairs:Array=[]
  for group in seams.values():
   for index in range(1,group.size()):pairs.append([group[0],group[index]])
  require(pairs.size()>5,'Actual wrist seam vertices are represented on both hands')
  require(palms.size()>20,'Visible palm and finger skin is represented independently of the seam')
  wrist_vertices.append(pairs);palm_vertices.append(palms)
 for family in [&'',&'axe',&'pickaxe',&'sword',&'bow',&'bottle',&'food',&'carried']:
  actor.family_override=family
  for state in [&'idle',&'equip',&'unequip']:
   var previous:Array=[]
   for frame in (range(1) if state==&'idle' else range(121)):
    var phase:float=frame/120.0;actor.animate(state,phase,family!=&'',n.Clips.duration(state,family)/120.0 if state!=&'idle' else 0.0)
    n.skeleton.force_update_all_bone_transforms()
    require(n.hand_error<.08,'Resized palms still reach their held contacts: %s %s %.2f'%[family,state,phase])
    var matrices:Array[Transform3D]=[]
    for bind in skin.get_bind_count():matrices.append(n.frame*n.skeleton.get_bone_global_pose(skin.get_bind_bone(bind))*skin.get_bind_pose(bind))
    var used:Dictionary={}
    for side in 2:
     for pair in wrist_vertices[side]:used[pair[0]]=true;used[pair[1]]=true
     for vertex in palm_vertices[side]:used[vertex]=true
    var points:Dictionary={}
    for vertex in used:
     var point:=Vector3.ZERO
     for slot in slots:
      var weight:float=weights[vertex*slots+slot]
      if weight>0:point+=(matrices[bones[vertex*slots+slot]]*vertices[vertex])*weight
     points[vertex]=point
    var rotations:Array=[]
    for side in 2:
     var hand:int=n.arms[side].ids[3]
     require(absf((n.posed[hand].basis*n.rest[hand].basis.inverse()).get_scale().x-.9)<.00001,'The wrist applies exactly ninety percent size once')
     for chain in n.grip.fingers[side]:
      for bone in chain:
       var parent:int=n.parents[bone]
       require(absf(n.posed[bone].origin.distance_to(n.posed[parent].origin)-n.rest[bone].origin.distance_to(n.rest[parent].origin)*.9)<.0001,'Every native finger segment inherits the same proportion')
       rotations.append((n.posed[hand].basis.inverse()*n.posed[bone].basis).orthonormalized().get_rotation_quaternion())
     var rendered_hand:Basis=(n.frame*n.skeleton.get_bone_global_pose(hand)).basis*n.rest[hand].basis.inverse()
     require(rendered_hand.get_scale().distance_to(Vector3.ONE*.9)<.00001,'Rendered skin receives ninety percent scale on all three hand axes')
     for vertex in palm_vertices[side]:require(points[vertex].is_finite(),'Native hand skin remains finite around the resized joints')
     for pair in wrist_vertices[side]:require(points[pair[0]].distance_to(points[pair[1]])<.001,'Duplicated visible wrist borders remain joined after scaling')
     if not n.grip.shafts.has(family) or n.Clips.arm_is_free(actor.last_pose,side) or state!=&'idle':continue
     var section:Vector3=n.grip.shafts[family][0 if side==actor.last_pose.active else 1]
     var shaft:Vector3=actor.last_pose.shaft.normalized()
     var center:Vector3=actor.grip_socket.position+actor.grip_socket.basis.x*section.x+actor.grip_socket.basis.z*section.y
     for chain in n.grip.fingers[side]:
      var tip:Vector3=n.posed[chain[3]].origin-center
      var radius:float=(tip-shaft*tip.dot(shaft)).length()
      require(radius>=section.z-.02 and radius<=section.z+.38,'Smaller fingers still wrap the full-size handle')
    if not previous.is_empty():
     for bone in rotations.size():require(rotations[bone].angle_to(previous[bone])<.55,'Grip continuity %s %s %.2f bone %d angle %.3f'%[family,state,phase,bone,rotations[bone].angle_to(previous[bone])])
    previous=rotations
   if state==&'equip' and n.grip.shafts.has(family):
    actor.animate(&'idle',0,true,n.Clips.duration(&'equip',family)/120.0)
    for side in 2:
     if n.Clips.arm_is_free(actor.last_pose,side):continue
     var index:=side*20
     for chain in n.grip.fingers[side]:
      for bone in chain:
       var rotation:Quaternion=(n.posed[n.arms[side].ids[3]].basis.inverse()*n.posed[bone].basis).orthonormalized().get_rotation_quaternion()
       require(rotation.angle_to(previous[index])<.55,'Equipment end %s side %d bone %d angle %.4f'%[family,side,bone,rotation.angle_to(previous[index])])
       index+=1
 # Drawing retains both bow contact points with the resized palms.
 actor.family_override=&'bow'
 for frame in 121:
  actor.animate(&'draw',frame/120.0,true)
  require(n.hand_error<.08,'Both resized hands retain their bow/string contacts while drawing')
 actor.free();print('%s: %d hand scale, rendered wrist, grip and equipment-transition checks'%['PASS' if failures==0 else 'FAIL',checks]);quit(1 if failures else 0)
