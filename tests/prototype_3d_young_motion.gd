extends SceneTree
const Model=preload("res://scripts/prototype_3d/young_model.gd")
const Motion=preload("res://scripts/prototype_3d/young_rig_motion.gd")
var failures:=0;var checks:=0
func require(value:bool,message:String):
 checks+=1
 if not value:
  failures+=1
  if failures<18:push_error(message)
func _initialize():call_deferred("run")
func run():
 var actor:=Model.new();root.add_child(actor)
 require(actor.skeleton.get_bone_count()==25,"Original 25 native bones")
 var skin:=actor.mesh_node.skin;var arrays:Array=actor.mesh_node.mesh.surface_get_arrays(0)
 var v:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var ids:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var w:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var worst_length:=0.;var lowest:=INF;var worst_floor:="";var previous:Array[Transform3D]=[]
 for state in Motion.STATES:
  for left in ([true,false] if state in [&"attack",&"hook"] else [true]):
   previous.clear()
   for frame in 121:
    actor.animate(state,frame/120.,left)
    for i in 25:
     var local:Transform3D=actor.posed[actor.parents[i]].affine_inverse()*actor.posed[i] if actor.parents[i]>=0 else actor.posed[i]
     var rest:Transform3D=actor.rest[actor.parents[i]].affine_inverse()*actor.rest[i] if actor.parents[i]>=0 else actor.rest[i]
     var error:=absf(local.origin.length()-rest.origin.length()) if actor.parents[i]>=0 else 0.0
     worst_length=maxf(worst_length,error)
     require(error<.00003,"Native bone length remains fixed")
     require(local.basis.get_scale().distance_to(rest.basis.get_scale())<.00003,"Native bone scale remains fixed")
     if not previous.is_empty():require(actor.posed[i].origin.distance_to(previous[i].origin)<.10,"Native animation remains continuous: %s %.5f %s %.6f"%[state,frame/120.,actor.skeleton.get_bone_name(i),actor.posed[i].origin.distance_to(previous[i].origin)])
    if frame%10==0:
     var matrices:Array[Transform3D]=[]
     for i in skin.get_bind_count():matrices.append(actor.posed[skin.get_bind_bone(i)]*skin.get_bind_pose(i))
     var floor_value:=INF
     for i in v.size():
      var point:=Vector3.ZERO
      for slot in 4:point+=(matrices[ids[i*4+slot]]*v[i])*w[i*4+slot]
      floor_value=minf(floor_value,point.y)
     if floor_value<lowest:lowest=floor_value;worst_floor=String(state)
     require(floor_value>-.001,"Real skin floor: %s %.4f -> %.6f"%[state,frame/120.,floor_value])
    previous.assign(actor.posed)
 print("Checks ",checks," failures ",failures," bone error ",worst_length," lowest ",lowest," state ",worst_floor)
 actor.free();await process_frame;quit(1 if failures else 0)
