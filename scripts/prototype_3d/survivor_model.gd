extends "res://tools/continuous_actor.gd"
## Real surfaces replace the authoring billboard skull and flat tool. The body,
## shorts and anatomical IK remain the same continuous authoring geometry.
const HAIR := Color8(66,43,30)
const GRIP_HEIGHT := 4.0
var axe: Node3D
var rig = preload("res://scripts/prototype_3d/humanoid_rig.gd").new()
var displayed_pose: Dictionary = {}
func _ready() -> void:
 super._ready()
 pose_direction_override = -1
 body_material.shader = preload("res://shaders/prototype_3d/skin.gdshader")
 body_material.set_shader_parameter("painted_materials",load("res://assets/characters/prototype_3d/painted_materials.png"))
 body_material.set_shader_parameter("use_painted_materials",true)
 var outline := ShaderMaterial.new(); outline.shader = preload("res://shaders/prototype_3d/outline.gdshader")
 body_material.next_pass = outline
 tool.hide()
 axe = preload("res://scripts/prototype_3d/stone_axe.gd").new(); add_child(axe)
 # Build the unarmed bind mesh once; animation only updates its skeleton.
 build(&"",&"",&"idle",0,4)
 rig.initialize(self,mesh_node)
 core_mesh.hide()
func triangle(a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
 surface.set_smooth_group(0)
 super.triangle(a,b,c,color)
func ellipsoid(center: Vector3,size: Vector3,color: Color,basis: Basis = Basis.IDENTITY) -> void:
 # One continuous torso avoids the necklace-like outlines produced by
 # overlapping chest/abdomen spheres in the original sprite-authoring model.
 if center.is_equal_approx(Vector3(0,35,0)) and size.is_equal_approx(Vector3(6.5,8.5,3)):
  append_torso(); return
 if center.is_equal_approx(Vector3(0,42,0)) or center.is_equal_approx(Vector3(0,48,0)): return
 if center.y>=31 and center.y<=44 and center.z>2 and size.z<1.5:
  return
 super.ellipsoid(center,size,color,basis)
func append_torso() -> void:
 var profile := [Vector3(26.9,6.7,3),Vector3(31,6.4,2.8),Vector3(35,6.5,3),Vector3(39,7.9,3.3),Vector3(42,8.6,3.55),Vector3(44.7,8.1,3.1),Vector3(46.3,5.8,2.5),Vector3(47.5,2.5,1.8),Vector3(49.5,2,1.8)]
 var rings: Array[PackedVector3Array] = []
 for section in profile.size()-1:
  for step in 3:
   var shape: Vector3 = profile[section].lerp(profile[section+1],step/3.0)
   var ring := PackedVector3Array()
   for i in 24:
    var angle := i*TAU/24
    ring.append(Vector3(cos(angle)*shape.y,shape.x,sin(angle)*shape.z))
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
 var center := torso*Vector3(0,55.1,0)
 head_center = center
 ellipsoid(center,Vector3(6.0,7.1,5.1),SKIN,torso.basis)
 ellipsoid(torso*Vector3(0,51.5,1.0),Vector3(4.6,3.3,4.4),SKIN,torso.basis)
 # Short, irregular hair, brown beard and the original blue facial marking.
 ellipsoid(torso*Vector3(0,59,0),Vector3(6.25,4.3,5.25),HAIR,torso.basis)
 ellipsoid(torso*Vector3(0,56.8,-3.0),Vector3(5.6,4.1,3.3),HAIR,torso.basis)
 for i in 9:
  var angle := i*TAU/9
  ellipsoid(torso*Vector3(cos(angle)*4.6,60.8+sin(i*2.7)*0.55,sin(angle)*3.5),Vector3(2.2,2.0,1.8),HAIR.lightened(0.055*(i%3)),torso.basis)
 for side in [-1,1]:
  ellipsoid(torso*Vector3(side*5.85,54.3,0),Vector3(1.0,1.65,1.0),SKIN,torso.basis)
  ellipsoid(torso*Vector3(side*2.3,55.5,4.7),Vector3(1.25,0.7,0.4),Color("eee2ce"),torso.basis)
  ellipsoid(torso*Vector3(side*2.3,55.45,5.02),Vector3(0.48,0.6,0.25),Color("251b16"),torso.basis)
  ellipsoid(torso*Vector3(side*2.3,56.6,4.8),Vector3(1.55,0.35,0.35),HAIR,torso.basis)
 ellipsoid(torso*Vector3(0,54.4,5.0),Vector3(0.9,1.1,1.35),SKIN,torso.basis)
 ellipsoid(torso*Vector3(0,50.8,3.8),Vector3(3.3,2.0,1.35),HAIR,torso.basis)
 ellipsoid(torso*Vector3(0,52.6,4.8),Vector3(2.55,0.48,0.4),HAIR,torso.basis)
 ellipsoid(torso*Vector3(-3.8,54.8,4.2),Vector3(0.35,2.0,0.38),Color("697e87"),torso.basis)
func place_tool(_data: Dictionary, grip: Vector3, shaft: Vector3, actor_basis: Basis, _item: StringName) -> Dictionary:
 var y_axis := (actor_basis*shaft).normalized()
 var x_axis := actor_basis*Vector3.RIGHT
 x_axis = (x_axis-y_axis*y_axis.dot(x_axis)).normalized()
 var z_axis := x_axis.cross(y_axis).normalized()
 axe.basis = Basis(x_axis,y_axis,z_axis)
 axe.position = actor_basis*grip-y_axis*GRIP_HEIGHT
 tool_tip = axe.position+x_axis*9.0+y_axis*25.0
 tool_cutting_axis = x_axis
 return {"grip":grip,"support":grip+shaft*7.25}
func animate(state: StringName, phase: float, equipped: bool, delta: float = 0.0, movement_phase: float = 0.0, movement: Vector3 = Vector3.ZERO) -> void:
 var item: StringName = &"axe" if equipped else &""
 var target := Pose.sample(item,state,phase,movement_phase,1.0,-1)
 # A shoulder camera allows backing up and strafing while facing the reticle.
 # Rotate the foot trajectory in body space rather than playing forward steps.
 if not movement.is_zero_approx() and state not in [&"slide",&"jump",&"slide_jump"]:
  var travel := Vector3(movement.x,0,movement.z).normalized()
  var walk_pose := Pose.sample(item,&"walk",movement_phase) if state==&"action" else target
  for side in 2:
   var ankle: Vector3 = walk_pose.legs[side].end
   var across := -4.4 if side==0 else 4.4
   var stride_scale := lerpf(1.0,0.65,absf(travel.x))
   target.legs[side].end = Vector3(across,ankle.y,0)+travel*ankle.z*stride_scale
   target.legs[side].pitch *= travel.z
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
 last_pose = displayed_pose
 # Re-solve the limbs after blending targets: interpolation must not shorten
 # a thigh or detach a shoulder from the moving torso.
 for side in 2:
  var body: Transform3D = last_pose.body
  last_pose.shoulders[side] = body*Vector3(-7.6 if side==0 else 7.6,45.7,0)
  last_pose.hips[side] = body*Vector3(-4.4 if side==0 else 4.4,26.9,0)
  var foot_pitch: float = last_pose.legs[side].pitch
  last_pose.legs[side] = Pose.joint(last_pose.hips[side],last_pose.legs[side].end,Pose.THIGH,Pose.SHIN,Vector3.BACK)
  last_pose.legs[side].pitch = foot_pitch
 var hands: Array[Vector3] = last_pose.hands.duplicate()
 grip_error = 0
 if equipped:
  var grip: Vector3 = last_pose.grip
  # Project onto the intersection of both arms' reachable volumes.
  for attempt in 24:
   var support: Vector3 = grip+last_pose.shaft*7.25
   for center in [last_pose.shoulders[0],last_pose.shoulders[1]-(support-grip)]:
    if center.distance_to(grip)>18.8: grip = center+center.direction_to(grip)*18.8
    elif center.distance_to(grip)<8.15: grip = center+center.direction_to(grip)*8.15
  var placement := place_tool({},grip,last_pose.shaft,Basis.IDENTITY,item)
  hands[0] = grip; hands[1] = placement.support
  for side in 2:
   var arm := Pose.joint(last_pose.shoulders[side],hands[side],Pose.UPPER_ARM,Pose.FOREARM,Vector3(-0.35 if side==0 else 0.35,-1,0))
   grip_error = maxf(grip_error,arm.end.distance_to(hands[side]))
 rig.apply(last_pose,hands)
 axe.visible = equipped
 tool.hide(); core_mesh.hide()
