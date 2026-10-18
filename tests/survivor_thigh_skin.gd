extends SceneTree
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:
  failures+=1
  if failures<12:push_error(message)
func point(arrays:Array,index:int,matrices:Array[Transform3D]) -> Vector3:
 var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var slots:int=bones.size()/arrays[Mesh.ARRAY_VERTEX].size();var result:=Vector3.ZERO
 for slot in slots:result+=matrices[bones[index*slots+slot]]*arrays[Mesh.ARRAY_VERTEX][index]*weights[index*slots+slot]
 return result
func _initialize():call_deferred("run")
func run():
 var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();root.add_child(actor)
 var n=actor.native;var skin:Skin=actor.mesh_node.skin
 var original:Array=n.source_mesh.surface_get_arrays(0);var repaired:Array=actor.mesh_node.mesh.surface_get_arrays(0)
 var quads:Array[int]=[];var knees:Array[int]=[]
 for index in original[Mesh.ARRAY_VERTEX].size():
  var p:Vector3=n.frame*original[Mesh.ARRAY_VERTEX][index]
  if absf(p.x)<1.5:continue
  if p.y>24 and p.y<32.5 and p.z>3.4:quads.append(index)
  if p.y>16 and p.y<24:knees.append(index)
 require(quads.size()>100 and knees.size()>100,"Regression measures the original visible quadriceps and knee skin")
 var slots:int=original[Mesh.ARRAY_BONES].size()/original[Mesh.ARRAY_VERTEX].size()
 for vertex in quads+knees:
  for slot in slots:
   var offset:int=vertex*slots+slot
   require(original[Mesh.ARRAY_BONES][offset]==repaired[Mesh.ARRAY_BONES][offset],"Front thighs and knees keep their original bone assignments")
   require(absf(original[Mesh.ARRAY_WEIGHTS][offset]-repaired[Mesh.ARRAY_WEIGHTS][offset])<.00004,"Pelvis support never adds a false hip influence inside the quadriceps or knee")
 for state in [&"walk",&"run"]:
  for direction in [Vector3.BACK,Vector3.FORWARD,Vector3.LEFT,Vector3.RIGHT,Vector3(1,0,1).normalized(),Vector3(-1,0,-1).normalized()]:
   for sample in 9:
    var phase:=sample/8.0;actor.animate(state,phase,false,0,phase,direction)
    var matrices:Array[Transform3D]=[]
    for bind in skin.get_bind_count():matrices.append(n.posed[skin.get_bind_bone(bind)]*skin.get_bind_pose(bind))
    for index in range(0,quads.size(),3):
     var vertex:int=quads[index]
     require(point(original,vertex,matrices).distance_to(point(repaired,vertex,matrices))<.002,"Moving quadriceps follow the native thigh without the extra mid-muscle bend from pelvis support")
    for index in range(0,knees.size(),5):
     var vertex:int=knees[index]
     require(point(original,vertex,matrices).distance_to(point(repaired,vertex,matrices))<.002,"Knee skin retains its anatomical hinge and original smooth thigh/shin transition")
 actor.free();print("%s: %d quadriceps/knee skin preservation and gait deformation checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
