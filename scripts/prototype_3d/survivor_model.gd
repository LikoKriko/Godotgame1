extends "res://tools/continuous_actor.gd"
## Reference-driven surfaces share one bind mesh, anatomical skeleton and cloth
## weights across every action. Hair, face, hands and tools have real volume.
const HAIR := Color8(80,44,28)
const FRONT_REFERENCE = preload("res://assets/characters/prototype_3d/reference_front.png")
const BACK_REFERENCE = preload("res://assets/characters/prototype_3d/reference_back.png")
const GRIP_HEIGHT := 4.0
const Clips = preload("res://scripts/prototype_3d/survivor_animation.gd")
const Anatomy = preload("res://scripts/prototype_3d/survivor_anatomy.gd")
const Aim = preload("res://scripts/prototype_3d/tool_aim.gd")
const Profiles = preload("res://scripts/prototype_3d/held_profiles.gd")
var axe: Node3D
var rig = preload("res://scripts/prototype_3d/humanoid_rig.gd").new()
var displayed_pose: Dictionary = {}
var family_override: StringName = &"default"
var aim_contact := Vector3.INF
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
 super._ready()
 pose_direction_override = -1
 body_material.shader = preload("res://shaders/prototype_3d/skin.gdshader")
 body_material.set_shader_parameter("painted_materials",load("res://assets/characters/prototype_3d/pixel_materials.png"))
 body_material.set_shader_parameter("use_painted_materials",true)
 body_material.set_shader_parameter("front_reference",FRONT_REFERENCE)
 body_material.set_shader_parameter("back_reference",BACK_REFERENCE)
 var outline := ShaderMaterial.new(); outline.shader = preload("res://shaders/prototype_3d/outline.gdshader")
 body_material.next_pass = outline
 tool.hide()
 axe = preload("res://scripts/prototype_3d/stone_axe.gd").new(); add_child(axe)
 for socket in [grip_socket,support_socket,tip_socket]: add_child(socket)
 grip_socket.name="ObjectGrip";support_socket.name="SupportHand";tip_socket.name="ObjectTip"
 for family in [&"pickaxe",&"sword",&"bow",&"bottle",&"food"]:
  var prop:=preload("res://scripts/prototype_3d/held_prop.gd").new();grip_socket.add_child(prop);prop.configure(family);prop.hide();held_props[family]=prop
 leaf_armor=preload("res://scripts/prototype_3d/leaf_armor.gd").new();add_child(leaf_armor);leaf_armor.hide()
 parry_pulse=preload("res://scripts/prototype_3d/parry_pulse.gd").new();add_child(parry_pulse)
 # Build the unarmed bind mesh once; animation only updates its skeleton.
 build(&"",&"",&"idle",0,4)
 rig.initialize(self,mesh_node)
 core_mesh.hide()
func tube(joints: Array,radius_a: float,radius_b: float,color: Color,shorts: bool = false,steps: int = 12) -> void:
 if color!=SKIN:
  super.tube(joints,radius_a,radius_b,color,shorts,steps);return
 # Anatomical cross sections span both bones, with no detached elbow/knee caps.
 var sections: Array[Vector3]
 if shorts:
  sections=[Vector3(0,1.10,1.03),Vector3(0.12,1.19,1.10),Vector3(0.26,1.14,1.10),Vector3(0.38,1.06,1.03),Vector3(0.43,0.85,0.91),Vector3(0.5,0.78,0.96),Vector3(0.58,0.83,0.88),Vector3(0.69,0.99,0.94),Vector3(0.82,0.72,0.75),Vector3(0.94,0.55,0.61),Vector3(1,0.57,0.64)]
 else:
  sections=[Vector3(0,0.75,0.85),Vector3(0.09,0.95,0.98),Vector3(0.23,1.07,1.00),Vector3(0.4,0.74,0.79),Vector3(0.5,0.68,0.79),Vector3(0.60,0.83,0.83),Vector3(0.74,0.72,0.69),Vector3(0.9,0.49,0.53),Vector3(1,0.47,0.49)]
 var rings:Array[PackedVector3Array]=[];var centers:Array[Vector3]=[]
 var sides:=16
 for shape:Vector3 in sections:
  var t:=shape.x
  var center:Vector3=joints[0].lerp(joints[1],t*2) if t<=0.5 else joints[1].lerp(joints[2],(t-0.5)*2)
  if not shorts and t<0.23:
   var shoulder_blend:=1-smoothstep(0,0.23,t)
   center+=Vector3((-1 if joints[0].x>0 else 1)*shoulder_blend,0.2*shoulder_blend,0)
  var tangent:Vector3=(joints[1]-joints[0]).normalized() if t<0.5 else (joints[2]-joints[1]).normalized()
  var across:=Vector3.RIGHT-tangent*tangent.x
  if across.length_squared()<0.01:across=Vector3.BACK-tangent*tangent.z
  across=across.normalized();var front:=across.cross(tangent).normalized()
  if front.z<0:front=-front
  var cloth:=0.45 if shorts and t<0.4 else 0.0
  var ring:=PackedVector3Array()
  for segment in sides:
   var angle:=segment*TAU/sides
   var hem:=0.0
   if shorts and is_equal_approx(t,0.38):hem=-0.32+0.35*sin(segment*2.7)
   ring.append(center+across*cos(angle)*(radius_a*shape.y+cloth)+front*sin(angle)*(radius_a*shape.z+cloth)+Vector3.UP*hem)
  rings.append(ring);centers.append(center)
 for row in rings.size()-1:
  var tint:=CLOTH if shorts and sections[row].x<0.38 else color
  for i in sides:
   var next:=(i+1)%sides
   triangle(rings[row][i],rings[row+1][i],rings[row+1][next],tint);triangle(rings[row][i],rings[row+1][next],rings[row][next],tint)
 for i in sides:
  if shorts:triangle(centers[0],rings[0][(i+1)%sides],rings[0][i],CLOTH)
  triangle(centers[-1],rings[-1][i],rings[-1][(i+1)%sides],color)
func triangle(a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
 surface.set_smooth_group(0)
 super.triangle(a,b,c,color)
func ellipsoid(center: Vector3,size: Vector3,color: Color,basis: Basis = Basis.IDENTITY) -> void:
 if surface_tag in [1.0,2.0] and color==SKIN and size.is_equal_approx(Vector3(1.45,1.7,1.5)):
  append_hand(center,-1.0 if surface_tag==1 else 1.0);return
 if center.y<4 and is_equal_approx(size.x,2.5):size.x=2.3
 if color.r<0.55 and center.y<27 and size.z<0.2:return # Retired round trouser patches.
 if absf(center.x)>7.0 and absf(center.x)<7.9 and absf(center.y-44.6)<0.1 and color==SKIN:return
 if center.is_equal_approx(Vector3(0,35,0)) and size.is_equal_approx(Vector3(6.5,8.5,3)):
  append_torso();return
 if center.is_equal_approx(Vector3(0,42,0)) or center.is_equal_approx(Vector3(0,48,0)):return
 if center.is_equal_approx(Vector3(0,27.7,0)):
  # Waistband joins both cloth legs without the old spherical crotch.
  profile_volume([Vector3(25.3,6.9,3.2),Vector3(27.5,7.0,3.3),Vector3(29.4,6.8,3.15)],CLOTH);return
 if center.y>=31 and center.y<=44 and center.z>2 and size.z<1.5:return
 super.ellipsoid(center,size,color,basis)
func profile_volume(profile:Array,color:Color,frame:Transform3D=Transform3D.IDENTITY) -> void:
 var rings:Array[PackedVector3Array]=[]
 for row:Vector3 in profile:
  var ring:=PackedVector3Array()
  for i in 32:
   var a:=i*TAU/32;var x:=signf(cos(a))*pow(absf(cos(a)),0.9)*row.y
   var z:=signf(sin(a))*pow(absf(sin(a)),0.86)*row.z
   ring.append(frame*Vector3(x,row.x,z))
  rings.append(ring)
 for row in rings.size()-1:
  for i in 32:
   var next:=(i+1)%32
   triangle(rings[row][i],rings[row+1][next],rings[row+1][i],color)
   triangle(rings[row][i],rings[row][next],rings[row+1][next],color)
func append_hand(center:Vector3,side:float) -> void:
 super.ellipsoid(center+Vector3(0,-0.15,0),Vector3(1.0,1.25,0.67),SKIN)
 # Four fingers and an opposed thumb, all assigned to the existing hand bone.
 for finger in 4:
  var x:=side*(-0.65+finger*0.43);var length:float=[1.30,1.58,1.45,1.10][finger]
  var root_point:=center+Vector3(x,-0.75,0.15)
  var middle:=root_point+Vector3(side*0.05,-length*0.6,0.18)
  var tip:=middle+Vector3(-side*0.10,-length*0.40,0.24)
  super.tube([root_point,middle,tip],0.28,0.22,SKIN,false,4)
  super.ellipsoid(tip,Vector3(0.22,0.25,0.22),SKIN)
 var thumb:=center+Vector3(-side*0.85,0.1,0.25)
 super.tube([thumb,thumb+Vector3(-side*0.55,-0.65,0.3),thumb+Vector3(-side*0.40,-1.25,0.65)],0.4,0.3,SKIN,false,4)
func append_torso() -> void:
 var profile := [Vector3(26.9,6.7,3),Vector3(31,6.1,2.65),Vector3(35,6.4,3),Vector3(38,7.4,3.4),Vector3(41,8.2,3.7),Vector3(43.5,9.2,3.45),Vector3(44.7,9.7,3.1),Vector3(45.8,8.5,2.7),Vector3(46.8,5.6,2.1),Vector3(47.6,2.4,1.8),Vector3(49.5,2,1.8)]
 var rings: Array[PackedVector3Array] = []
 for section in profile.size()-1:
  for step in 3:
   var shape: Vector3 = profile[section].lerp(profile[section+1],step/3.0)
   var ring := PackedVector3Array()
   for i in 24:
    var angle := i*TAU/24
    var across:=cos(angle);var depth:=sin(angle)
    # Flatter back/chest planes and subtle shoulder blades, keeping the slim waist.
    var x:=signf(across)*pow(absf(across),0.85)*shape.y
    var z:=signf(depth)*pow(absf(depth),0.80)*shape.z
    if z<0 and shape.x>35 and shape.x<45:
     z-=0.35*exp(-pow((absf(x)-4.4)/1.7,2))*sin((shape.x-35)/10*PI)
    ring.append(Vector3(x,shape.x,z))
   rings.append(ring)
 var final_ring := PackedVector3Array()
 var shape: Vector3 = profile[-1]
 for i in 24: final_ring.append(Vector3(cos(i*TAU/24)*shape.y,shape.x,sin(i*TAU/24)*shape.z))
 rings.append(final_ring)
 for row in rings.size()-1:
  for i in 24:
   var next := (i+1)%24
   triangle(rings[row][i],rings[row+1][next],rings[row+1][i],SKIN)
   triangle(rings[row][i],rings[row][next],rings[row+1][next],SKIN)
func integrated_head(torso: Transform3D, _actor_basis: Basis, _direction: int, _pose_state: StringName) -> void:
 surface_tag=3
 head_center=torso*Vector3(0,55.1,0)
 # Forehead, temples, cheekbones and jaw are one closed volume.
 profile_volume([Vector3(49.4,2.8,2.6),Vector3(50.6,3.8,3.5),Vector3(52.0,4.9,4.3),Vector3(54.0,5.7,4.8),Vector3(56.0,5.8,4.7),Vector3(58.3,5.4,4.3),Vector3(60.2,4.3,3.4),Vector3(61.0,0.1,0.1)],SKIN,torso)
 for side in [-1,1]:
  super.ellipsoid(torso*Vector3(side*5.7,54.1,0),Vector3(1.0,1.8,1.1),SKIN,torso.basis)
  super.ellipsoid(torso*Vector3(side*5.9,54.2,0.65),Vector3(0.55,1.1,0.3),SKIN.darkened(0.16),torso.basis)
  # Deep-set almond eyes, amber iris, dark pupil and restrained catchlight.
  super.ellipsoid(torso*Vector3(side*2.15,55.4,4.35),Vector3(1.45,1.0,0.55),SKIN.darkened(0.27),torso.basis)
  super.ellipsoid(torso*Vector3(side*2.15,55.35,4.65),Vector3(1.15,0.75,0.34),Color('f1d7ad'),torso.basis)
  super.ellipsoid(torso*Vector3(side*2.15,55.35,4.94),Vector3(0.64,0.69,0.18),Color('794423'),torso.basis)
  super.ellipsoid(torso*Vector3(side*2.15,55.35,5.09),Vector3(0.29,0.49,0.10),Color('231610'),torso.basis)
  super.ellipsoid(torso*Vector3(side*2.15-0.18,55.65,5.18),Vector3(0.16,0.18,0.06),Color('fff3d6'),torso.basis)
  super.ellipsoid(torso*Vector3(side*2.2,56.8,4.6),Vector3(1.65,0.45,0.45),HAIR,torso.basis*Basis(Vector3.BACK,side*0.08))
 super.ellipsoid(torso*Vector3(0,54.4,4.65),Vector3(0.72,1.3,0.85),SKIN,torso.basis)
 super.ellipsoid(torso*Vector3(0,53.8,5.2),Vector3(1.15,0.75,0.85),SKIN.darkened(0.04),torso.basis)
 for side in [-1,1]:super.ellipsoid(torso*Vector3(side*0.65,53.5,5.45),Vector3(0.28,0.2,0.15),SKIN.darkened(0.32),torso.basis)
 # Beard underlay is continuous around the jaw; locks add shallow relief.
 for row in 4:
  var y:=49.4+row*0.85
  for i in 20:
   var a:=lerpf(-1.6,1.6,i/20.0);var b:=lerpf(-1.6,1.6,(i+1)/20.0)
   var r:=2.7+row*0.7
   var p:=Vector3(sin(a)*r,y+absf(sin(a))*0.75,cos(a)*(3.9+row*0.15))
   var q:=Vector3(sin(b)*r,y+absf(sin(b))*0.75,cos(b)*(3.9+row*0.15))
   triangle(torso*p,torso*q,torso*(q+Vector3.UP*0.85),HAIR)
   triangle(torso*p,torso*(q+Vector3.UP*0.85),torso*(p+Vector3.UP*0.85),HAIR)
 # Layered beard wraps the jaw and neck rather than a painted chin patch.
 for row in 3:
  for i in 9:
   var a:=lerpf(-1.4,1.4,i/8.0)
   var y:=52.8-row*1.0+absf(sin(a))*0.65
   var root_point:=Vector3(sin(a)*(4.8-row*0.4),y,cos(a)*4.25)
   hair_lock(torso,root_point,root_point+Vector3(sin(a)*0.2,-1.35,0.35),0.8,HAIR.lightened(0.025*((i+row)%3)))
 for side in [-1,1]:hair_lock(torso,Vector3(side*0.1,52.9,5.05),Vector3(side*2.2,52.45,4.8),0.5,HAIR)
 append_hair(torso)
 surface_tag=0
func hair_lock(frame:Transform3D,root_point:Vector3,tip:Vector3,width:float,color:Color) -> void:
 var axis:=root_point.direction_to(tip)
 var outward:=Vector3(root_point.x,(root_point.y-55.5)*0.4,root_point.z).normalized()
 var across:=axis.cross(outward).normalized()
 if across.length_squared()<0.1:across=Vector3.RIGHT
 var center:=root_point.lerp(tip,0.38)
 var rim:=[root_point-across*width*0.55,center-across*width,tip,center+across*width,root_point+across*width*0.55]
 var ridge:=center+outward*width*0.45
 for i in rim.size():
  var a:Vector3=rim[i];var b:Vector3=rim[(i+1)%rim.size()]
  if (ridge-a).cross(b-a).dot(outward)<0:
   var swap:=a;a=b;b=swap
  triangle(frame*a,frame*b,frame*ridge,color.lightened(0.02 if i%2==0 else 0))
func append_hair(torso:Transform3D) -> void:
 var rings:Array[PackedVector3Array]=[]
 for row in 6:
  var t:=row/5.0;var ring:=PackedVector3Array()
  for i in 24:
   var a:=i*TAU/24;var front:=maxf(0,sin(a))
   var lower:=51.0+front*7.25
   var y:=lerpf(lower,62.15,t)
   var radius:=hair_radius(y)
   ring.append(torso*Vector3(cos(a)*6.0*radius,y,sin(a)*5.0*radius-0.15))
  rings.append(ring)
 for row in 5:
  for i in 24:
   var n:=(i+1)%24
   triangle(rings[row][i],rings[row+1][n],rings[row+1][i],HAIR)
   triangle(rings[row][i],rings[row][n],rings[row+1][n],HAIR)
 for row in 4:
  for i in 14:
   var a:float=(i+float(row%2)*0.5)*TAU/14
   var front:=maxf(0,sin(a));var lower:=51.1+front*7.25
   var y:=lerpf(lower+0.6,61.8,row/4.0)
   var r:=hair_radius(y)
   var root_point:=Vector3(cos(a)*6.05*r,y,sin(a)*5.05*r-0.15)
   var ty:=y-1.2;var tr:=hair_radius(ty)
   hair_lock(torso,root_point,Vector3(cos(a)*6.1*tr,ty,sin(a)*5.1*tr-0.15),1.0,HAIR.lightened(0.018*((i+row)%4)))
 for i in 6:
  var x:float=(i-2.5)*1.3
  hair_lock(torso,Vector3(x,60.5,1.4),Vector3(x+1.2,62.5-absf(x)*0.08,-0.2),1.0,HAIR.lightened(0.02*(i%3)))
func hair_radius(y:float) -> float:
 var values:=[Vector2(49.5,0.55),Vector2(51.0,0.75),Vector2(54,0.99),Vector2(56,1.02),Vector2(58,0.98),Vector2(60,0.81),Vector2(62.5,0.12)]
 for i in values.size()-1:
  if y<=values[i+1].x:return lerpf(values[i].y,values[i+1].y,clampf((y-values[i].x)/(values[i+1].x-values[i].x),0,1))
 return 0.1
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
func animate(state: StringName, phase: float, equipped: bool, delta: float = 0.0, movement_phase: float = 0.0, movement: Vector3 = Vector3.ZERO) -> void:
 var item: StringName = (&"axe" if equipped else &"") if family_override==&"default" else family_override
 var target := Clips.sample(item,state,phase,movement_phase,movement,aim_contact)
 if displayed_pose.is_empty() or delta <= 0:
  displayed_pose = target.duplicate(true)
 else:
  var blend := 1-exp(-delta*18)
  displayed_pose.body = displayed_pose.body.interpolate_with(target.body,blend)
  for side in 2:
   displayed_pose.shoulders[side] = displayed_pose.shoulders[side].lerp(target.shoulders[side],blend)
   displayed_pose.hands[side] = displayed_pose.hands[side].lerp(target.hands[side],blend)
   for field in ["root","joint","end"]:
    displayed_pose.legs[side][field] = displayed_pose.legs[side][field].lerp(target.legs[side][field],blend)
   displayed_pose.legs[side].pitch = lerpf(displayed_pose.legs[side].pitch,target.legs[side].pitch,blend)
  displayed_pose.grip = displayed_pose.grip.lerp(target.grip,blend)
  displayed_pose.shaft = displayed_pose.shaft.lerp(target.shaft,blend).normalized()
  displayed_pose.active = target.active
  displayed_pose.state = target.state; displayed_pose.phase = target.phase
  displayed_pose.family=target.family;displayed_pose.clip_state=target.clip_state;displayed_pose.gait_phase=target.gait_phase
 displayed_pose.tool_basis=target.get("tool_basis",Aim.frame(target.shaft))
 if state in [&"action",&"draw",&"death"]:
  displayed_pose.body=target.body;displayed_pose.grip=target.grip;displayed_pose.shaft=target.shaft
 last_pose = displayed_pose
 # Re-solve the limbs after blending targets: interpolation must not shorten
 # a thigh or detach a shoulder from the moving torso.
 for side in 2:
  var body: Transform3D = last_pose.body
  last_pose.shoulders[side] = body*Vector3((-1 if side==0 else 1)*Anatomy.SHOULDER.x,45.7,0)
  last_pose.hips[side] = body*Vector3((-1 if side==0 else 1)*Anatomy.HIP.x,26.9,0)
 Clips.solve_legs(last_pose)
 var hands: Array[Vector3] = last_pose.hands.duplicate()
 grip_error = 0
 tool_frame=last_pose.tool_basis
 if item!=&"":
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
 axe.visible = equipped and item==&"axe"
 for family in held_props:
  var prop:Node3D=held_props[family];prop.visible=family==item and state!=&"death"
  if prop.visible:
   prop.show_item(displayed_item,item_water_ml)
   var support_hand:Vector3=rig.posed[6 if last_pose.active==1 else 9].origin
   prop.update_pose(state,phase,grip_socket.transform.affine_inverse()*support_hand,nock_visible)
 tool.hide(); core_mesh.hide()
func can_reach_contact(point: Vector3,family:StringName=&"axe") -> bool:
 var contact_pose := Clips.sample(family,&"action",0.5,0,Vector3.ZERO,point)
 return contact_pose.get("contact_reachable",false)
func wear(item:Dictionary) -> void:leaf_armor.visible=item.get("id")==&"burdock_armor"
func confirm_parry() -> void:
 parry_pulse.play()
