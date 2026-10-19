extends RefCounted
## Stable skinned mesh. Poses move bones; topology and surface detail never change.
const ANIMATION_PROFILE=preload("res://data/animation/characters/survivor.tres")
var anatomy=preload("res://scripts/animation/shared/rig_binding.gd").new()
const Pose = preload("res://scripts/continuous_body_pose.gd")
const Anatomy = preload("res://scripts/prototype_3d/survivor_anatomy.gd")
const Kinematics=preload("res://scripts/prototype_3d/human_kinematics.gd")
const Clips = preload("res://scripts/prototype_3d/survivor_animation.gd")
var skeleton := Skeleton3D.new()
var rest: Array[Transform3D] = []
var posed: Array[Transform3D] = []
var parents: Array[int] = []
var pose_writer=preload("res://scripts/prototype_3d/skeleton_pose.gd").new()
var limb_frames:Array[Basis]=[]
var collar_frames:Array[Basis]=[]
var names: Dictionary = {}
var neutral: Dictionary
var arm_rest: Array[Dictionary] = []
var cloth_angle: Array[float] = [0.0,0.0]
var cloth_velocity: Array[float] = [0.0,0.0]
var previous_leg_angle: Array[float] = [0.0,0.0]
var run_arm_blend:Array[float]=[0.0,0.0]
var relaxed_arm_blend:Array[float]=[0.0,0.0]
var last_run_weight:=0.0

func initialize_imported(actor:Node3D,mesh_instance:MeshInstance3D) -> void:
 setup(actor,mesh_instance)
 mesh_instance.custom_aabb=AABB(Vector3(-35,-15,-45),Vector3(70,105,90))

func setup(actor:Node3D,mesh_instance:MeshInstance3D) -> void:
 neutral = Anatomy.bind_pose()
 bone("pelvis",-1,Vector3(0,Anatomy.HIP.y,0))
 bone("chest",0,Vector3(0,43,0))
 bone("neck",1,Anatomy.HEAD_ANCHOR)
 bone("head",2,Vector3(0,57.5,0))
 for side in 2:
  var arm:Dictionary = neutral.arms[side]
  neutral.hands[side]=arm.end
  arm_rest.append(arm)
  var start := rest.size()
  bone("upper_arm_%d"%side,1,arm.root)
  bone("forearm_%d"%side,start,arm.joint)
  bone("hand_%d"%side,start+1,arm.end,Kinematics.hand_frame(arm,Basis.IDENTITY,side))
 for side in 2:
  var leg: Dictionary = neutral.legs[side]
  var start := rest.size()
  bone("thigh_%d"%side,0,leg.root)
  bone("shin_%d"%side,start,leg.joint)
  bone("foot_%d"%side,start+1,leg.end)
 for side in 2:
  for panel in 2:
   bone("cloth_hem_%d_%d"%[side,panel],10+side*3,neutral.legs[side].root.lerp(neutral.legs[side].joint,0.3))
 # One volume-preserving hinge collar per elbow/knee, appended after stable IDs.
 for side in 2:
  bone("elbow_volume_%d"%side,4+side*3,arm_rest[side].joint)
 for side in 2:
  bone("knee_volume_%d"%side,10+side*3,neutral.legs[side].joint)
 actor.add_child(skeleton)
 mesh_instance.reparent(skeleton)
 mesh_instance.skeleton = NodePath("..")
 var skin := Skin.new()
 for i in rest.size(): skin.add_bind(i,rest[i].affine_inverse())
 mesh_instance.skin = skin
 if not anatomy.configure(skeleton,ANIMATION_PROFILE):push_error(str(anatomy.errors))
 pose_writer.configure(parents);limb_frames.resize(rest.size());collar_frames.resize(rest.size())
 for side in 2:
  cache_limb(4+side*3,20+side,arm_rest[side])
  cache_limb(10+side*3,22+side,neutral.legs[side])

func bone(label: String, parent: int, position: Vector3,basis:Basis=Basis.IDENTITY) -> void:
 var index := skeleton.get_bone_count(); skeleton.add_bone(label)
 names[label] = index; parents.append(parent)
 var transform := Transform3D(basis,position)
 rest.append(transform); posed.append(transform)
 if parent >= 0: skeleton.set_bone_parent(index,parent)
 var local := rest[parent].affine_inverse()*transform if parent >= 0 else transform
 skeleton.set_bone_rest(index,local); skeleton.set_bone_pose(index,local)

func cache_limb(start:int,collar:int,chain:Dictionary) -> void:
 for segment in 2:limb_frames[start+segment]=Kinematics.segment_frame(chain,segment).inverse()
 var axis:Vector3=(chain.joint-chain.root).normalized()+(chain.end-chain.joint).normalized()
 collar_frames[collar]=Kinematics.frame(axis,Kinematics.plane(chain)).inverse()

func orient_limb(start:int,chain:Dictionary) -> void:
 # A shortest-arc quaternion alone loses the hinge plane and flips limb roll.
 for segment in 2:
  var rotation:=Kinematics.segment_frame(chain,segment)*limb_frames[start+segment]
  posed[start+segment]=Transform3D(rotation,chain.root if segment==0 else chain.joint)

func hinge_collar(index:int,chain:Dictionary) -> void:
 var current:Vector3=(chain.joint-chain.root).normalized()+(chain.end-chain.joint).normalized()
 var rotation:=Kinematics.frame(current,Kinematics.plane(chain))*collar_frames[index]
 posed[index]=Transform3D(rotation,chain.joint)

func apply(pose: Dictionary,hands: Array[Vector3],delta: float = 0.0) -> void:
 var torso: Transform3D = pose.body
 # Idle/walk do not carry a sprint weight. Retain the last explicit weight
 # while the arm blend fades instead of restoring a full running pose.
 if pose.has("run_weight"):last_run_weight=clampf(pose.run_weight,0,1)
 elif pose.get("clip_state",&"") in [&"run",&"start_run",&"equip_run"]:last_run_weight=1.0
 elif delta<=0:last_run_weight=0.0
 for i in 3: posed[i] = Transform3D(torso.basis,torso*rest[i].origin)
 var pelvis:Transform3D=pose.get("pelvis",torso)
 posed[0]=Transform3D(pelvis.basis,pelvis*rest[0].origin)
 # The skull stays attached to the neck, with only a small counter-rotation.
 var skull_basis := torso.basis if pose.state==&"death" else Basis.IDENTITY.slerp(torso.basis,0.2)
 var neck: Vector3 = torso*Anatomy.HEAD_ANCHOR
 if pose.get("clip_state",&"") in [&"pickup",&"pickup_walk"] and pose.get("look_contact",Vector3.INF).is_finite():
  var direction:Vector3=neck.direction_to(pose.look_contact)
  var pitch:=clampf(atan2(-direction.y,maxf(0.1,direction.z)),0,0.95)
  var weight:float=Clips.pickup_weight(pose.phase)
  skull_basis=skull_basis.slerp(Basis(Vector3.RIGHT,pitch),weight)
 skull_basis=pose.get("head_basis",skull_basis)
 posed[3] = Transform3D(skull_basis,neck+skull_basis*(rest[3].origin-Anatomy.HEAD_ANCHOR))
 for side in 2:
  var clip:StringName=pose.get("clip_state",&"idle")
  var swinging:=Clips.arm_is_free(pose,side) and clip in [&"idle",&"walk",&"run",&"start",&"stop",&"start_run",&"stop_run",&"crouch",&"crouch_walk",&"slide",&"equip",&"unequip",&"equip_walk",&"equip_run",&"equip_crouch",&"equip_crouch_walk"]
  var draw_amount:=0.0
  if pose.get("family",&"")==&"bow" and side!=pose.active:
   if clip in [&"draw",&"action"]:draw_amount=smoothstep(.12,.7,pose.phase)
   elif clip==&"bow_release":draw_amount=1-smoothstep(.45,1,pose.phase)
  var held:=0.0
  var family:StringName=pose.get("family",&"")
  if clip!=&"death" and family in [&"axe",&"pickaxe",&"sword",&"bow"] and (side==pose.active or Clips.Profiles.profile(family).two_hands):
   held=pose.get("equipment_weight",1.0)
  var arm := Kinematics.arm(pose.shoulders[side],hands[side],torso.basis,side,swinging,draw_amount,held)
  var walking:Dictionary=Clips.walking_arm(pose,side,pose.get("gait_phase",0.0))
  if not walking.is_empty():arm=walking
  if family==&"sword" and clip==&"action" and side==pose.active:
   arm=Pose.joint(arm.root,arm.end,Pose.UPPER_ARM,Pose.FOREARM,arm.joint-arm.root-torso.basis.y*2.0)
  if pose.has("arm_poles"):arm=Pose.joint(arm.root,arm.end,Pose.UPPER_ARM,Pose.FOREARM,pose.arm_poles[side])
  if pose.has("equipment_poles"):
   var axis:Vector3=(arm.end-arm.root).normalized()
   var previous_axis:Vector3=pose.equipment_axes[side]
   var previous_pole:Vector3=pose.equipment_poles[side]
   var pole:=Kinematics.transport_pole(previous_axis,previous_pole,axis,arm.joint-arm.root,pose.equipment_weight)
   arm=Pose.joint(arm.root,arm.end,Pose.UPPER_ARM,Pose.FOREARM,pole)
  var relaxed:Dictionary=Clips.relaxed_arm(pose,side)
  var resting:=clip==&"idle"
  if relaxed.is_empty() or clip not in [&"idle",&"walk",&"run",&"start",&"stop",&"start_run",&"stop_run"]:relaxed_arm_blend[side]=0
  elif delta<=0:relaxed_arm_blend[side]=1.0 if resting else 0.0
  else:relaxed_arm_blend[side]=move_toward(relaxed_arm_blend[side],1.0 if resting else 0.0,delta/0.14)
  if relaxed_arm_blend[side]>0:
   var blend:float=relaxed_arm_blend[side]
   var upper:Vector3=(arm.joint-arm.root).normalized().lerp((relaxed.joint-relaxed.root).normalized(),blend).normalized()
   var forearm:Vector3=(arm.end-arm.joint).normalized().lerp((relaxed.end-relaxed.joint).normalized(),blend).normalized()
   arm.joint=arm.root+upper*Pose.UPPER_ARM;arm.end=arm.joint+forearm*Pose.FOREARM
  var running:=clip in [&"run",&"start_run",&"equip_run"]
  var running_pose:Dictionary=Clips.running_arm(pose,side,pose.get("gait_phase",0.0))
  var allow_transition:=clip in [&"idle",&"walk",&"stop_run",&"stop"]
  if running_pose.is_empty() or (not running and not allow_transition):run_arm_blend[side]=0
  elif delta<=0:run_arm_blend[side]=1.0 if running else 0.0
  else:run_arm_blend[side]=move_toward(run_arm_blend[side],1.0 if running else 0.0,delta/(0.14 if running else 0.18))
  if run_arm_blend[side]>0:
   var amount:float=run_arm_blend[side]*last_run_weight
   var upper:Vector3=(arm.joint-arm.root).normalized().lerp((running_pose.joint-running_pose.root).normalized(),amount).normalized()
   var forearm:Vector3=(arm.end-arm.joint).normalized().lerp((running_pose.end-running_pose.joint).normalized(),amount).normalized()
   arm.joint=arm.root+upper*Pose.UPPER_ARM;arm.end=arm.joint+forearm*Pose.FOREARM
  var start := 4+side*3
  orient_limb(start,arm)
  hinge_collar(20+side,arm)
  var balancing:bool=pose.get("family",&"")==&"sword" and clip==&"action" and side!=pose.active
  var bare_action:bool=family==&"" and clip==&"action"
  var palm:=Kinematics.hand_frame(arm,torso.basis,side,not swinging and not balancing and not bare_action)
  if not walking.is_empty():palm=palm.rotated(torso.basis.x,walking.wrist*(1-run_arm_blend[side])*(1-relaxed_arm_blend[side]))
  if held>0 or pose.has("equipment_forearms"):
   var roll:=Kinematics.grip_roll(arm,torso.basis,side,pose.shaft)*held
   palm=palm.rotated(palm.y,roll)
   var forearm_axis:Vector3=(arm.joint-arm.end).normalized()
   var forearm_roll:=roll
   if pose.has("equipment_forearms"):
    var current:=posed[start+1].basis.x
    var saved:Vector3=pose.equipment_forearms[side].x
    current=(current-forearm_axis*current.dot(forearm_axis)).normalized()
    saved=(saved-forearm_axis*saved.dot(forearm_axis)).normalized()
    forearm_roll=lerpf(current.signed_angle_to(saved,forearm_axis),roll,pose.equipment_weight)
   posed[start+1].basis=posed[start+1].basis.rotated(forearm_axis,forearm_roll)
  if pose.has("equipment_palms"):palm=(pose.equipment_palms[side] as Basis).slerp(palm,pose.equipment_weight)
  posed[start+2] = Transform3D(palm,arm.end)
  if clip in [&"pickup",&"pickup_walk"] and side==1:
   # Turn the fingers toward a low object while the wrist stays exactly on
   # the selected contact. Following the forearm alone drives fingertips down.
   var low:=1-smoothstep(5,20,pose.get("look_contact",Vector3(0,20,0)).y)
   posed[start+2].basis=posed[start+2].basis.rotated(torso.basis.x,-.60*Clips.pickup_weight(pose.phase)*low)
  if pose.get("family",&"")==&"" and pose.get("clip_state")==&"action":
   var close_fist:=sin(clampf(float(pose.phase),0,1)*PI)
   posed[start+2].basis=posed[start+2].basis*Basis.from_scale(Vector3(1+0.1*close_fist,1-0.12*close_fist,1+0.1*close_fist))
  var leg: Dictionary = pose.legs[side]; start = 10+side*3
  orient_limb(start,leg)
  hinge_collar(22+side,leg)
  posed[start+2] = Transform3D(pose.foot_bases[side] if pose.has("foot_bases") else pose.get("leg_frame",Basis.IDENTITY)*Basis(Vector3.RIGHT,leg.pitch),leg.end)
  var leg_angle := atan2((leg.joint-leg.root).z,-(leg.joint-leg.root).y)
  if delta>0:
   var d:=minf(delta,0.033)
   var angular_speed:=wrapf(leg_angle-previous_leg_angle[side],-PI,PI)/maxf(delta,0.001)
   cloth_velocity[side]+=(-cloth_angle[side]*80-cloth_velocity[side]*15-angular_speed*0.7)*d
   cloth_angle[side]=clampf(cloth_angle[side]+cloth_velocity[side]*d,-0.09,0.09)
  else: cloth_angle[side]=0;cloth_velocity[side]=0
  previous_leg_angle[side]=leg_angle
  var cloth_display:=cloth_angle[side]
  if clip==&"death":
   cloth_display*=1-smoothstep(.8,1,pose.phase)
   if pose.phase>=1:cloth_angle[side]=0;cloth_velocity[side]=0
  for panel in 2:
   var index:=16+side*2+panel
   var origin: Vector3=leg.root+posed[10+side*3].basis*(rest[index].origin-rest[10+side*3].origin)
   posed[index]=Transform3D(posed[10+side*3].basis*Basis(Vector3.RIGHT,cloth_display*(1 if panel==0 else 0.7)),origin)
 pose_writer.apply(skeleton,posed)
