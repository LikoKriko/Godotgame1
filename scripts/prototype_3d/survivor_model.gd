extends Node3D
## Original Meshy survivor supplied by the user; shared mesh, independent rig.
const IMPORTED_SKIN=preload("res://assets/characters/prototype_3d/meshy/survivor_skin.res")
const AXILLA_SKIN=preload("res://assets/characters/prototype_3d/meshy/survivor_axilla.res")
const Pose=preload("res://scripts/continuous_body_pose.gd")
const Clips=preload("res://scripts/prototype_3d/survivor_animation.gd")
const Anatomy=preload("res://scripts/prototype_3d/survivor_anatomy.gd")
const Aim=preload("res://scripts/prototype_3d/tool_aim.gd")
const Profiles=preload("res://scripts/prototype_3d/held_profiles.gd")
const GRIP_HEIGHT:=4.0
var ground=preload("res://scripts/animation/characters/skin_ground.gd").new()
var ground_enabled:=true
var mesh_node:MeshInstance3D
var body_material:Material
var last_pose:Dictionary={}
var grip_error:=0.0
var tool_tip:=Vector3.ZERO
var tool_cutting_axis:=Vector3.ZERO
var axe: Node3D
var rig = preload("res://scripts/prototype_3d/humanoid_rig.gd").new()
var displayed_pose: Dictionary = {}
var gait_active:=false
var gait_entry_age:=0.0
var gait_entry_offsets:Array[Vector3]=[Vector3.ZERO,Vector3.ZERO]
var gait_direction=preload("res://scripts/prototype_3d/gait_direction.gd").new()
var slide_launch_pose:Dictionary={}
var equipment_from:Dictionary={}
var death_from:Dictionary={}
var family_override: StringName = &"default"
var aim_contact := Vector3.INF
var action_crouch:=0.0
var punch_side:=1
var sprint_weight:float=-1.0
var sprint_crouch:=0.0
var tool_frame := Basis.IDENTITY
var grip_socket := Node3D.new()
var support_socket := Node3D.new()
var tip_socket := Node3D.new()
var parry_pulse: Node3D
var held_props:Dictionary={}
var displayed_item:StringName=&"axe"
var item_water_ml:=0
var nock_visible:=false
var leaf_armor:Node3D
func begin_equipment_transition() -> void:
 if displayed_pose.is_empty():equipment_from.clear();return
 equipment_from={"body":displayed_pose.body,"pelvis":displayed_pose.get("pelvis",displayed_pose.body),"hands":[rig.posed[6].origin,rig.posed[9].origin],"poles":[rig.posed[5].origin-rig.posed[4].origin,rig.posed[8].origin-rig.posed[7].origin],"palms":[rig.posed[6].basis.orthonormalized(),rig.posed[9].basis.orthonormalized()],"forearms":[rig.posed[5].basis.orthonormalized(),rig.posed[8].basis.orthonormalized()],"axes":[rig.posed[4].origin.direction_to(rig.posed[6].origin),rig.posed[7].origin.direction_to(rig.posed[9].origin)]}
func _ready() -> void:
 mesh_node=MeshInstance3D.new();add_child(mesh_node)
 mesh_node.mesh=AXILLA_SKIN
 body_material=AXILLA_SKIN.surface_get_material(0)
 rig.initialize_imported(self,mesh_node)
 ground.configure(AXILLA_SKIN,rig.rest)
 axe = preload("res://scripts/prototype_3d/stone_axe.gd").new(); add_child(axe)
 for socket in [grip_socket,support_socket,tip_socket]: add_child(socket)
 grip_socket.name="ObjectGrip";support_socket.name="SupportHand";tip_socket.name="ObjectTip"
 for family in [&"pickaxe",&"sword",&"bow",&"bottle",&"food"]:
  var prop:=preload("res://scripts/prototype_3d/held_prop.gd").new();grip_socket.add_child(prop);prop.configure(family);prop.hide();held_props[family]=prop
 leaf_armor=preload("res://scripts/prototype_3d/leaf_armor.gd").new();add_child(leaf_armor);leaf_armor.bind(rig);leaf_armor.hide()
 parry_pulse=preload("res://scripts/prototype_3d/parry_pulse.gd").new();add_child(parry_pulse)
func place_tool(_data: Dictionary, grip: Vector3, shaft: Vector3, actor_basis: Basis, _item: StringName) -> Dictionary:
 var y_axis := (actor_basis*shaft).normalized()
 var x_axis := actor_basis*tool_frame.x
 x_axis = (x_axis-y_axis*y_axis.dot(x_axis)).normalized()
 var z_axis := x_axis.cross(y_axis).normalized()
 axe.basis = Basis(x_axis,y_axis,z_axis)
 axe.position = actor_basis*grip-y_axis*GRIP_HEIGHT
 tool_tip = actor_basis*grip+axe.basis*Profiles.profile(_item).tip
 tool_cutting_axis = x_axis
 return {"grip":grip,"support":grip+shaft*Profiles.profile(_item).support}
func animate(state: StringName, phase: float, equipped: bool, delta: float = 0.0, movement_phase: float = 0.0, movement: Vector3 = Vector3.ZERO, motion_amount:float=1.0) -> void:
 if state in [&"walk",&"run",&"start_run",&"stop_run",&"crouch_walk",&"equip_walk",&"equip_run",&"equip_crouch_walk",&"pickup_walk",&"eat_walk",&"drink_walk",&"unequip"]:
  movement=gait_direction.sample(movement,delta)
 else:gait_direction.reset()
 var item: StringName = (&"axe" if equipped else &"") if family_override==&"default" else family_override
 var equipping:=String(state).begins_with("equip") or state==&"unequip"
 if equipping and delta>0 and (equipment_from.is_empty() or displayed_pose.get("clip_state",&"")!=state or displayed_pose.get("family",&"")!=item or phase<float(displayed_pose.get("phase",0))):begin_equipment_transition()
 if state==&"death" and death_from.is_empty() and not displayed_pose.is_empty():
  begin_equipment_transition()
  death_from=equipment_from.duplicate(true)
  death_from.feet=[rig.posed[12].origin,rig.posed[15].origin]
  death_from.foot_bases=[rig.posed[12].basis,rig.posed[15].basis]
  death_from.leg_poles=[rig.posed[11].origin-rig.posed[10].origin,rig.posed[14].origin-rig.posed[13].origin]
  death_from.leg_axes=[rig.posed[10].origin.direction_to(rig.posed[12].origin),rig.posed[13].origin.direction_to(rig.posed[15].origin)]
  death_from.head=rig.posed[3].basis
  death_from.low_start=(death_from.pelvis*Vector3(0,Anatomy.HIP.y,0)).y<15.6
 if state!=&"death":death_from.clear()
 if not equipping:equipment_from.clear()
 var death_phase:=lerpf(.40,1,phase) if state==&"death" and death_from.get("low_start",false) and delta>0 else phase
 var target := Clips.sample(item,state,death_phase,movement_phase,movement,aim_contact,slide_launch_pose,action_crouch,punch_side)
 if state in [&"run",&"start_run",&"stop_run"] and sprint_weight>=0:
  var walking:=Clips.sample(item,&"walk",movement_phase,movement_phase,movement)
  if sprint_crouch>0:walking=Clips.mix_motion(walking,Clips.sample(item,&"crouch_walk",movement_phase,movement_phase,movement),sprint_crouch)
  var sprinting:=Clips.sample(item,&"run",movement_phase,movement_phase,movement)
  target=Clips.mix_motion(walking,sprinting,sprint_weight)
  target.clip_state=state;target.state=state;target.phase=phase;target.run_weight=sprint_weight
 if equipping and delta>0 and not equipment_from.is_empty():
  var entry:=smoothstep(0,.65,phase)
  target.body=(equipment_from.body as Transform3D).interpolate_with(target.body,entry)
  target.pelvis=(equipment_from.pelvis as Transform3D).interpolate_with(target.pelvis,entry)
  target.grip=(equipment_from.hands[target.active] as Vector3).lerp(target.grip,entry)
  for side in 2:target.hands[side]=(equipment_from.hands[side] as Vector3).lerp(target.hands[side],entry)
  if state!=&"unequip":target.equipment_poles=equipment_from.poles;target.equipment_palms=equipment_from.palms;target.equipment_forearms=equipment_from.forearms;target.equipment_axes=equipment_from.axes
 if state==&"death" and delta>0 and not death_from.is_empty():
  var entry:=smoothstep(0,.28,phase)
  target.body=(death_from.body as Transform3D).interpolate_with(target.body,entry)
  target.pelvis=(death_from.pelvis as Transform3D).interpolate_with(target.pelvis,entry)
  target.head_basis=(death_from.head as Basis).slerp(target.head_basis,entry)
  for side in 2:
   target.hands[side]=(death_from.hands[side] as Vector3).lerp(target.hands[side],entry)
   target.legs[side].end=(death_from.feet[side] as Vector3).lerp(target.legs[side].end,entry)
   target.foot_bases[side]=(death_from.foot_bases[side] as Basis).slerp(target.foot_bases[side],entry)
   var hip:Vector3=target.pelvis*Vector3((-1 if side==0 else 1)*Anatomy.HIP.x,Anatomy.HIP.y,0)
   target.leg_poles[side]=preload("res://scripts/prototype_3d/human_kinematics.gd").transport_pole(death_from.leg_axes[side],death_from.leg_poles[side],hip.direction_to(target.legs[side].end),target.leg_poles[side],entry)
  target.equipment_weight=entry
  target.equipment_poles=death_from.poles;target.equipment_palms=death_from.palms
  target.equipment_forearms=death_from.forearms;target.equipment_axes=death_from.axes
 if state in [&"walk",&"run",&"start_run",&"stop_run",&"crouch_walk"] and motion_amount<1:
  var neutral:=Clips.sample(item,&"crouch" if state==&"crouch_walk" or sprint_crouch>.01 else &"idle",sprint_crouch if sprint_crouch>.01 else (1.0 if state==&"crouch_walk" else 0.0))
  target.body=neutral.body.interpolate_with(target.body,motion_amount)
  target.pelvis=neutral.pelvis.interpolate_with(target.pelvis,motion_amount)
  target.grip=neutral.grip.lerp(target.grip,motion_amount)
  for side in 2:
   target.hands[side]=neutral.hands[side].lerp(target.hands[side],motion_amount)
   target.legs[side].end=neutral.legs[side].end.lerp(target.legs[side].end,motion_amount)
 var moving_gait:=not movement.is_zero_approx() and state in [&"walk",&"run",&"start_run",&"stop_run",&"crouch_walk",&"equip_walk",&"equip_run",&"equip_crouch_walk",&"pickup_walk",&"eat_walk",&"drink_walk",&"unequip",&"action",&"bow_release"]
 if moving_gait and not gait_active:
  gait_entry_age=0
  for side in 2:gait_entry_offsets[side]=displayed_pose.legs[side].end-target.legs[side].end if not displayed_pose.is_empty() else Vector3.ZERO
 gait_entry_age+=maxf(delta,0)
 gait_active=moving_gait
 if displayed_pose.is_empty() or delta <= 0:
  displayed_pose = target.duplicate(true)
 else:
  var blend := 1-exp(-delta*18)
  displayed_pose.body = displayed_pose.body.interpolate_with(target.body,blend)
  displayed_pose.leg_frame=(displayed_pose.get("leg_frame",Basis.IDENTITY) as Basis).slerp(target.leg_frame,blend)
  displayed_pose.pelvis = (displayed_pose.get("pelvis",displayed_pose.body) as Transform3D).interpolate_with(target.get("pelvis",target.body),blend)
  for side in 2:
   displayed_pose.leg_poles[side]=(displayed_pose.leg_poles[side] as Vector3).lerp(target.leg_poles[side],blend).normalized()
   displayed_pose.shoulders[side] = displayed_pose.shoulders[side].lerp(target.shoulders[side],blend)
   displayed_pose.hands[side] = displayed_pose.hands[side].lerp(target.hands[side],blend)
   for field in ["root","joint","end"]:
    displayed_pose.legs[side][field] = displayed_pose.legs[side][field].lerp(target.legs[side][field],blend)
   displayed_pose.legs[side].pitch = lerpf(displayed_pose.legs[side].pitch,target.legs[side].pitch,blend)
  displayed_pose.grip = displayed_pose.grip.lerp(target.grip,blend)
  displayed_pose.shaft = displayed_pose.shaft.lerp(target.shaft,blend).normalized()
  displayed_pose.active = target.active
  displayed_pose.look_contact=target.look_contact
  displayed_pose.state = target.state; displayed_pose.phase = target.phase
  displayed_pose.family=target.family;displayed_pose.clip_state=target.clip_state;displayed_pose.gait_phase=target.gait_phase
 if moving_gait:
  # Smooth the entry once, not every new foot target: a rolling low-pass
  # delays lift/contact and erases the fast return of a lateral step.
  var entry:=1-smoothstep(0,.15,gait_entry_age) if delta>0 else 0.0
  for side in 2:
   displayed_pose.legs[side].end=target.legs[side].end+gait_entry_offsets[side]*entry
   displayed_pose.legs[side].pitch=target.legs[side].pitch
 if state==&"death":displayed_pose=target.duplicate(true)
 for key in ["run_weight","head_basis","arm_poles","foot_bases","equipment_weight","support_weight","equipment_poles","equipment_palms","equipment_forearms","equipment_axes"]:
  if target.has(key):displayed_pose[key]=target[key]
  else:displayed_pose.erase(key)
 displayed_pose.tool_basis=target.get("tool_basis",Aim.frame(target.shaft))
 if state in [&"action",&"draw",&"death"] or (state in [&"pickup",&"pickup_walk"] and phase>=0.5 and phase<=0.58):
  displayed_pose.body=target.body;displayed_pose.pelvis=target.get("pelvis",target.body);displayed_pose.grip=target.grip;displayed_pose.shaft=target.shaft
  if state in [&"pickup",&"pickup_walk"]:displayed_pose.hands[1]=target.hands[1]
  if state==&"action" and item==&"":displayed_pose.hands=target.hands.duplicate()
 if equipping:
  # The authored/captured hand path is already eased. Filtering old generic
  # hand targets here would discard the displayed relaxed arm on the first frame.
  displayed_pose.grip=target.grip
  displayed_pose.hands=target.hands.duplicate()
 last_pose = displayed_pose
 # Re-solve the limbs after blending targets: interpolation must not shorten
 # a thigh or detach a shoulder from the moving torso.
 for side in 2:
  var body: Transform3D = last_pose.body
  last_pose.shoulders[side] = body*Vector3((-1 if side==0 else 1)*Anatomy.SHOULDER.x,Anatomy.SHOULDER.y,Anatomy.SHOULDER.z)
  last_pose.hips[side] = last_pose.get("pelvis",body)*Vector3((-1 if side==0 else 1)*Anatomy.HIP.x,Anatomy.HIP.y,0)
 Clips.solve_legs(last_pose)
 var hands: Array[Vector3] = last_pose.hands.duplicate()
 grip_error = 0
 tool_frame=last_pose.tool_basis
 if item!=&"" and state!=&"death":
  var profile:=Profiles.profile(item)
  var grip: Vector3 = last_pose.grip
  var secondary_limit:=lerpf(maxf(18.8,last_pose.shoulders[1-last_pose.active].distance_to(grip+last_pose.shaft*profile.support)),18.8,last_pose.get("support_weight",1.0))
  # Project onto the intersection of both arms' reachable volumes.
  for attempt in 24:
   var support: Vector3 = grip+last_pose.shaft*profile.support
   var active: int = last_pose.active
   var centers: Array = [last_pose.shoulders[active]]
   if profile.two_hands and last_pose.get("support_weight",1.0)>.001:
    centers.append(last_pose.shoulders[1-active]-(support-grip))
   for center in centers:
    var reach:=lerpf(18.96,18.8,last_pose.get("equipment_weight",1.0))
    if profile.two_hands and center!=centers[0]:reach=secondary_limit
    if center.distance_to(grip)>reach: grip = center+center.direction_to(grip)*reach
    elif center.distance_to(grip)<8.15: grip = center+center.direction_to(grip)*8.15
  var placement := place_tool({},grip,last_pose.shaft,Basis.IDENTITY,item)
  hands[last_pose.active] = grip
  if profile.two_hands:
   var join:float=last_pose.get("support_weight",1.0)
   hands[1-last_pose.active]=placement.support if join>=1 else hands[1-last_pose.active]+(placement.support-(last_pose.grip+last_pose.shaft*profile.support))*join
  for side in 2:
   var arm := Pose.joint(last_pose.shoulders[side],hands[side],Pose.UPPER_ARM,Pose.FOREARM,Vector3(-0.35 if side==0 else 0.35,-1,0))
   if side==last_pose.active or (profile.two_hands and last_pose.get("support_weight",1.0)>=1): grip_error = maxf(grip_error,arm.end.distance_to(hands[side]))
  grip_socket.transform=Transform3D(axe.basis,grip)
  support_socket.position=hands[1-last_pose.active]
  tip_socket.position=tool_tip
 rig.apply(last_pose,hands,delta)
 if state==&"death" and ground_enabled:ground_clearance(smoothstep(0,.025,phase) if delta>0 else 1.0)
 leaf_armor.transform=last_pose.body
 leaf_armor.update_pose(rig,last_pose.body)
 parry_pulse.update_hands([rig.posed[6].origin,rig.posed[9].origin])
 axe.visible = equipped and item==&"axe" and state!=&"death"
 for family in held_props:
  var prop:Node3D=held_props[family];prop.visible=family==item and state!=&"death"
  if prop.visible:
   prop.show_item(displayed_item,item_water_ml)
   var support_hand:Vector3=rig.posed[6 if last_pose.active==1 else 9].origin
   prop.update_pose(state,phase,grip_socket.transform.affine_inverse()*support_hand,nock_visible,grip_socket.transform.affine_inverse()*aim_contact if aim_contact.is_finite() else Vector3.INF)
 if state in Clips.SLIDE_STATES:
  # Capture after IK and grips, so take-off uses the pose actually rendered.
  slide_launch_pose=displayed_pose.duplicate(true)
  slide_launch_pose.hands=[rig.posed[6].origin,rig.posed[9].origin]
  if item!=&"":
   slide_launch_pose.grip=grip_socket.position;slide_launch_pose.tool_basis=grip_socket.basis;slide_launch_pose.shaft=grip_socket.basis.y
 elif state!=&"slide_jump":slide_launch_pose.clear()
func can_reach_contact(point: Vector3,family:StringName=&"axe") -> bool:
 var contact_pose := Clips.sample(family,&"action",0.5,0,Vector3.ZERO,point,{},action_crouch,punch_side)
 return contact_pose.get("contact_reachable",false)
func wear(item:Dictionary) -> void:leaf_armor.visible=item.get("id")==&"burdock_armor"
func confirm_parry() -> void:
 parry_pulse.play()

func ground_clearance(weight:float=1.0) -> void:
 var lift:float=ground.correction(rig.posed)*weight
 if lift<=0:return
 var shift:=Vector3.UP*lift
 last_pose.body.origin+=shift;last_pose.pelvis.origin+=shift;last_pose.grip+=shift
 for side in 2:
  last_pose.hips[side]+=shift;last_pose.shoulders[side]+=shift;last_pose.hands[side]+=shift
  for field in ["root","joint","end"]:last_pose.legs[side][field]+=shift
 for bone in rig.posed.size():rig.posed[bone].origin+=shift
 rig.pose_writer.apply(rig.skeleton,rig.posed)
