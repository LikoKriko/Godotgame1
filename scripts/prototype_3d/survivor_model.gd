extends Node3D
## Original Meshy survivor supplied by the user; shared mesh, independent rig.
const IMPORTED_SKIN=preload("res://assets/characters/prototype_3d/meshy/survivor_skin.res")
const Pose=preload("res://scripts/continuous_body_pose.gd")
const Clips=preload("res://scripts/prototype_3d/survivor_animation.gd")
const Anatomy=preload("res://scripts/prototype_3d/survivor_anatomy.gd")
const Aim=preload("res://scripts/prototype_3d/tool_aim.gd")
const Profiles=preload("res://scripts/prototype_3d/held_profiles.gd")
const GRIP_HEIGHT:=4.0
var mesh_node:MeshInstance3D
var body_material:StandardMaterial3D
var last_pose:Dictionary={}
var grip_error:=0.0
var tool_tip:=Vector3.ZERO
var tool_cutting_axis:=Vector3.ZERO
var axe: Node3D
var rig = preload("res://scripts/prototype_3d/humanoid_rig.gd").new()
var displayed_pose: Dictionary = {}
var slide_launch_pose:Dictionary={}
var family_override: StringName = &"default"
var aim_contact := Vector3.INF
var action_crouch:=0.0
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
func _ready() -> void:
 mesh_node=MeshInstance3D.new();add_child(mesh_node)
 mesh_node.mesh=IMPORTED_SKIN
 body_material=IMPORTED_SKIN.surface_get_material(0)
 rig.initialize_imported(self,mesh_node)
 axe = preload("res://scripts/prototype_3d/stone_axe.gd").new(); add_child(axe)
 for socket in [grip_socket,support_socket,tip_socket]: add_child(socket)
 grip_socket.name="ObjectGrip";support_socket.name="SupportHand";tip_socket.name="ObjectTip"
 for family in [&"pickaxe",&"sword",&"bow",&"bottle",&"food"]:
  var prop:=preload("res://scripts/prototype_3d/held_prop.gd").new();grip_socket.add_child(prop);prop.configure(family);prop.hide();held_props[family]=prop
 leaf_armor=preload("res://scripts/prototype_3d/leaf_armor.gd").new();add_child(leaf_armor);leaf_armor.hide()
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
 var item: StringName = (&"axe" if equipped else &"") if family_override==&"default" else family_override
 var target := Clips.sample(item,state,phase,movement_phase,movement,aim_contact,slide_launch_pose,action_crouch)
 if state in [&"walk",&"run",&"crouch_walk"] and motion_amount<1:
  var neutral:=Clips.sample(item,&"crouch" if state==&"crouch_walk" else &"idle",1.0 if state==&"crouch_walk" else 0.0)
  target.body=neutral.body.interpolate_with(target.body,motion_amount)
  target.pelvis=neutral.pelvis.interpolate_with(target.pelvis,motion_amount)
  target.grip=neutral.grip.lerp(target.grip,motion_amount)
  for side in 2:
   target.hands[side]=neutral.hands[side].lerp(target.hands[side],motion_amount)
   target.legs[side].end=neutral.legs[side].end.lerp(target.legs[side].end,motion_amount)
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
 displayed_pose.tool_basis=target.get("tool_basis",Aim.frame(target.shaft))
 if state in [&"action",&"draw",&"death"] or (state in [&"pickup",&"pickup_walk"] and phase>=0.5 and phase<=0.58):
  displayed_pose.body=target.body;displayed_pose.pelvis=target.get("pelvis",target.body);displayed_pose.grip=target.grip;displayed_pose.shaft=target.shaft
  if state in [&"pickup",&"pickup_walk"]:displayed_pose.hands[1]=target.hands[1]
  if state==&"action" and item==&"":displayed_pose.hands=target.hands.duplicate()
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
  # Project onto the intersection of both arms' reachable volumes.
  for attempt in 24:
   var support: Vector3 = grip+last_pose.shaft*profile.support
   var active: int = last_pose.active
   var centers: Array = [last_pose.shoulders[active]]
   if profile.two_hands: centers.append(last_pose.shoulders[1-active]-(support-grip))
   for center in centers:
    if center.distance_to(grip)>18.8: grip = center+center.direction_to(grip)*18.8
    elif center.distance_to(grip)<8.15: grip = center+center.direction_to(grip)*8.15
  var placement := place_tool({},grip,last_pose.shaft,Basis.IDENTITY,item)
  hands[last_pose.active] = grip
  if profile.two_hands: hands[1-last_pose.active] = placement.support
  for side in 2:
   var arm := Pose.joint(last_pose.shoulders[side],hands[side],Pose.UPPER_ARM,Pose.FOREARM,Vector3(-0.35 if side==0 else 0.35,-1,0))
   if side==last_pose.active or profile.two_hands: grip_error = maxf(grip_error,arm.end.distance_to(hands[side]))
  grip_socket.transform=Transform3D(axe.basis,grip)
  support_socket.position=hands[1-last_pose.active]
  tip_socket.position=tool_tip
 rig.apply(last_pose,hands,delta)
 leaf_armor.transform=last_pose.body
 parry_pulse.update_hands([rig.posed[6].origin,rig.posed[9].origin])
 axe.visible = equipped and item==&"axe" and state!=&"death"
 for family in held_props:
  var prop:Node3D=held_props[family];prop.visible=family==item and state!=&"death"
  if prop.visible:
   prop.show_item(displayed_item,item_water_ml)
   var support_hand:Vector3=rig.posed[6 if last_pose.active==1 else 9].origin
   prop.update_pose(state,phase,grip_socket.transform.affine_inverse()*support_hand,nock_visible,grip_socket.transform.affine_inverse()*aim_contact if aim_contact.is_finite() else Vector3.INF)
 if state==&"slide":
  # Capture after IK and grips, so take-off uses the pose actually rendered.
  slide_launch_pose=displayed_pose.duplicate(true)
  slide_launch_pose.hands=[rig.posed[6].origin,rig.posed[9].origin]
  if item!=&"":
   slide_launch_pose.grip=grip_socket.position;slide_launch_pose.tool_basis=grip_socket.basis;slide_launch_pose.shaft=grip_socket.basis.y
 elif state!=&"slide_jump":slide_launch_pose.clear()
func can_reach_contact(point: Vector3,family:StringName=&"axe") -> bool:
 var contact_pose := Clips.sample(family,&"action",0.5,0,Vector3.ZERO,point,{},action_crouch)
 return contact_pose.get("contact_reachable",false)
func wear(item:Dictionary) -> void:leaf_armor.visible=item.get("id")==&"burdock_armor"
func confirm_parry() -> void:
 parry_pulse.play()
