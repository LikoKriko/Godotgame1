extends SceneTree
const HipSkin=preload("res://scripts/animation/characters/hip_skin.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:
  failures+=1
  if failures<12:push_error(message)
func point(arrays:Array,index:int,matrices:Array[Transform3D]) -> Vector3:
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var slots:int=bones.size()/vertices.size();var result:=Vector3.ZERO
 for slot in slots:result+=matrices[bones[index*slots+slot]]*vertices[index]*weights[index*slots+slot]
 return result
func _initialize():call_deferred("run")
func run():
 var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();root.add_child(actor)
 var native=actor.native;var skin:Skin=actor.mesh_node.skin
 var source:Array=native.source_mesh.surface_get_arrays(0)
 var stable:Array=actor.mesh_node.mesh.surface_get_arrays(0)
 for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_INDEX]:
  require(source[channel]==stable[channel],"Hip support preserves original rest geometry, shading, UVs and topology")
 require(HipSkin.stable_mesh(native.source_mesh,skin,native.frame,native.binding.names["smartrig_Hips"])==actor.mesh_node.mesh,"Skin support is cached instead of rebuilt during animation")
 var hip_bind:=-1
 for bind in skin.get_bind_count():
  if skin.get_bind_bone(bind)==native.binding.names["smartrig_Hips"]:hip_bind=bind
 var samples:Array[int]=[]
 for index in source[Mesh.ARRAY_VERTEX].size():
  var height:float=(native.frame*source[Mesh.ARRAY_VERTEX][index]).y
  if height>30 and height<36:samples.append(index)
 require(samples.size()>100,"Skin regression measures the actual visible pelvis")
 var displaced:=0;var worst_error:=0.0
 for family in [&"",&"sword",&"axe",&"pickaxe"]:
  actor.family_override=family
  for state in [&"walk",&"run",&"action"]:
   for frame in 9:
    var t:=frame/8.0;actor.animate(state,t,family!=&"",0,t,Vector3.RIGHT)
    var matrices:Array[Transform3D]=[]
    for bind in skin.get_bind_count():matrices.append(native.posed[skin.get_bind_bone(bind)]*skin.get_bind_pose(bind))
    for index in samples:
     var original:=point(source,index,matrices);var result:=point(stable,index,matrices)
     var rigid:Vector3=matrices[hip_bind]*source[Mesh.ARRAY_VERTEX][index]
     worst_error=maxf(worst_error,result.distance_to(rigid.lerp(original,.4)))
     require(result.distance_to(rigid.lerp(original,.4))<.002,"Visible hip deformation retains forty percent of the previous skin response within GPU weight precision")
     if original.distance_to(rigid)>.01:displaced+=1
 require(displaced>100,"Percentage check includes genuinely deforming hip vertices")
 actor.family_override=&"";actor.sprint_weight=0
 actor.animate(&"walk",.3,false,0,.3,Vector3.BACK)
 var feet:Array[Vector3]=[native.posed[native.legs[0].ids[2]].origin,native.posed[native.legs[1].ids[2]].origin]
 actor.animate(&"start_run",0,false,0,.3,Vector3.BACK)
 for side in 2:require(native.posed[native.legs[side].ids[2]].origin.distance_to(feet[side])<.5,"Native foot alignment blends with sprint instead of snapping on the first running frame")
 actor.sprint_weight=-1
 for fps in [30,60,120]:
  for direction in [Vector3.BACK,Vector3.FORWARD,Vector3.RIGHT,Vector3.LEFT,Vector3(1,0,1).normalized()]:
   actor.displayed_pose.clear();actor.gait_active=false;actor.gait_direction.reset()
   var speed:=4.48;var previous:=Vector3.ZERO;var sum:=0.0;var count:=0
   var distance:float=actor.Clips.cycle_distance(1,0,direction)
   var support:float=actor.Clips.Gait.RUN_SUPPORT*actor.Clips.directional_stride(direction)*lerpf(1,actor.Clips.LATERAL_STEP_SCALE,smoothstep(sqrt(.5),1,absf(direction.x)))
   for frame in fps*2:
    var phase:=fposmod(frame*speed/distance/fps,1)
    actor.animate(&"run",phase,false,1.0/fps,phase,direction)
    var foot:Vector3=native.posed[native.legs[0].ids[2]].origin*(1.75/64)+direction*frame*speed/fps
    var previous_phase:=fposmod((frame-1)*speed/distance/fps,1)
    if frame>fps/2 and phase>.01 and phase<support-.01 and previous_phase>.01 and previous_phase<phase:
     sum+=Vector2(foot.x-previous.x,foot.z-previous.z).length()*fps;count+=1
    previous=foot
   if (support-.02)*distance/speed>2.0/fps:require(count>0,"Running regression measures real planted samples at each frame rate")
   require(sum/maxi(count,1)<.15,"Rendered running foot stays planted while the body travels at full sprint speed")
 print("Hip quantization error ",worst_error)
 actor.free();print("%s: %d hip skin preservation, sixty-percent deformation reduction and running contact checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
