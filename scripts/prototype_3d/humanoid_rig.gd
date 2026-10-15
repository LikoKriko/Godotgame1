extends RefCounted
## Stable skinned mesh. Poses move bones; topology and surface detail never change.
const Pose = preload("res://scripts/continuous_body_pose.gd")
const SurfaceProfile=preload("res://scripts/prototype_3d/survivor_surface.gd")
const Anatomy = preload("res://scripts/prototype_3d/survivor_anatomy.gd")
const Kinematics=preload("res://scripts/prototype_3d/human_kinematics.gd")
const Clips = preload("res://scripts/prototype_3d/survivor_animation.gd")
var skeleton := Skeleton3D.new()
var rest: Array[Transform3D] = []
var posed: Array[Transform3D] = []
var parents: Array[int] = []
var names: Dictionary = {}
var neutral: Dictionary
var arm_rest: Array[Dictionary] = []
var cloth_angle: Array[float] = [0.0,0.0]
var cloth_velocity: Array[float] = [0.0,0.0]
var previous_leg_angle: Array[float] = [0.0,0.0]
var run_arm_blend:Array[float]=[0.0,0.0]
var relaxed_arm_blend:Array[float]=[0.0,0.0]

func initialize(actor: Node3D, mesh_instance: MeshInstance3D) -> void:
 neutral = Clips.sample(&"",&"idle",0)
 bone("pelvis",-1,Vector3(0,26.9,0))
 bone("chest",0,Vector3(0,41,0))
 bone("neck",1,Vector3(0,48,0))
 bone("head",2,Anatomy.head(Vector3(0,55.1,0)))
 for side in 2:
  var arm:Dictionary = Clips.relaxed_arm(neutral,side)
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
 var arrays: Array = mesh_instance.mesh.surface_get_arrays(0)
 var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
 var authored_vertices:=vertices.duplicate()
 var tags: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
 for i in vertices.size(): vertices[i]=actor.mesh_to_bind(vertices[i],int(tags[i].x),self)
 arrays[Mesh.ARRAY_VERTEX]=vertices
 arrays[Mesh.ARRAY_NORMAL] = sculpted_normals(vertices,arrays[Mesh.ARRAY_COLOR],tags)
 var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
 var texture_uv := PackedVector2Array()
 var projection_tags:=tags.duplicate()
 var reference_data:=PackedFloat32Array()
 var surface_normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
 var indices := PackedInt32Array(); var weights := PackedFloat32Array()
 for i in vertices.size():
  var cloth := colors[i].r<0.61 and colors[i].g<0.39 and vertices[i].y<25
  var blend := bindings(vertices[i],int(tags[i].x),cloth)
  if int(tags[i].x) in [1,2]:
   var arm:Dictionary=arm_rest[int(tags[i].x)-1]
   var along:float=(vertices[i]-arm.root).dot(arm.root.direction_to(arm.joint))
   colors[i].a=smoothstep(1.2,4.0,along)
  texture_uv.append(material_uv(vertices[i],colors[i]))
  # Store BOTH anatomical paintings and a bind-space side blend. Colors are
  # blended after sampling; mirrored UV coordinates must never be interpolated.
  var face:=i-i%3
  var face_height:float=(vertices[face].y+vertices[face+1].y+vertices[face+2].y)/3.0
  var tag:=int(tags[i].x)
  var torso:=tag==0 and colors[face].r>.7 and face_height>=29.4 and face_height<=49.5
  var cloth_surface:=tag==13 or (tag==0 and colors[face].is_equal_approx(Color8(96,77,51)))
  var painted:=torso or cloth_surface or tag in [1,2]
  var front_uv:=texture_uv[-1];var back_uv:=front_uv;var side_blend:=1.0
  if painted:
   var point:Vector3=vertices[i]
   if torso:
    front_uv=SurfaceProfile.torso_uv(point,true);back_uv=SurfaceProfile.torso_uv(point,false)
   elif tag==13:
    front_uv=SurfaceProfile.pelvis_uv(point,true);back_uv=SurfaceProfile.pelvis_uv(point,false)
   elif cloth_surface:
    var coordinate:Vector2=actor.authored_cloth_coordinates.get(authored_vertices[i],Vector2.ZERO)
    var side:=0 if authored_vertices[i].x<0 else 1
    front_uv=SurfaceProfile.leg_cloth_uv(coordinate,side,true);back_uv=SurfaceProfile.leg_cloth_uv(coordinate,side,false)
   else:
    front_uv=SurfaceProfile.limb_uv(point,true);back_uv=SurfaceProfile.limb_uv(point,false)
   side_blend=smoothstep(-0.55,0.55,surface_normals[i].z)
   texture_uv[-1]=front_uv;projection_tags[i].y=1.0
  reference_data.append_array(PackedFloat32Array([back_uv.x,back_uv.y,side_blend,1.0 if cloth_surface else 0.0]))
  if int(tags[i].x)==0 and vertices[i].y>30 and vertices[i].y<45 and colors[i].r>0.7:
   var point: Vector3 = vertices[i]
   var front := smoothstep(0.5,2.5,point.z)
   var sternum := exp(-point.x*point.x/1.5)*exp(-pow(point.y-40,2)/12.0)*0.04
   var chest := exp(-pow(point.y-39,2)/1.5)*(1-exp(-point.x*point.x/3.0))*0.025
   var navel := exp(-point.x*point.x-pow(point.y-32.5,2))*0.07
   colors[i] = colors[i].darkened(front*(sternum+chest+navel))
  for slot in 4:
   indices.append(int(blend[slot*2])); weights.append(float(blend[slot*2+1]))
 arrays[Mesh.ARRAY_BONES] = indices; arrays[Mesh.ARRAY_WEIGHTS] = weights
 arrays[Mesh.ARRAY_TEX_UV2] = texture_uv
 arrays[Mesh.ARRAY_TEX_UV] = projection_tags
 arrays[Mesh.ARRAY_COLOR] = colors
 arrays[Mesh.ARRAY_CUSTOM0]=reference_data
 var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
 mesh_instance.mesh = mesh
 # Animated limbs may extend beyond the standing bounds.
 mesh_instance.custom_aabb = AABB(Vector3(-30,-10,-35),Vector3(60,90,70))

static func smooth_normals(vertices: PackedVector3Array) -> PackedVector3Array:
 # The sprite authoring mesh commits its torso before appending its limbs.
 # Recompute shared-vertex normals once for the final bind surface.
 var sums: Dictionary = {}
 for i in range(0,vertices.size(),3):
  var face := (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i])
  for corner in 3:
   var key: Vector3 = vertices[i+corner].snapped(Vector3.ONE*0.0001)
   sums[key] = sums.get(key,Vector3.ZERO)+face
 var normals := PackedVector3Array()
 for vertex in vertices:
  normals.append((sums[vertex.snapped(Vector3.ONE*0.0001)] as Vector3).normalized())
 return normals

static func sculpted_normals(vertices:PackedVector3Array,colors:PackedColorArray,tags:PackedVector2Array) -> PackedVector3Array:
 var normals:=smooth_normals(vertices)
 for face in range(0,vertices.size(),3):
  var normal:Vector3=(vertices[face+2]-vertices[face]).cross(vertices[face+1]-vertices[face]).normalized()
  for corner in 3:
   var i:=face+corner;var p:=vertices[i];var color:=colors[i];var amount:=0.0
   if int(tags[i].x)==0 and p.y<26:amount=0.58
   elif int(tags[i].x) in [1,2]:amount=0.25
   elif int(tags[i].x)==0 and p.z< -0.5 and p.y>31 and p.y<45:amount=0.6
   elif p.y>42 and p.y<47.2 and absf(p.x)>5.0:amount=0.68
   if int(tags[i].x)==3 and color.r<0.38 and color.g<0.27:amount=0.88
   normals[i]=normals[i].lerp(normal,amount).normalized()
 return normals

func material_uv(vertex: Vector3,color: Color) -> Vector2:
 # UV2 selects a material patch; UV keeps the original anatomical region tag.
 # Coordinates are authored in the bind pose so texture never swims on skin.
 var patch := Vector2.ZERO
 var sample := Vector2(vertex.x*0.055+vertex.z*0.035,vertex.y*0.055)
 if color.b>0.7 or (color.b>color.r*1.1): return Vector2(-1,-1)
 if color.r<0.38 and color.g<0.27:
  patch = Vector2(0,0.5);sample=Vector2(vertex.x*0.07+vertex.z*0.05,vertex.y*0.08)
 elif color.r<0.61 and color.g<0.39 and vertex.y<32:
  patch=Vector2(0.5,0.5) if color.r>0.45 and vertex.y>25.5 else Vector2(0.5,0)
  sample=Vector2(vertex.x*0.08+vertex.z*0.04,vertex.y*0.12)
 # Keep bilinear taps inside each patch, avoiding contamination by its neighbor.
 return patch+Vector2(0.004,0.004)+Vector2(fposmod(sample.x,1),fposmod(sample.y,1))*0.492

func bone(label: String, parent: int, position: Vector3,basis:Basis=Basis.IDENTITY) -> void:
 var index := skeleton.get_bone_count(); skeleton.add_bone(label)
 names[label] = index; parents.append(parent)
 var transform := Transform3D(basis,position)
 rest.append(transform); posed.append(transform)
 if parent >= 0: skeleton.set_bone_parent(index,parent)
 var local := rest[parent].affine_inverse()*transform if parent >= 0 else transform
 skeleton.set_bone_rest(index,local); skeleton.set_bone_pose(index,local)

func pair(a: int,b: int,t: float) -> Array:
 return [a,1-clampf(t,0,1),b,clampf(t,0,1),0,0.0,0,0.0]

func limb_binding(vertex: Vector3,start: int,joints: Dictionary) -> Array:
 var top: Vector3 = joints.root; var middle: Vector3 = joints.joint; var end: Vector3 = joints.end
 var first := Geometry3D.get_closest_point_to_segment(vertex,top,middle)
 var second := Geometry3D.get_closest_point_to_segment(vertex,middle,end)
 var collar:=20+int((start-4)/3.0) if start<10 else 22+int((start-10)/3.0)
 if vertex.distance_squared_to(first) <= vertex.distance_squared_to(second):
  var t := top.distance_to(first)/top.distance_to(middle)
  return pair(start,collar,smoothstep(0.80,1.0,t))
 var t := middle.distance_to(second)/middle.distance_to(end)
 if t < 0.20: return pair(collar,start+1,smoothstep(0,0.20,t))
 return pair(start+1,start+2,smoothstep(0.78,1.0,t))

func bindings(vertex: Vector3,tag: int,cloth: bool = false) -> Array:
 if tag==13:return pair(0,0,0) # Waist/crotch bridge belongs to pelvis, not either thigh.
 if tag in [1,2]:
  var side:=tag-1;var arm:Dictionary=arm_rest[side];var start:=4+side*3
  var along:=clampf((vertex-arm.root).dot((arm.joint-arm.root).normalized()),0,Pose.UPPER_ARM)
  if along<2.5:return pair(1,start,smoothstep(0.0,2.5,along))
  return limb_binding(vertex,start,arm)
 if tag in [5,6]:return pair(6+(tag-5)*3,6+(tag-5)*3,0)
 if tag==3: return pair(3,3,0)
 if vertex.y < 26.0:
  var side := 0 if vertex.x < 0 else 1
  if vertex.y<4: return pair(12+side*3,12+side*3,0)
  if cloth:
   var panel := 0 if vertex.z>=0 else 1
   return pair(10+side*3,16+side*2+panel,(1-smoothstep(22,25,vertex.y))*0.65)
  var result := limb_binding(vertex,10+side*3,neutral.legs[side])
  if vertex.y > 23:
   var pelvis_weight := smoothstep(23,26,vertex.y)
   return pair(10+side*3,0,pelvis_weight)
  return result
 if vertex.y >= 49.0: return pair(3,3,0)
 if vertex.y > 45: return pair(1,2,smoothstep(45,48,vertex.y))
 return pair(0,1,smoothstep(28,40,vertex.y))

func orient_limb(start:int,chain:Dictionary,bind_chain:Dictionary) -> void:
 # A shortest-arc quaternion alone loses the hinge plane and flips limb roll.
 for segment in 2:
  var rotation:=Kinematics.segment_frame(chain,segment)*Kinematics.segment_frame(bind_chain,segment).inverse()
  posed[start+segment]=Transform3D(rotation,chain.root if segment==0 else chain.joint)

func hinge_collar(index:int,chain:Dictionary,bind_chain:Dictionary) -> void:
 var current:Vector3=(chain.joint-chain.root).normalized()+(chain.end-chain.joint).normalized()
 var original:Vector3=(bind_chain.joint-bind_chain.root).normalized()+(bind_chain.end-bind_chain.joint).normalized()
 var rotation:=Kinematics.frame(current,Kinematics.plane(chain))*Kinematics.frame(original,Kinematics.plane(bind_chain)).inverse()
 posed[index]=Transform3D(rotation,chain.joint)

func apply(pose: Dictionary,hands: Array[Vector3],delta: float = 0.0) -> void:
 var torso: Transform3D = pose.body
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
 posed[3] = Transform3D(skull_basis,neck+skull_basis*(rest[3].origin-Anatomy.HEAD_ANCHOR))
 for side in 2:
  var clip:StringName=pose.get("clip_state",&"idle")
  var swinging:=Clips.arm_is_free(pose,side) and clip in [&"idle",&"walk",&"run",&"start",&"stop",&"start_run",&"stop_run",&"crouch",&"crouch_walk"]
  var arm := Kinematics.arm(pose.shoulders[side],hands[side],torso.basis,side,swinging)
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
   var amount:float=run_arm_blend[side]
   var upper:Vector3=(arm.joint-arm.root).normalized().lerp((running_pose.joint-running_pose.root).normalized(),amount).normalized()
   var forearm:Vector3=(arm.end-arm.joint).normalized().lerp((running_pose.end-running_pose.joint).normalized(),amount).normalized()
   arm.joint=arm.root+upper*Pose.UPPER_ARM;arm.end=arm.joint+forearm*Pose.FOREARM
  var start := 4+side*3
  orient_limb(start,arm,arm_rest[side])
  hinge_collar(20+side,arm,arm_rest[side])
  posed[start+2] = Transform3D(Kinematics.hand_frame(arm,torso.basis,side,not swinging),arm.end)
  if pose.get("family",&"")==&"" and pose.get("clip_state")==&"action":
   var close_fist:=sin(clampf(float(pose.phase),0,1)*PI)
   posed[start+2].basis=posed[start+2].basis*Basis.from_scale(Vector3(1+0.1*close_fist,1-0.12*close_fist,1+0.1*close_fist))
  var leg: Dictionary = pose.legs[side]; start = 10+side*3
  orient_limb(start,leg,neutral.legs[side])
  hinge_collar(22+side,leg,neutral.legs[side])
  posed[start+2] = Transform3D(torso.basis if pose.state==&"death" else Basis(Vector3.RIGHT,leg.pitch),leg.end)
  var leg_angle := atan2((leg.joint-leg.root).z,-(leg.joint-leg.root).y)
  if delta>0:
   var d:=minf(delta,0.033)
   var angular_speed:=wrapf(leg_angle-previous_leg_angle[side],-PI,PI)/maxf(delta,0.001)
   cloth_velocity[side]+=(-cloth_angle[side]*80-cloth_velocity[side]*15-angular_speed*0.7)*d
   cloth_angle[side]=clampf(cloth_angle[side]+cloth_velocity[side]*d,-0.09,0.09)
  else: cloth_angle[side]=0;cloth_velocity[side]=0
  previous_leg_angle[side]=leg_angle
  for panel in 2:
   var index:=16+side*2+panel
   var origin: Vector3=leg.root+posed[10+side*3].basis*(rest[index].origin-rest[10+side*3].origin)
   posed[index]=Transform3D(posed[10+side*3].basis*Basis(Vector3.RIGHT,cloth_angle[side]*(1 if panel==0 else 0.7)),origin)
 for i in posed.size():
  var parent := parents[i]
  skeleton.set_bone_pose(i,posed[parent].affine_inverse()*posed[i] if parent >= 0 else posed[i])
