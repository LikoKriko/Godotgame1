extends RefCounted
## Native T-pose skin driven by shared gameplay contacts, without reweighting it
## onto the retired A-pose skeleton. Native bind axes remain intact; the hand
## proportion is applied once at each wrist without resizing the source mesh.
const PROFILE=preload("res://data/animation/characters/survivor_native.tres")
const Binding=preload("res://scripts/animation/shared/rig_binding.gd")
const Solver=preload("res://scripts/continuous_body_pose.gd")
const Frames=preload("res://scripts/prototype_3d/human_kinematics.gd")
const Clips=preload("res://scripts/prototype_3d/survivor_animation.gd")
const GROUND=preload("res://assets/characters/prototype_3d/composite/ground_supports.tres")
var ground=preload("res://scripts/animation/characters/skin_ground.gd").new()
var ground_enabled:=true
var binding=Binding.new()
var writer=preload("res://scripts/animation/shared/skeleton_pose.gd").new()
var skeleton:Skeleton3D
var mesh:MeshInstance3D
var source_mesh:Mesh
var frame:Transform3D
var inverse_frame:Transform3D
var rest:Array[Transform3D]=[]
var inverse_rest:Array[Transform3D]=[]
var posed:Array[Transform3D]=[]
var local_globals:Array[Transform3D]=[]
var parents:Array[int]=[]
var arms:Array[Dictionary]=[]
var legs:Array[Dictionary]=[]
var knee_shapes:Array[int]=[]
var driven:Dictionary={}
var spine:Array[int]=[]
var spine_segments:PackedInt32Array=[]
var finger_sides:PackedInt32Array=[]
var finger_axes:Array[Vector3]=[]
var finger_angles:Array[float]=[]
const SPINE_TWIST_SHARES:Array[float]=[.25,.60,1.0]
var grip=preload("res://scripts/animation/characters/native_hand_grip.gd").new()
var head:int
var neck:int
var walk_posture:=0.0
var run_posture:=0.0
var torso_turn:=0.0
var hand_error:=0.0
var hand_errors:Array[float]=[0.0,0.0]
func configure(actor:Node3D,model:Node3D) -> void:
 skeleton=model.find_children("*","Skeleton3D",true,false)[0]
 mesh=model.find_children("*","MeshInstance3D",true,false)[0]
 assert(binding.configure(skeleton,PROFILE),str(binding.errors))
 frame=Transform3D.IDENTITY
 var ancestor:Node3D=skeleton
 while ancestor!=actor:
  frame=ancestor.transform*frame;ancestor=ancestor.get_parent()
 inverse_frame=frame.affine_inverse()
 # Keep the full action envelope visible when limbs leave the T-pose bounds.
 mesh.custom_aabb=inverse_frame*AABB(Vector3(-35,-15,-45),Vector3(70,105,90))
 parents.assign(binding.parents)
 for i in skeleton.get_bone_count():
  rest.append(frame*binding.globals[i]);inverse_rest.append(rest[i].affine_inverse());posed.append(rest[i]);local_globals.append(binding.globals[i])
 head=binding.bone(&"head");neck=binding.bone(&"neck")
 for name in ["Hips","Spine","Spine1","Spine2","Neck","Head"]:driven[binding.names["smartrig_"+name]]=true
 for side in 2:
  var label:="Right" if side==0 else "Left"
  knee_shapes.append(mesh.find_blend_shape_by_name("KneeFold"+label))
  assert(knee_shapes[-1]>=0,"Native skin requires its posterior knee corrective")
  var arm:Array[int]=[];var leg:Array[int]=[]
  for part in ["Shoulder","Arm","ForeArm","Hand"]:arm.append(binding.names["smartrig_"+label+part])
  for part in ["UpLeg","Leg","Foot"]:leg.append(binding.names["smartrig_"+label+part])
  var y:=rest[arm[2]].origin.direction_to(rest[arm[1]].origin)
  var z:=Vector3.DOWN;var x:=y.cross(z).normalized();z=x.cross(y).normalized()
  var knuckle:int=binding.names["smartrig_"+label+"HandMiddle1"]
  arms.append({"ids":arm,"a":rest[arm[1]].origin.distance_to(rest[arm[2]].origin),"b":rest[arm[2]].origin.distance_to(rest[arm[3]].origin),"palm":Basis(x,y,z).inverse(),"contact":(rest[knuckle].origin-rest[arm[3]].origin)*.5})
  legs.append({"ids":leg,"a":rest[leg[0]].origin.distance_to(rest[leg[1]].origin),"b":rest[leg[1]].origin.distance_to(rest[leg[2]].origin)})
  for id in arm+leg:driven[id]=true
  var arm_axes:Array[Basis]=[];var leg_axes:Array[Basis]=[]
  var arm_normal:=Vector3.UP*(1 if side==0 else -1)
  var leg_chain:Dictionary={"root":rest[leg[0]].origin,"joint":rest[leg[1]].origin,"end":rest[leg[2]].origin}
  for segment in 2:
   arm_axes.append(Frames.frame(rest[arm[segment+2]].origin-rest[arm[segment+1]].origin,arm_normal).inverse()*rest[arm[segment+1]].basis)
   leg_axes.append(Frames.segment_frame(leg_chain,segment).inverse()*rest[leg[segment]].basis)
  arms[side].axes=arm_axes;legs[side].axes=leg_axes
 for name in ["Spine","Spine1","Spine2"]:spine.append(binding.names["smartrig_"+name])
 grip.configure(self)
 for i in rest.size():
  spine_segments.append(spine.find(i))
  var label:String=skeleton.get_bone_name(i)
  var finger:bool="Hand" in label and ("Thumb" in label or "Index" in label or "Middle" in label or "Ring" in label or "Pinky" in label)
  finger_sides.append((0 if "Right" in label else 1) if finger else -1)
  var axis:Vector3=rest[i].basis.inverse()*(rest[i].basis.y.normalized().cross(Vector3.DOWN)).normalized() if finger else Vector3.ZERO
  finger_axes.append(axis.normalized() if axis.length_squared()>.00001 else Vector3.ZERO)
  finger_angles.append(.45 if "Thumb" in label else .8)
 writer.configure(parents)
 source_mesh=mesh.mesh
 mesh.mesh=preload("res://scripts/animation/characters/hip_skin.gd").stable_mesh(source_mesh,mesh.skin,frame,binding.names["smartrig_Hips"])
 ground.configure(mesh.mesh,rest,GROUND,mesh.skin)
func aim(bone:int,child:int,a:Vector3,b:Vector3) -> void:
 var rotation:=Basis(Quaternion(rest[bone].origin.direction_to(rest[child].origin),a.direction_to(b)))
 posed[bone]=Transform3D(rotation*rest[bone].basis,a)
func orient_chain(ids:Array[int],offset:int,chain:Dictionary,axes:Array) -> void:
 for segment in 2:
  posed[ids[offset+segment]]=Transform3D(Frames.segment_frame(chain,segment)*axes[segment],chain.root if segment==0 else chain.joint)
func untwisted_chain(ids:Array[int],offset:int,chain:Dictionary,reference:Basis) -> void:
 # Swing each native bone from its bind axis without importing the contact
 # rig's axial roll into the trouser fabric or the relaxed upper arm.
 for segment in 2:
  var bone:int=ids[offset+segment];var child:int=ids[offset+segment+1]
  var a:Vector3=chain.root if segment==0 else chain.joint
  var b:Vector3=chain.joint if segment==0 else chain.end
  var from:Vector3=reference*(rest[child].origin-rest[bone].origin).normalized()
  var swing:=Basis(Quaternion(from,a.direction_to(b)))
  posed[bone]=Transform3D(swing*reference*rest[bone].basis,a)

func spread_knee(chain:Dictionary,pelvis:Transform3D,weight:float,spread:float=Clips.Gait.WALK_KNEE_SPREAD) -> Dictionary:
 if weight<=0:return chain
 var axis:Vector3=(chain.end-chain.root).normalized()
 var bend:Vector3=chain.joint-chain.root
 var centre:Vector3=chain.root+axis*bend.dot(axis)
 var radial:Vector3=chain.joint-centre
 var lateral:Vector3=pelvis.basis.x.normalized()
 var projection:Vector3=lateral-axis*lateral.dot(axis)
 var freedom:=projection.length()
 var radius:=radial.length()
 if freedom<.0001 or radius<.0001:return chain
 var u:=projection/freedom;var v:=axis.cross(u).normalized()
 var origin:float=(pelvis*Vector3(0,Clips.Anatomy.HIP.y,0)).dot(lateral)
 var target:float=origin+(chain.joint.dot(lateral)-origin)*lerpf(1,spread,weight)
 var x:=clampf((target-centre.dot(lateral))/freedom,-radius,radius)
 var y:=sqrt(maxf(0,radius*radius-x*x))*(-1 if radial.dot(v)<0 else 1)
 chain.joint=centre+u*x+v*y
 return chain

static func diagonal_turn(direction:Vector3) -> float:
 var travel:=Vector3(direction.x,0,direction.z).normalized()
 if travel.is_zero_approx():return 0.0
 # Backpedalling uses the same frontal body orientation as forward travel in
 # the opposite diagonal; never ask the spine to turn through 135 degrees.
 var forward:=travel if travel.z>=0 else -travel
 var angle:=clampf(atan2(forward.x,forward.z),-Clips.Gait.DIAGONAL_ANGLE,Clips.Gait.DIAGONAL_ANGLE)
 var diagonal:=smoothstep(0,.35,absf(travel.x))*smoothstep(0,.35,absf(travel.z))
 return angle/Clips.Gait.DIAGONAL_ANGLE*Clips.Gait.DIAGONAL_TORSO_TURN*diagonal

func sync(control:RefCounted,pose:Dictionary,delta:float=0.0) -> void:
 var body:Transform3D=pose.body
 var clip:StringName=pose.get("clip_state",&"")
 var family:StringName=pose.get("family",&"")
 var gait:bool=clip in [&"walk",&"run",&"start",&"stop",&"start_run",&"stop_run",&"crouch_walk",&"equip_walk",&"equip_run",&"equip_crouch_walk",&"pickup_walk",&"eat_walk",&"drink_walk"]
 var walking:bool=clip in [&"walk",&"run",&"equip_walk",&"equip_run",&"eat_walk",&"drink_walk",&"start",&"stop",&"start_run",&"stop_run"]
 var running_posture:bool=clip in [&"run",&"equip_run",&"start_run",&"stop_run"]
 var sprint:float=pose.get("run_weight",1.0 if running_posture else 0.0)
 var target_posture:float=pose.get("gait_weight",1.0)*(1-sprint) if walking else 0.0
 var target_run:float=pose.get("gait_weight",1.0)*sprint if running_posture else 0.0
 var posture_response:=1-exp(-delta*18) if delta>0 else 1.0
 walk_posture=lerpf(walk_posture,target_posture,posture_response) if delta>0 else target_posture
 run_posture=lerpf(run_posture,target_run,posture_response) if delta>0 else target_run
 var lean:float=Clips.Gait.WALK_LEAN*walk_posture
 var running_lean:float=Clips.Gait.RUN_LEAN*run_posture
 var running_curve:float=Clips.Gait.RUN_BACK_CURVE*run_posture
 var turning:bool=clip in [&"walk",&"run",&"start",&"stop",&"start_run",&"stop_run",&"crouch_walk",&"equip_walk",&"equip_run",&"equip_crouch_walk"]
 var turn_target:float=diagonal_turn(pose.get("torso_travel",Vector3.ZERO))*pose.get("gait_weight",1.0) if turning else 0.0
 if delta>0:
  var eased:=lerpf(torso_turn,turn_target,1-exp(-delta*Clips.Gait.DIAGONAL_TORSO_RESPONSE))
  torso_turn=move_toward(torso_turn,eased,Clips.Gait.DIAGONAL_TORSO_SPEED*delta)
 else:torso_turn=turn_target
 var pelvis:Transform3D=pose.get("pelvis",body)
 if clip in [&"pickup",&"pickup_walk"]:
  var lower:float=Clips.pickup_weight(pose.phase)
  body.origin.y-=lower;pelvis.origin.y-=lower
 var head_rotation:Basis=control.posed[3].basis.orthonormalized()
 var chest_rotation:Basis=body.basis
 var shoulder_motion:=Vector3.ZERO
 if gait:
  var cycle:float=pose.get("gait_phase",0.0)
  var state:StringName=&"run" if clip in [&"run",&"start_run",&"stop_run",&"equip_run"] else &"walk"
  var keys:=Clips.Controls.sample(state,cycle)
  if running_posture:
   var walking_keys:=Clips.Controls.sample(&"walk",cycle)
   for key in [&"spine",&"chest",&"shoulders"]:keys[key]=(walking_keys[key] as Vector3).lerp(keys[key],sprint)
  head_rotation=Basis(Vector3.UP,Clips.Gait.head_twist(keys.chest.y,sprint if running_posture else 0.0)*pose.get("gait_weight",1.0))*head_rotation
  var angles:=chest_rotation.get_euler()
  angles.y=pelvis.basis.get_euler().y+keys.spine.y*pose.get("gait_weight",1.0)
  chest_rotation=Basis.from_euler(angles)
  shoulder_motion=keys.shoulders*pose.get("gait_weight",1.0)
 for i in posed.size():
  var rotation:=pelvis.basis if parents[i]<0 else chest_rotation
  var segment:int=spine_segments[i]
  if segment>=0:rotation=pelvis.basis.slerp(chest_rotation,SPINE_TWIST_SHARES[segment])
  if i==neck:rotation=chest_rotation.slerp(head_rotation,.35)
  if i==head:rotation=head_rotation
  var lean_share:float=Clips.Gait.WALK_SPINE_LEAN[segment] if segment>=0 else (1.0 if i in [neck,head] else .80)
  if parents[i]>=0:
   var run_share:float=Clips.Gait.RUN_SPINE_LEAN[segment] if segment>=0 else (1.0 if i in [neck,head] else Clips.Gait.RUN_SPINE_LEAN[2])
   var curve_share:float=Clips.Gait.RUN_BACK_CURVE_SHARES[segment] if segment>=0 else 1.0
   rotation=Basis(pelvis.basis.x.normalized(),lean*lean_share+running_lean*run_share+running_curve*curve_share)*rotation
   var turn_share:float=SPINE_TWIST_SHARES[segment] if segment>=0 else (.65 if i==neck else (0.0 if i==head else 1.0))
   rotation=Basis(pelvis.basis.y.normalized(),torso_turn*turn_share)*rotation
  var origin:Vector3=pelvis*rest[i].origin if parents[i]<0 else posed[parents[i]]*(inverse_rest[parents[i]]*rest[i].origin)
  posed[i]=Transform3D(rotation*rest[i].basis,origin)
 body=posed[spine[2]]*inverse_rest[spine[2]]
 hand_error=0
 for side in 2:
  var chain:Dictionary=arms[side];var ids:Array[int]=chain.ids
  var source:int=4+side*3
  var goal:Vector3=control.posed[source+2].origin
  var palm_basis:Basis=control.posed[source+2].basis.orthonormalized()
  var pickup:bool=side==1 and clip in [&"pickup",&"pickup_walk"]
  if pickup:palm_basis=palm_basis.rotated(body.basis.x,-.4*Clips.pickup_weight(pose.phase))
  var balancing:bool=family==&"sword" and clip==&"action" and side!=pose.active
  var free:bool=balancing or Clips.arm_is_free(pose,side) and clip not in [&"action",&"death"] and not (side==1 and clip in [&"pickup",&"pickup_walk"])
  if not free and family in [&"axe",&"pickaxe",&"sword"] and clip!=&"death":
   var closed:Basis=grip.palm(pose.family,side,pose.get("tool_basis",Basis.IDENTITY),palm_basis)
   var amount:float=pose.get("equipment_weight",1.0)*(pose.get("support_weight",1.0) if side!=pose.active else 1.0)
   palm_basis=palm_basis.slerp(closed,clampf(amount,0,1))
  if free:
   goal=body*rest[ids[1]].origin+(goal-control.posed[source].origin)*((chain.a+chain.b)/19.0)
   if clip in [&"pickup",&"pickup_walk"]:goal.y+=Clips.pickup_weight(pose.phase)
  elif pickup or clip==&"action" or (family!=&"" and clip!=&"death"):
   var contact:Vector3=chain.contact*grip.HAND_SCALE*(2.0 if family==&"" and clip==&"action" else 1.0)
   goal-=palm_basis*chain.palm*contact
  var core:Vector3=posed[ids[0]].origin
  var offset:Vector3=body.basis*(rest[ids[1]].origin-rest[ids[0]].origin)
  var relaxed_offset:=offset
  if gait:offset=offset.rotated(body.basis.z,(-1 if side==1 else 1)*deg_to_rad(2)*shoulder_motion[side])
  var shoulder:Vector3=core+offset
  if free:goal+=offset-relaxed_offset
  # Clavicular protraction accommodates held contacts while respecting the
  # original clavicle and arm lengths. Free arms use native proportions.
  if shoulder.distance_to(goal)>chain.a+chain.b-.04:
   var desired:Vector3=(goal-core).normalized()*offset.length()
   var max_angle:=minf(offset.angle_to(desired),deg_to_rad(60))
   var axis:=offset.cross(desired).normalized()
   if axis.length_squared()>.1:
    for step in range(1,17):
     shoulder=core+offset.rotated(axis,max_angle*step/16.0)
     if shoulder.distance_to(goal)<chain.a+chain.b-.04:break
  aim(ids[0],ids[1],core,shoulder)
  var pole:Vector3=control.posed[source+1].origin-control.posed[source].origin
  var solved:=Solver.joint(shoulder,goal,chain.a,chain.b,pole)
  if balancing:untwisted_chain(ids,1,solved,body.basis)
  else:orient_chain(ids,1,solved,chain.axes)
  # Scale once at the wrist; native finger descendants inherit the same
  # proportion. Original skin weights blend the wrist into the forearm.
  posed[ids[3]]=Transform3D(palm_basis*chain.palm*rest[ids[3]].basis*grip.HAND_SCALE,solved.end)
  hand_errors[side]=solved.end.distance_to(goal)
  if not free:hand_error=maxf(hand_error,hand_errors[side])
  chain=legs[side];ids=chain.ids;source=10+side*3
  var hip:Vector3=pelvis*rest[ids[0]].origin
  var foot_rotation:Basis=control.posed[source+2].basis.orthonormalized()
  var foot_offset:Vector3=rest[ids[2]].origin-control.rest[source+2].origin
  var running:bool=clip in [&"run",&"start_run",&"stop_run",&"equip_run"]
  var foot:Vector3=control.posed[source+2].origin+foot_rotation*foot_offset
  var grounded_walk:bool=walking and not running
  # Centre upright locomotion under the native hip. The posture weights
  # also fade this bind correction when stopping, crouching or jumping.
  var aligned_foot:Vector3=control.posed[source+2].origin+pelvis.basis*Vector3(foot_offset.x,foot_offset.y,rest[ids[0]].origin.z-control.rest[source].origin.z)+Vector3.UP*.30
  foot=foot.lerp(aligned_foot,clampf(walk_posture+run_posture,0,1))
  pole=control.posed[source+1].origin-control.posed[source].origin
  if Clips.upright_gait(pose):foot=Clips.grounded_reach(hip,foot,chain.a,chain.b,.12 if running or grounded_walk else .35)
  solved=Solver.joint(hip,foot,chain.a,chain.b,pole)
  var posture_weight:=clampf(walk_posture+run_posture,0,1)
  var knee_spread:float=lerpf(Clips.Gait.WALK_KNEE_SPREAD,Clips.Gait.RUN_KNEE_SPREAD,run_posture/maxf(walk_posture+run_posture,.000001))
  solved=spread_knee(solved,pelvis,posture_weight,knee_spread)
  if gait:untwisted_chain(ids,0,solved,pelvis.basis)
  else:orient_chain(ids,0,solved,chain.axes)
  posed[ids[2]]=Transform3D(foot_rotation*rest[ids[2]].basis,solved.end)
  var upper:Vector3=solved.joint-solved.root;var lower_leg:Vector3=solved.end-solved.joint
  # Continuous anatomical response, shared by every action and direction.
  var cosine:float=clampf(upper.normalized().dot(lower_leg.normalized()),-1,1)
  # At deep kneeling flexion the calf already meets the thigh; taper the
  # support instead of pushing that contact into the floor.
  var fold:float=.5*(1-cosine)*(1-smoothstep(deg_to_rad(115),deg_to_rad(145),acos(cosine)))
  mesh.set_blend_shape_value(knee_shapes[side],fold)
 # Native fingers, toes and end bones inherit their actual native parents.
 var relaxed_pose:bool=clip in grip.RELAXED_STATES
 var relaxed_right:bool=relaxed_pose and Clips.arm_is_free(pose,0)
 var relaxed_left:bool=relaxed_pose and Clips.arm_is_free(pose,1)
 for i in posed.size():
  if driven.has(i):continue
  posed[i]=posed[parents[i]]*inverse_rest[parents[i]]*rest[i]
  var side:int=finger_sides[i]
  if side>=0:
   var grip:float=.08
   if (side==0 and relaxed_right) or (side==1 and relaxed_left):
    posed[i].basis=posed[i].basis*self.grip.relaxed[i]
    continue
   if family!=&"" and clip!=&"death" and not Clips.arm_is_free(pose,side):grip=.8
   elif clip in [&"pickup",&"pickup_walk"]:grip=.08+.65*Clips.pickup_weight(pose.phase)
   elif clip==&"action" and not (family==&"sword" and side!=pose.active):grip=sin(clampf(pose.phase,0,1)*PI)
   var axis:Vector3=finger_axes[i]
   if axis.length_squared()>.00001:posed[i].basis=posed[i].basis*Basis(axis,grip*finger_angles[i])
 grip.apply(self,control,pose)
 if ground_enabled and clip==&"death":
  var lift:float=ground.correction(posed)*smoothstep(0,.025,pose.phase)
  for i in posed.size():posed[i].origin.y+=lift
 for i in posed.size():local_globals[i]=inverse_frame*posed[i]
 writer.apply(skeleton,local_globals)
