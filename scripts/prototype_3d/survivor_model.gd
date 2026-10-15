extends "res://tools/continuous_actor.gd"
## Reference-driven surfaces share one bind mesh, anatomical skeleton and cloth
## weights across every action. Hair, face, hands and tools have real volume.
const HAIR := Color8(80,44,28)
const FRONT_REFERENCE = preload("res://assets/characters/prototype_3d/reference_front.png")
const BACK_REFERENCE = preload("res://assets/characters/prototype_3d/reference_back.png")
const GRIP_HEIGHT := 4.0
const Clips = preload("res://scripts/prototype_3d/survivor_animation.gd")
const SurfaceProfile=preload("res://scripts/prototype_3d/survivor_surface.gd")
const Anatomy = preload("res://scripts/prototype_3d/survivor_anatomy.gd")
const Aim = preload("res://scripts/prototype_3d/tool_aim.gd")
const Profiles = preload("res://scripts/prototype_3d/held_profiles.gd")
const Kinematics=preload("res://scripts/prototype_3d/human_kinematics.gd")
var authored_limbs:Dictionary={}
var authored_cloth_coordinates:Dictionary={}
var axe: Node3D
var rig = preload("res://scripts/prototype_3d/humanoid_rig.gd").new()
var displayed_pose: Dictionary = {}
var slide_launch_pose:Dictionary={}
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
 var outline := ShaderMaterial.new(); outline.shader = preload("res://shaders/prototype_3d/survivor_outline.gdshader")
 outline.set_shader_parameter("thickness",0.085)
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
  # Refit the original waist cord to the new cloth silhouette, not its old
  # broad ellipse. The knot tails stay just in front of the same waistband.
  if color in [Color8(128,84,43),Color8(131,86,44)] and joints[0].y>26:
   var fitted:Array=[]
   for p:Vector3 in joints:
    var size:=SurfaceProfile.pelvis_radius(p.y)+Vector2.ONE*.18
    fitted.append(Vector3(p.x/6.7*size.x/Anatomy.BODY_WIDTH,p.y,p.z/3.4*size.y/Anatomy.BODY_DEPTH))
   super.tube(fitted,radius_a,radius_b,color,shorts,steps)
  else:super.tube(joints,radius_a,radius_b,color,shorts,steps)
  return
 var key:=int(surface_tag) if not shorts else (10 if joints[0].x<0 else 11)
 authored_limbs[key]={"root":joints[0],"joint":joints[1],"end":joints[2]}
 # Anatomical cross sections span both bones, with no detached elbow/knee caps.
 var sections: Array[Vector3]
 if shorts:
  sections=[Vector3(0,1.10,1.03),Vector3(0.12,1.19,1.10),Vector3(0.26,1.14,1.10),Vector3(0.38,1.06,1.03),Vector3(0.43,0.85,0.91),Vector3(0.47,0.82,0.96),Vector3(0.5,0.80,1.00),Vector3(0.53,0.81,0.95),Vector3(0.58,0.83,0.88),Vector3(0.69,0.99,0.94),Vector3(0.82,0.72,0.75),Vector3(0.94,0.55,0.61),Vector3(1,0.57,0.64)]
 else:
  sections=[Vector3(0,0.25,0.35),Vector3(0.045,0.85,0.92),Vector3(0.09,0.98,1.04),Vector3(0.23,1.07,1.00),Vector3(0.4,0.78,0.82),Vector3(0.46,0.72,0.78),Vector3(0.5,0.70,0.79),Vector3(0.54,0.76,0.80),Vector3(0.60,0.83,0.83),Vector3(0.74,0.72,0.69),Vector3(0.9,0.49,0.53),Vector3(1,0.47,0.49)]
 var rings:Array[PackedVector3Array]=[];var centers:Array[Vector3]=[]
 var sides:=24
 for shape:Vector3 in sections:
  var t:=shape.x
  var center:Vector3=joints[0].lerp(joints[1],t*2) if t<=0.5 else joints[1].lerp(joints[2],(t-0.5)*2)
  if not shorts and t<0.23:
   var shoulder_blend:=1-smoothstep(0,0.23,t)
   center+=Vector3((-1 if joints[0].x>0 else 1)*1.9*shoulder_blend,0.05*shoulder_blend,0)
  var tangent:Vector3=(joints[1]-joints[0]).normalized().slerp((joints[2]-joints[1]).normalized(),smoothstep(0.4,0.6,t))
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
   var cloth_width:=lerpf(0.79,1.0,smoothstep(0.34,0.43,t)) if shorts else 1.0
   var point:Vector3=center+across*cos(angle)*(radius_a*shape.y+cloth)*cloth_width+front*sin(angle)*(radius_a*shape.z+cloth)+Vector3.UP*hem
   ring.append(point)
   if shorts:authored_cloth_coordinates[point]=Vector2(cos(angle),point.y)
  rings.append(ring);centers.append(center)
  if shorts:authored_cloth_coordinates[center]=Vector2(0,center.y)
 for row in rings.size()-1:
  var tint:=CLOTH if shorts and sections[row].x<0.38 else color
  for i in sides:
   var next:=(i+1)%sides
   triangle(rings[row][i],rings[row+1][i],rings[row+1][next],tint);triangle(rings[row][i],rings[row+1][next],rings[row][next],tint)
 for i in sides:
  if shorts:triangle(centers[0],rings[0][(i+1)%sides],rings[0][i],CLOTH)
  triangle(centers[-1],rings[-1][i],rings[-1][(i+1)%sides],color)
func mesh_to_bind(point:Vector3,tag:int,skin_rig:RefCounted) -> Vector3:
 if tag in [5,6]:
  var side:=tag-5
  var source:Dictionary=authored_limbs[side+1]
  return skin_rig.arm_rest[side].end+Kinematics.hand_frame(skin_rig.arm_rest[side],Basis.IDENTITY,side)*(point-source.end)*0.84
 if tag in [1,2]:
  return Kinematics.retarget(point,authored_limbs[tag],skin_rig.arm_rest[tag-1])
 if tag==0 and point.y<26.0:
  var side:=0 if point.x<0 else 1
  var transformed:=Kinematics.retarget(point,authored_limbs[10+side],skin_rig.neutral.legs[side])
  # The crotch and waistband stay on the pelvis, not on either moving thigh.
  return fit_upper_cloth(transformed.lerp(Anatomy.geometry(point,tag),smoothstep(23,26,point.y)),point)
 var result:=Anatomy.geometry(point,tag)
 return fit_upper_cloth(result,point) if tag==0 and authored_cloth_coordinates.has(point) else result
func fit_upper_cloth(point:Vector3,authored:Vector3) -> Vector3:
 if authored.y<23.0:return point
 var size:=SurfaceProfile.pelvis_radius(point.y)
 # Upper trouser tubes meet the shared hip shell; they cannot stick through
 # its sides and form a horizontal ledge. Preserve the individual leg hems.
 var extent:=pow(pow(absf(point.x)/size.x,2.2)+pow(absf(point.z)/size.y,2.2),1.0/2.2)
 if extent>1.0:
  var amount:=smoothstep(23.0,25.3,authored.y)
  point.x=lerpf(point.x,point.x/extent,amount)
  point.z=lerpf(point.z,point.z/extent,amount)
 return point
func triangle(a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
 surface.set_smooth_group(0)
 super.triangle(a,b,c,color)
func ellipsoid(center: Vector3,size: Vector3,color: Color,basis: Basis = Basis.IDENTITY) -> void:
 if surface_tag in [1.0,2.0] and color==SKIN and size.is_equal_approx(Vector3(1.45,1.7,1.5)):
  var previous:=surface_tag
  surface_tag=5.0 if previous==1 else 6.0
  append_hand(center,-1.0 if previous==1 else 1.0)
  surface_tag=previous;return
 if center.y<4 and is_equal_approx(size.x,2.5):size.x=2.3
 if color.r<0.55 and center.y<27 and size.z<0.2:return # Retired round trouser patches.
 if absf(center.x)>7.0 and absf(center.x)<7.9 and absf(center.y-44.6)<0.1 and color==SKIN:return
 if center.is_equal_approx(Vector3(0,35,0)) and size.is_equal_approx(Vector3(6.5,8.5,3)):
  append_torso();return
 if center.is_equal_approx(Vector3(0,42,0)) or center.is_equal_approx(Vector3(0,48,0)):return
 if center.is_equal_approx(Vector3(0,27.7,0)):
  # Waistband joins both cloth legs without the old spherical crotch.
  var previous:=surface_tag;surface_tag=13
  var profile:Array=[]
  for ring:Vector3 in SurfaceProfile.PELVIS:profile.append(Vector3(ring.x,ring.y/Anatomy.BODY_WIDTH,ring.z/Anatomy.BODY_DEPTH))
  profile_volume(profile,CLOTH)
  surface_tag=previous;return
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
 super.ellipsoid(center+Vector3(0,-0.15,0),Vector3(1.18,1.38,0.63),SKIN)
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
 # Silhouette landmarks follow the supplied front/back views. Depth is sculpted
 # separately: a projected painting must not substitute for a rib cage/scapula.
 var profile:Array=[]
 for mark:Vector4 in SurfaceProfile.FRONT:
  var shape:=SurfaceProfile.radius(mark.x)
  profile.append(Vector3(mark.x,shape.x/Anatomy.BODY_WIDTH,shape.y/Anatomy.BODY_DEPTH))
 var rings:Array[PackedVector3Array]=[]
 var sides:=48
 for section in profile.size()-1:
  for step in 3:
   var shape:Vector3=profile[section].lerp(profile[section+1],step/3.0)
   var ring:=PackedVector3Array()
   for i in sides:
    var angle:=i*TAU/sides
    var across:=cos(angle);var depth:=sin(angle)
    var x:=signf(across)*pow(absf(across),0.91)*shape.y
    var z:=signf(depth)*pow(absf(depth),0.88)*shape.z
    var front:=maxf(0,depth)
    # Real shallow pectoral/oblique planes, clavicles and sternum depression.
    z+=front*(0.38*exp(-pow((absf(x)-3.7)/2.2,2)-pow((shape.x-41.0)/2.3,2)))
    z-=front*0.16*exp(-x*x/0.8-pow((shape.x-40.8)/3.8,2))
    z+=front*0.12*exp(-pow((absf(x)-1.65)/1.1,2)-pow((shape.x-34.7)/3.2,2))
    z+=front*0.20*exp(-pow((shape.x-(45.5-absf(x)*0.10))/0.32,2))*smoothstep(0.5,2.0,absf(x))
    if z<0:
     z-=0.43*exp(-pow((absf(x)-4.0)/1.8,2)-pow((shape.x-41.5)/3.0,2))
     z+=0.17*exp(-x*x/0.7-pow((shape.x-38.5)/6.0,2))
    ring.append(Vector3(x,shape.x,z))
   rings.append(ring)
 var top:=PackedVector3Array()
 var neck_size:=SurfaceProfile.radius(49.5)
 for i in sides:top.append(Vector3(cos(i*TAU/sides)*neck_size.x/Anatomy.BODY_WIDTH,49.5,sin(i*TAU/sides)*neck_size.y/Anatomy.BODY_DEPTH))
 rings.append(top)
 for row in rings.size()-1:
  for i in sides:
   var next:=(i+1)%sides
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
  super.ellipsoid(torso*Vector3(side*2.15,55.35,4.65),Vector3(1.05,0.64,0.25),Color('f1d7ad'),torso.basis)
  super.ellipsoid(torso*Vector3(side*2.15,55.35,4.85),Vector3(0.55,0.59,0.12),Color('794423'),torso.basis)
  super.ellipsoid(torso*Vector3(side*2.15,55.35,4.98),Vector3(0.26,0.43,0.06),Color('231610'),torso.basis)
  super.ellipsoid(torso*Vector3(side*2.15-0.18,55.60,5.04),Vector3(0.16,0.18,0.06),Color('fff3d6'),torso.basis)
  super.ellipsoid(torso*Vector3(side*2.2,56.8,4.6),Vector3(1.75,0.56,0.48),HAIR,torso.basis*Basis(Vector3.BACK,side*0.08))
 super.ellipsoid(torso*Vector3(0,54.4,4.65),Vector3(0.72,1.3,0.85),SKIN,torso.basis)
 super.ellipsoid(torso*Vector3(0,53.8,5.2),Vector3(1.15,0.75,0.85),SKIN.darkened(0.04),torso.basis)
 for side in [-1,1]:super.ellipsoid(torso*Vector3(side*0.65,53.5,5.45),Vector3(0.28,0.2,0.15),SKIN.darkened(0.32),torso.basis)
 # One connected beard shell follows chin, jaw and cheeks. Its ridges are
 # shallow relief, not detached strips intersecting the face at every frame.
 var beard_rings:Array[PackedVector3Array]=[]
 for row in 8:
  var t:=row/7.0;var ring:=PackedVector3Array()
  for i in 33:
   var a:=lerpf(-1.65,1.65,i/32.0)
   var width:=lerpf(2.9,5.0,t)
   var y:=lerpf(48.8,53.1,t)+pow(absf(sin(a)),1.2)*lerpf(0.7,1.7,t)
   var relief:=0.10*cos(a*16+t*2.0)
   ring.append(torso*Vector3(sin(a)*(width+relief),y,cos(a)*(4.2+t*0.75+relief)))
  beard_rings.append(ring)
 for row in 7:
  for i in 32:
   var tone:=HAIR.lightened(0.018 if i%4==0 else 0.0)
   triangle(beard_rings[row][i],beard_rings[row+1][i+1],beard_rings[row+1][i],tone)
   triangle(beard_rings[row][i],beard_rings[row][i+1],beard_rings[row+1][i+1],tone)
 for i in 9:
  var a:=lerpf(-1.5,1.5,i/8.0)
  var root_point:=Vector3(sin(a)*3.7,50.0+absf(sin(a))*0.8,cos(a)*4.6)
  hair_lock(torso,root_point,root_point+Vector3(sin(a)*0.2,-1.2,0.1),0.58,HAIR)
 for side in [-1,1]:hair_lock(torso,Vector3(side*0.1,53.0,5.45),Vector3(side*2.2,52.6,5.1),0.5,HAIR)
 super.ellipsoid(torso*Vector3(0,52.35,4.9),Vector3(1.5,0.25,0.2),Color("673a26"),torso.basis)
 super.ellipsoid(torso*Vector3(0,52.1,5.05),Vector3(1.25,0.22,0.25),SKIN.darkened(0.12),torso.basis)
 append_hair(torso)
 surface_tag=0
func hair_lock(frame:Transform3D,root_point:Vector3,tip:Vector3,width:float,color:Color) -> void:
 # Closed, thick tufts. Flat paper triangles made the old beard/scalp sparkle.
 var axis:=root_point.direction_to(tip)
 var outward:=Vector3(root_point.x,(root_point.y-55.5)*0.4,root_point.z).normalized()
 outward=(outward-axis*outward.dot(axis)).normalized()
 var across:=axis.cross(outward).normalized()
 var rings:Array[PackedVector3Array]=[]
 for shape:Vector3 in [Vector3(0,0.48,0.26),Vector3(0.3,1,0.55),Vector3(0.68,0.65,0.42),Vector3(1,0.035,0.035)]:
  var ring:=PackedVector3Array();var center:=root_point.lerp(tip,shape.x)
  for i in 8:ring.append(frame*(center+across*cos(i*TAU/8)*width*shape.y+outward*sin(i*TAU/8)*width*shape.z))
  rings.append(ring)
 for row in rings.size()-1:
  for i in 8:
   var n:=(i+1)%8
   triangle(rings[row][i],rings[row+1][n],rings[row+1][i],color)
   triangle(rings[row][i],rings[row][n],rings[row+1][n],color)
 for i in 8:triangle(frame*root_point,rings[0][(i+1)%8],rings[0][i],color)
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
   var ty:=y-2.0;var tr:=hair_radius(ty)
   hair_lock(torso,root_point,Vector3(cos(a)*6.1*tr,ty,sin(a)*5.1*tr-0.15),1.0,HAIR.lightened(0.018*((i+row)%4)))
 # Close the crown, including views from a fully raised camera.
 for i in 24:triangle(rings[-1][i],rings[-1][(i+1)%24],torso*Vector3(0,62.4,-0.15),HAIR)
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
 var target := Clips.sample(item,state,phase,movement_phase,movement,aim_contact,slide_launch_pose)
 if displayed_pose.is_empty() or delta <= 0:
  displayed_pose = target.duplicate(true)
 else:
  var blend := 1-exp(-delta*18)
  displayed_pose.body = displayed_pose.body.interpolate_with(target.body,blend)
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
 if state==&"slide":
  # Capture after IK and grips, so take-off uses the pose actually rendered.
  slide_launch_pose=displayed_pose.duplicate(true)
  slide_launch_pose.hands=[rig.posed[6].origin,rig.posed[9].origin]
  if item!=&"":
   slide_launch_pose.grip=grip_socket.position;slide_launch_pose.tool_basis=grip_socket.basis;slide_launch_pose.shaft=grip_socket.basis.y
 elif state!=&"slide_jump":slide_launch_pose.clear()
func can_reach_contact(point: Vector3,family:StringName=&"axe") -> bool:
 var contact_pose := Clips.sample(family,&"action",0.5,0,Vector3.ZERO,point)
 return contact_pose.get("contact_reachable",false)
func wear(item:Dictionary) -> void:leaf_armor.visible=item.get("id")==&"burdock_armor"
func confirm_parry() -> void:
 parry_pulse.play()
