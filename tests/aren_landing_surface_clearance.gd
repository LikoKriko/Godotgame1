extends SceneTree
## Independent surface check: convex knee skin against actual torso/arm triangles.
func _initialize():call_deferred("run")
func skin(record:Array,n) -> Vector3:
 var p:=Vector3.ZERO
 for inf in record:p+=n.posed[inf[0]].basis*inf[1]+n.posed[inf[0]].origin*inf[2]
 return p*(1.75/64.0)
func run():
 var a=load("res://scenes/prototype_3d/aren_landing_review_actor.tscn").instantiate();root.add_child(a);a.set_process(false)
 var n=a.native;var knees:Array=[];var triangles:Array=[]
 var k:Vector3=n.rest[n.legs[1].ids[1]].origin
 for surf in n.mesh.mesh.get_surface_count():
  var ar:Array=n.mesh.mesh.surface_get_arrays(surf);var vertices:PackedVector3Array=ar[Mesh.ARRAY_VERTEX];var ids:PackedInt32Array=ar[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=ar[Mesh.ARRAY_WEIGHTS];var indices:PackedInt32Array=ar[Mesh.ARRAY_INDEX];var slots:int=ids.size()/vertices.size()
  var records:Array=[];var ownership:Array[float]=[];var arm_ownership:Array[float]=[]
  for v in vertices.size():
   var record:Array=[];var p:=Vector3.ZERO;var torso:=0.0;var leg:=0.0;var arm:=0.0
   for slot in slots:
    var i:int=v*slots+slot
    if weights[i]<=0:continue
    var bone:int=n.mesh.skin.get_bind_bone(ids[i]);var local:Vector3=n.mesh.skin.get_bind_pose(ids[i])*vertices[v]
    record.append([bone,local*weights[i],weights[i]]);p+=(n.rest[bone]*local)*weights[i]
    if bone in n.spine or bone==n.binding.bone(&"root"):torso+=weights[i]
    if bone in [n.arms[1].ids[0],n.arms[1].ids[1]]:arm+=weights[i]
    if bone in [n.legs[1].ids[0],n.legs[1].ids[1]]:leg+=weights[i]
   records.append(record);ownership.append(torso);arm_ownership.append(arm)
   if leg>.75 and p.distance_to(k)*a.SCALE<.065:knees.append(record)
  for face in range(0,indices.size(),3):
   if minf(ownership[indices[face]],minf(ownership[indices[face+1]],ownership[indices[face+2]]))>.5 or minf(arm_ownership[indices[face]],minf(arm_ownership[indices[face+1]],arm_ownership[indices[face+2]]))>.5:
    for offset in 3:triangles.append(records[indices[face+offset]])
 var errors:Array[String]=[]
 for style in ["normal","cautious","tired"]:
  a.set_style(style)
  for h in [3.0,4.8,7.9]:
   a.review_height=h
   for gait in ["idle_to_fall","walk_to_fall","run_to_fall"]:
    a.begin_preview(gait);a.advance_jump_preview(.55+sqrt(2*h/9.8)+.5)
    for frame in 2:
     a.advance_jump_preview(.15)
     var points:=PackedVector3Array()
     for record in triangles:points.append(skin(record,n))
     var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(points)
     var body:=StaticBody3D.new();body.collision_layer=2;body.collision_mask=0;var collider:=CollisionShape3D.new();collider.shape=shape;body.add_child(collider);root.add_child(body)
     var knee_points:=PackedVector3Array()
     for record in knees:knee_points.append(skin(record,n))
     var query:=PhysicsShapeQueryParameters3D.new();var knee_shape:=ConvexPolygonShape3D.new();knee_shape.points=knee_points;query.shape=knee_shape;query.collision_mask=2;query.margin=.0001
     await physics_frame;await physics_frame
     if not a.get_world_3d().direct_space_state.intersect_shape(query).is_empty():errors.append(style+"/"+str(h)+gait+" t"+str(a.stage_time))
     body.free()
 print("KNEE/TORSO/UPPER ARM SURFACE triangles ",triangles.size()/3," knee points ",knees.size()," intersections ",errors)
 a.free();quit(0 if errors.is_empty() else 1)
