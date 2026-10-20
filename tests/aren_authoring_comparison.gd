extends SceneTree
## Measure the skeleton that the four-view scene actually displays.
var review:Control
var failures:=0
func require(value:bool,message:String) -> void:
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func skeleton() -> Skeleton3D:
 var actor=review.actors[0]
 return actor.native.skeleton if review.source_index==0 else actor.get_node(actor.model_path).find_children("*","Skeleton3D",true,false)[0]
func capture(source:int) -> Dictionary:
 review.select_source(source)
 var actor=review.actors[0]
 var rig:=skeleton()
 var frames:Array=[];var angles:Array=[[],[]];var tilts:Array=[];var support:Array=[]
 var duration:float=review.cycle_info("walk").duration
 var spine:=rig.find_bone("smartrig_Spine2")
 var foot:=rig.find_bone("smartrig_RightFoot")
 for frame in 121:
  review.show_frame("walk",frame/120.0*duration);rig.force_update_all_bone_transforms()
  var positions:Array[Vector3]=[]
  for bone in rig.get_bone_count():positions.append(rig.to_global(rig.get_bone_global_pose(bone).origin)-actor.global_position)
  frames.append(positions)
  var basis:=rig.global_transform.basis.orthonormalized()
  var body:Basis=basis*rig.get_bone_global_pose(spine).basis.orthonormalized()*rig.get_bone_global_rest(spine).basis.orthonormalized().inverse()*basis.inverse()
  tilts.append(atan2(-body.z.y,body.z.z))
  for side in 2:
   var label:="Right" if side==0 else "Left"
   var upper:=rig.find_bone("smartrig_"+label+"Arm")
   var elbow:=rig.find_bone("smartrig_"+label+"ForeArm")
   var direction:Vector3=body.inverse()*(positions[elbow]-positions[upper])
   angles[side].append(atan2(direction.z,-direction.y))
  if frame>=4 and frame<=26:support.append(positions[foot].z)
 var amplitudes:Array=[]
 for side in 2:amplitudes.append(float(angles[side].max())-float(angles[side].min()))
 return {"frames":frames,"arm_range":amplitudes,"tilts":tilts,"stance_span_m":float(support.max())-float(support.min()),"duration":duration}
func max_delta(a:Dictionary,b:Dictionary) -> float:
 var result:=0.0
 for frame in a.frames.size():
  for bone in a.frames[frame].size():result=maxf(result,a.frames[frame][bone].distance_to(b.frames[frame][bone]))
 return result
func run() -> void:
 review=load("res://scenes/prototype_3d/aren_authoring_review.tscn").instantiate();root.add_child(review);review.playing=false;review.set_process(false)
 require(review.source_selector.item_count>=3,"The F6 scene exposes the actual source selector")
 var original:=capture(0)
 require(review.actors[0].get_script().resource_path=="res://scripts/prototype_3d/survivor_model.gd","Original uses the approved procedural actor")
 var natural:=capture(1)
 require(review.actors[0].library.resource_path.ends_with("aren_natural_v1/clips.res"),"Natural uses its own baked library")
 var proof:=capture(2)
 require(review.actors[0].library.resource_path.ends_with("aren_walk_proof_20_30_v1/clips.res"),"Proof uses its independent baked library")
 var proof_clip:Animation=review.actors[0].library.get_animation(&"walk")
 for path in proof_clip.get_meta("source_hashes"):
  require(FileAccess.get_sha256(path)==proof_clip.get_meta("source_hashes")[path],"Proof was baked with the current sources: "+str(path))
 var stride_ratio:float=proof.stance_span_m/original.stance_span_m
 var arm_ratios:Array=[]
 for side in 2:
  var ratio:float=proof.arm_range[side]/original.arm_range[side];arm_ratios.append(ratio)
  require(absf(ratio-1.3)<.02,"Rendered shoulder swing grows by 30 percent")
 var tilt_delta:=0.0
 for frame in 120:tilt_delta+=float(proof.tilts[frame])-float(original.tilts[frame])
 tilt_delta=rad_to_deg(tilt_delta/120)
 require(absf(stride_ratio-1.2)<.02,"Rendered planted stride grows by 20 percent")
 require(absf(tilt_delta-4.0)<.2,"Visible torso adds four degrees forward lean")
 require(max_delta(original,proof)>.05,"The output changes real bone positions, not just metadata")
 review.select_source(0);review.elapsed=review.cycle_info("walk").duration*.125;review.show_frame("walk",review.elapsed)
 var before:=skeleton().get_bone_global_pose(skeleton().find_bone("smartrig_Spine2"))
 review.select_source(2)
 var after:=skeleton().get_bone_global_pose(skeleton().find_bone("smartrig_Spine2"))
 require(absf(review.elapsed/review.cycle_info("walk").duration-.125)<.0001,"Switching preserves normalized phase while paused")
 require(before.basis.get_rotation_quaternion().angle_to(after.basis.get_rotation_quaternion())>.05,"Paused source switch updates the displayed pose immediately")
 var report:Dictionary={"original_vs_natural_max_bone_delta_m":max_delta(original,natural),"original_vs_proof_max_bone_delta_m":max_delta(original,proof),"stride_ratio":stride_ratio,"arm_swing_ratios":arm_ratios,"added_torso_lean_degrees":tilt_delta,"original_duration_s":original.duration,"proof_duration_s":proof.duration}
 var args:=OS.get_cmdline_user_args()
 if args.size()==1 and args[0].begins_with("/") and not args[0].begins_with(ProjectSettings.globalize_path("res://")):
  var file:=FileAccess.open(args[0],FileAccess.WRITE)
  if file:file.store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report));review.free()
 print("PASS: F6 source selection and rendered-pose A/B comparison" if failures==0 else "FAIL: A/B comparison");quit(1 if failures else 0)
