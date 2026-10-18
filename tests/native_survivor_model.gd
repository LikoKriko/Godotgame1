extends SceneTree
## The actual visible 66-bone composite, including both neck seams and native skin.
var failures:=0;var checks:=0
var morphs:Array=[]
var skin_node:MeshInstance3D
func require(value:bool,message:String):
 checks+=1
 if not value:
  failures+=1
  if failures<18:push_error(message)
func _initialize():call_deferred("run")
func deform(arrays:Array,index:int,matrices:Array[Transform3D],surface:int=0) -> Vector3:
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var ids:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var slots:int=ids.size()/vertices.size();var point:=Vector3.ZERO
 var vertex:Vector3=vertices[index]
 for shape in morphs[surface].size():vertex+=(morphs[surface][shape][Mesh.ARRAY_VERTEX][index]-vertices[index])*skin_node.get_blend_shape_value(shape)
 for slot in slots:
  if weights[index*slots+slot]>0:point+=(matrices[ids[index*slots+slot]]*vertex)*weights[index*slots+slot]
 return point
func run():
 var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();root.add_child(actor)
 var native=actor.native;var mesh:Mesh=actor.mesh_node.mesh;var skin:Skin=actor.mesh_node.skin
 skin_node=actor.mesh_node
 for surface in mesh.get_surface_count():morphs.append(mesh.surface_get_blend_shape_arrays(surface))
 require(native.skeleton.get_bone_count()==66,"The original 66-bone rig skins the visible character")
 require(mesh!=actor.AXILLA_SKIN and mesh.get_surface_count()==3,"One new skinned mesh contains body, approved head and connected neck")
 require(absf(actor.author_bounds().size.y-64)<.002,"Composite retains the common 1.75 m authoring scale")
 require(native.binding.errors.is_empty(),"Native rig resolves through the shared humanoid profile")
 var surfaces:Array=[]
 for s in mesh.get_surface_count():surfaces.append(mesh.surface_get_arrays(s))
 require(mesh.get_blend_shape_count()==2,"Each knee has an independent corrective")
 for surface in 3:
  for side in 2:
   var changed:=0
   var knee:Vector3=native.inverse_frame*native.rest[native.legs[side].ids[1]].origin
   for vertex in surfaces[surface][Mesh.ARRAY_VERTEX].size():
    var base:Vector3=surfaces[surface][Mesh.ARRAY_VERTEX][vertex]
    var offset:Vector3=morphs[surface][side][Mesh.ARRAY_VERTEX][vertex]-base
    if offset.length()<.000001:continue
    changed+=1
    require(surface==0 and absf(base.y-knee.y)<.131 and base.z<knee.z+.006,"Corrective stays at the back of its own knee")
    require(absf(offset.x)<.000001 and absf(offset.y)<.000001 and offset.z<0 and offset.length()<.081,"Corrective fills the fold without moving the knee joint")
   require(changed>100 if surface==0 else changed==0,"Head and neck remain unchanged by both knee morphs")
 # Every bridge vertex is also present on the adjacent body or head boundary.
 var pairs:Array=[];var bridge:Array=surfaces[2]
 for i in bridge[Mesh.ARRAY_VERTEX].size():
  var point:Vector3=bridge[Mesh.ARRAY_VERTEX][i];var found:=false
  for surface in 2:
   for vertex in surfaces[surface][Mesh.ARRAY_VERTEX].size():
    if point.distance_to(surfaces[surface][Mesh.ARRAY_VERTEX][vertex])>.00001:continue
    pairs.append([i,surface,vertex]);found=true;break
   if found:break
  require(found,"Neck transition shares an exact geometric boundary with body/head")
 require(pairs.size()>100,"Both neck contours are fully represented")
 var states:Array=[&"idle",&"walk",&"run",&"crouch",&"pickup",&"jump",&"death"]
 var clips=load("res://scripts/prototype_3d/survivor_animation.gd")
 states.append_array(clips.SLIDE_STATES)
 var worst_seam:=0.0;var worst_floor:=INF;var worst_bone:=0.0
 for state in states:
  for phase in [0.,.2,.4,.6,.8,1.]:
   actor.family_override=&"";actor.animate(state,phase,false,0,phase)
   native.skeleton.force_update_all_bone_transforms()
   # Quaternion reconstruction accumulates small float errors along the native chains.
   for bone in native.posed.size():
    var rendered:Transform3D=native.frame*native.skeleton.get_bone_global_pose(bone)
    var expected:Transform3D=native.posed[bone]
    var error:float=rendered.origin.distance_to(expected.origin)
    for axis in 3:error=maxf(error,rendered.basis[axis].distance_to(expected.basis[axis]))
    require(error<.0005,"Rendered native skeleton agrees with solved transforms")
   var matrices:Array[Transform3D]=[]
   for bind in skin.get_bind_count():matrices.append(native.frame*native.skeleton.get_bone_global_pose(skin.get_bind_bone(bind))*skin.get_bind_pose(bind))
   for pair in pairs:
    var error:=deform(bridge,pair[0],matrices,2).distance_to(deform(surfaces[pair[1]],pair[2],matrices,pair[1]));worst_seam=maxf(worst_seam,error)
    require(error<.01,"Neck remains closed throughout animation")
   for bone in native.posed.size():
    var parent:int=native.parents[bone]
    if parent<0:continue
    var error:float=absf(native.posed[bone].origin.distance_to(native.posed[parent].origin)-native.rest[bone].origin.distance_to(native.rest[parent].origin)*(native.grip.HAND_SCALE if native.grip.relaxed.has(bone) else 1.0));worst_bone=maxf(worst_bone,error)
    require(error<.0001,"Native limb lengths and configured hand proportions remain fixed")
   var floor_value:=INF
   for surface in surfaces.size():
    var arrays:Array=surfaces[surface]
    for vertex in range(0,arrays[Mesh.ARRAY_VERTEX].size(),5):
     var point:=deform(arrays,vertex,matrices,surface);require(point.is_finite(),"Visible skin remains finite")
     floor_value=minf(floor_value,point.y)
   worst_floor=minf(worst_floor,floor_value)
   require(floor_value>-.10,"Native skin clears floor: %s %.2f %.6f"%[state,phase,floor_value])
 # Measure the bent, rendered skin: the posterior contour gains volume instead
 # of merely moving a bone or changing a number on the animation controller.
 for side in 2:
  actor.animate(&"crouch",1,false,0,0,Vector3.ZERO)
  native.skeleton.force_update_all_bone_transforms()
  var matrices:Array[Transform3D]=[]
  for bind in skin.get_bind_count():matrices.append(native.frame*native.skeleton.get_bone_global_pose(skin.get_bind_bone(bind))*skin.get_bind_pose(bind))
  var value:float=skin_node.get_blend_shape_value(side)
  require(value>.35,"The flexed crouching knee receives posterior support")
  var gain:=0.0;var count:=0;var knee:Vector3=native.posed[native.legs[side].ids[1]].origin
  for vertex in surfaces[0][Mesh.ARRAY_VERTEX].size():
   if (morphs[0][side][Mesh.ARRAY_VERTEX][vertex]-surfaces[0][Mesh.ARRAY_VERTEX][vertex]).z>-.025:continue
   skin_node.set_blend_shape_value(side,0)
   var before:=deform(surfaces[0],vertex,matrices).distance_to(knee)
   skin_node.set_blend_shape_value(side,value)
   gain+=deform(surfaces[0],vertex,matrices).distance_to(knee)-before;count+=1
  require(count>20 and gain/count>.2,"Visible posterior knee contour retains volume in flexion")
 # Explicit skull turns exercise the new head/neck weights independently of gait.
 for yaw in [-.7,.7]:
  actor.animate(&"idle",0,false);actor.rig.posed[3].basis=Basis(Vector3.UP,yaw);native.sync(actor.rig,actor.last_pose)
  native.skeleton.force_update_all_bone_transforms()
  var matrices:Array[Transform3D]=[]
  for bind in skin.get_bind_count():matrices.append(native.frame*native.skeleton.get_bone_global_pose(skin.get_bind_bone(bind))*skin.get_bind_pose(bind))
  for pair in pairs:require(deform(bridge,pair[0],matrices,2).distance_to(deform(surfaces[pair[1]],pair[2],matrices,pair[1]))<.01,"Head turns keep both neck contours closed")
 for family in [&"axe",&"pickaxe",&"sword",&"bow",&"bottle"]:
  actor.family_override=family
  for phase in [.25,.5,.75]:
   actor.animate(&"draw" if family==&"bow" else (&"drink" if family==&"bottle" else &"action"),phase,family==&"axe",0,phase)
   require(native.hand_error<.08,"Native palms reach held contacts: %s %.2f %.6f"%[family,phase,native.hand_error])
 # Use the real directional gait, not only the zero-movement authoring poses.
 actor.family_override=&""
 for state in [&"walk",&"run"]:
  for direction in [Vector3.BACK,Vector3.FORWARD,Vector3.LEFT,Vector3.RIGHT,Vector3(-1,0,1).normalized(),Vector3(1,0,1).normalized(),Vector3(-1,0,-1).normalized(),Vector3(1,0,-1).normalized()]:
   var minimum:=INF;var maximum:=-INF
   var previous:Array=[]
   for frame in 65:
    var phase:=frame/64.0
    actor.animate(state,phase,false,0,phase,direction)
    var hip:Vector3=actor.last_pose.pelvis*Vector3(0,31,0)
    minimum=minf(minimum,hip.y);maximum=maxf(maximum,hip.y)
    for side in 2:
     var bone:int=native.legs[side].ids[0]
     var rotation:Quaternion=native.posed[bone].basis.get_rotation_quaternion()
     if not previous.is_empty():require(rotation.angle_to(previous[side])<.5,"Native trouser/thigh rotation stays continuous through support transfer")
    previous=[native.posed[native.legs[0].ids[0]].basis.get_rotation_quaternion(),native.posed[native.legs[1].ids[0]].basis.get_rotation_quaternion()]
   require(maximum-minimum<.8,"Walking/running hips avoid reach-induced pumping in every direction")
   require(minimum>(29.7 if state==&"walk" else 29.65),"Upright gait removes 85 percent of the previous low stance")
 # Lateral stepping must not pull the proximal thighs far out of the shorts
 # or pump the rendered hip contour open/closed on every transfer.
 var hip_vertices:Array[int]=[]
 for index in surfaces[0][Mesh.ARRAY_VERTEX].size():
  var point:Vector3=native.frame*surfaces[0][Mesh.ARRAY_VERTEX][index]
  if point.y>33 and point.y<36:hip_vertices.append(index)
 require(hip_vertices.size()>100,"Lateral contour check samples the visible hip and upper shorts")
 for state in [&"walk",&"run"]:
  for direction in [Vector3.LEFT,Vector3.RIGHT]:
   var narrowest:=INF;var widest:=0.0
   for sample in 33:
    var phase:=sample/32.0
    actor.animate(state,phase,false,0,phase,direction)
    var matrices:Array[Transform3D]=[]
    for bind in skin.get_bind_count():matrices.append(native.posed[skin.get_bind_bone(bind)]*skin.get_bind_pose(bind))
    var minimum:=INF;var maximum:=-INF
    for index in hip_vertices:
     var point:=deform(surfaces[0],index,matrices)
     minimum=minf(minimum,point.x);maximum=maxf(maximum,point.x)
    narrowest=minf(narrowest,maximum-minimum);widest=maxf(widest,maximum-minimum)
    for side in 2:
     var ids:Array=native.legs[side].ids
     var thigh:Vector3=native.posed[ids[1]].origin-native.posed[ids[0]].origin
     var limit:float=12*clips.Gait.WALK_KNEE_SPREAD
     require(absf(atan2(thigh.x,-thigh.y))<deg_to_rad(limit),"Lateral shuffle bounds thigh abduction instead of stretching the hip")
   require(widest-narrowest<2.5,"Rendered lateral hip/short contour avoids the previous broad expansion")
 actor.animate(&"walk",.25,false,0,.25,Vector3.BACK)
 var visible:Basis=native.posed[native.spine[2]].basis*native.rest[native.spine[2]].basis.inverse()
 require(visible.get_euler().y*actor.last_pose.pelvis.basis.get_euler().y<0,"The visible walking back counter-rotates gently against the hips")
 var left:Dictionary=clips.walking_arm(actor.last_pose,0,.25)
 var right:Dictionary=clips.walking_arm(actor.last_pose,1,.25)
 require((left.joint-left.root).dot(actor.last_pose.body.basis.z)<0 and (right.joint-right.root).dot(actor.last_pose.body.basis.z)>0,"Left elbow moves back during right-leg recovery; the other arm counterbalances")
 require(absf(left.wrist)<.026,"Walking wrist follow-through remains subtle")
 actor.animate(&"run",.25,false,0,.25,Vector3.BACK)
 require(clips.walking_arm(actor.last_pose,0,.25).is_empty(),"Walking follow-through does not alter running arms")
 actor.family_override=&"sword"
 for frame in 65:
  var phase:=frame/64.0
  actor.animate(&"action",phase,true,0,phase)
  var side:int=1-actor.last_pose.active;var ids:Array=native.arms[side].ids
  var rest_axis:Vector3=actor.last_pose.body.basis*(native.rest[ids[1]].origin-native.rest[ids[0]].origin)
  var axis:Vector3=native.posed[ids[1]].origin-native.posed[ids[0]].origin
  require(rest_axis.angle_to(axis)<deg_to_rad(5),"Sword counterweight uses native arm proportions without pulling the clavicle")
 print("%s: %d native rig, visible skin, neck seam and contact checks; seam %.6f bone %.6f floor %.6f"%["PASS" if failures==0 else "FAIL",checks,worst_seam,worst_bone,worst_floor])
 actor.free();await process_frame;quit(1 if failures else 0)
