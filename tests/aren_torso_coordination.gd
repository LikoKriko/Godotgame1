extends SceneTree
const ROOT="res://assets/characters/prototype_3d/generated/"
const HipSkin=preload("res://scripts/animation/characters/hip_skin.gd")
var failures:=0
func require(value:bool,message:String) -> void:
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func span(values:Array) -> Vector3:
 var low:Vector3=values[0];var high:=low
 for value in values:low=low.min(value);high=high.max(value)
 return high-low
func capture(folder:String,motion:String="walk") -> Dictionary:
 var actor=load(ROOT+folder+"/aren.tscn").instantiate();root.add_child(actor);actor.set_process(false);actor.tree.active=false
 var model:Node3D=actor.get_node(actor.model_path)
 var rig:Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
 var mesh:MeshInstance3D=model.find_children("*","MeshInstance3D",true,false)[0]
 var clip:Animation=actor.library.get_animation(StringName(motion))
 var frame:Transform3D=actor.global_transform.affine_inverse()*rig.global_transform
 var hip:=rig.find_bone("smartrig_Hips")
 var angles:Dictionary={};var poses:Array=[];var arms:Array=[[],[]]
 var labels:Array[String]=["Hips","Spine","Spine1","Spine2"]
 for label in labels:angles[label]=[]
 var arrays:Array=mesh.mesh.surface_get_arrays(0)
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var slots:int=bones.size()/vertices.size();var indices:Array[int]=[]
 for vertex in range(0,vertices.size(),4):
  var point:Vector3=frame*vertices[vertex]
  if HipSkin.support_mask(point)>.95 and absf(point.x)<8.5:indices.append(vertex)
 var skin_low:Array[Vector3]=[];var skin_high:Array[Vector3]=[]
 skin_low.resize(indices.size());skin_high.resize(indices.size())
 for sample in 121:
  actor.player.play(StringName("aren/"+motion));actor.player.seek(sample/120.0*clip.length,true);rig.force_update_all_bone_transforms()
  var positions:Array[Vector3]=[]
  for bone in rig.get_bone_count():positions.append(rig.to_global(rig.get_bone_global_pose(bone).origin))
  poses.append(positions)
  for label in labels:
   var bone:=rig.find_bone("smartrig_"+label)
   var change:Basis=frame.basis.orthonormalized()*rig.get_bone_global_pose(bone).basis.orthonormalized()*rig.get_bone_global_rest(bone).basis.orthonormalized().inverse()*frame.basis.orthonormalized().inverse()
   angles[label].append(change.get_euler())
  var chest:int=rig.find_bone("smartrig_Spine2")
  var body:Basis=frame.basis.orthonormalized()*rig.get_bone_global_pose(chest).basis.orthonormalized()*rig.get_bone_global_rest(chest).basis.orthonormalized().inverse()*frame.basis.orthonormalized().inverse()
  for side in 2:
   var label:="Right" if side==0 else "Left"
   var arm:int=rig.find_bone("smartrig_"+label+"Arm");var elbow:int=rig.find_bone("smartrig_"+label+"ForeArm")
   var direction:Vector3=body.inverse()*(positions[elbow]-positions[arm])
   arms[side].append(atan2(direction.z,-direction.y))
  if sample%4!=0:continue
  var matrices:Array[Transform3D]=[]
  var relative:Transform3D=(frame*rig.get_bone_global_pose(hip)*(frame*rig.get_bone_global_rest(hip)).affine_inverse()).affine_inverse()
  for bind in mesh.skin.get_bind_count():matrices.append(relative*frame*rig.get_bone_global_pose(mesh.skin.get_bind_bone(bind))*mesh.skin.get_bind_pose(bind))
  for i in indices.size():
   var vertex:int=indices[i];var point:=Vector3.ZERO
   for slot in slots:
    var index:=vertex*slots+slot
    if weights[index]>0:point+=(matrices[bones[index]]*vertices[vertex])*weights[index]
   if sample==0:skin_low[i]=point;skin_high[i]=point
   else:skin_low[i]=skin_low[i].min(point);skin_high[i]=skin_high[i].max(point)
 var waist_motion:=0.0
 for i in indices.size():waist_motion+=(skin_high[i]-skin_low[i]).length()*(1.75/64.0)
 waist_motion/=maxi(indices.size(),1)
 var spans:Dictionary={}
 for label in labels:spans[label]=span(angles[label])
 var arm_ranges:Array=[]
 for side in 2:arm_ranges.append(float(arms[side].max())-float(arms[side].min()))
 var result:Dictionary={"spans":spans,"angles":angles,"poses":poses,"waist_motion_m":waist_motion,"waist_vertices":indices.size(),"arm_ranges":arm_ranges,"cycle":clip.get_meta("cycle"),"approved_skin":actor.use_approved_skin,"parameters":clip.get_meta("parameters")}
 if folder=="aren_walk_torso_v2":
  for path in clip.get_meta("source_hashes"):require(preload("res://tests/aren_branch_cache.gd").source_matches(path,clip.get_meta("source_hashes")[path]),"Correction matches its source hashes")
 actor.free();return result
func run() -> void:
 var before:=capture("aren_walk_proof_20_30_v1")
 var after:=capture("aren_walk_torso_v2")
 require(after.approved_skin,"Uses the same approved waist stabilization as gameplay")
 require(after.waist_vertices>50,"Samples actual visible waist skin")
 require(after.waist_motion_m<before.waist_motion_m*.65,"Visible waist deformation is reduced")
 require(after.spans.Hips.y<before.spans.Hips.y*.45,"Pelvis yaw oscillation reduced by at least 55 percent")
 var previous:=0.0
 for label in ["Spine","Spine1","Spine2"]:
  require(after.spans[label].z>previous+.001,"Frontal movement accumulates through abdomen and chest")
  require(after.spans[label].x>before.spans[label].x*3,"Support-linked flexion reaches every spine segment")
  previous=after.spans[label].z
  var covariance:=0.0
  for frame in 120:covariance+=after.angles.Hips[frame].y*after.angles[label][frame].y
  require(covariance<0,"The entire torso counter-rotates against the hips")
 require(after.cycle==before.cycle,"Stride, cadence, support timing and speed remain unchanged")
 for side in 2:require(absf(after.arm_ranges[side]/before.arm_ranges[side]-1)<.01,"Arm swing remains unchanged relative to the chest")
 var foot_error:=0.0
 # Native foot IDs follow the unmodified rig profile, not authored control IDs.
 var profile=load("res://assets/characters/prototype_3d/composite/model.scn").instantiate()
 var rig:Skeleton3D=profile.find_children("*","Skeleton3D",true,false)[0]
 for label in ["RightFoot","LeftFoot"]:
  var id:=rig.find_bone("smartrig_"+label)
  for frame in 121:foot_error=maxf(foot_error,after.poses[frame][id].distance_to(before.poses[frame][id]))
 profile.free()
 require(foot_error<.001,"Corrected torso preserves both foot trajectories within one millimetre")
 var original_library:AnimationLibrary=load(ROOT+"aren_walk_proof_20_30_v1/clips.res")
 var corrected_library:AnimationLibrary=load(ROOT+"aren_walk_torso_v2/clips.res")
 for motion in [&"idle",&"run"]:
  var a:Animation=original_library.get_animation(motion);var b:Animation=corrected_library.get_animation(motion)
  require(a.length==b.length and a.get_track_count()==b.get_track_count(),"Nonwalking clip timing and tracks preserved")
  var error:=0.0
  for track in a.get_track_count():
   require(a.track_get_path(track)==b.track_get_path(track) and a.track_get_key_count(track)==b.track_get_key_count(track),"Nonwalking tracks keep their native targets and keys")
   for key in a.track_get_key_count(track):
    var va=a.track_get_key_value(track,key);var vb=b.track_get_key_value(track,key)
    if va is Vector3:error=maxf(error,va.distance_to(vb))
    elif va is Quaternion:error=maxf(error,va.angle_to(vb))
    else:error=maxf(error,absf(float(va)-float(vb)))
  require(error<.002,"Idle and running poses remain unchanged within native numeric precision")
 var report:Dictionary={"waist_motion_ratio":after.waist_motion_m/before.waist_motion_m,"pelvis_yaw_ratio":after.spans.Hips.y/before.spans.Hips.y,"foot_delta_m":foot_error,"waist_vertices":after.waist_vertices,"spine_roll_span_deg":{}}
 for label in ["Spine","Spine1","Spine2"]:report.spine_roll_span_deg[label]=rad_to_deg(after.spans[label].z)
 print(JSON.stringify(report))
 print("PASS: waist skin, whole-spine coordination, counter-rotation and preserved contacts" if failures==0 else "FAIL: torso coordination");quit(1 if failures else 0)
