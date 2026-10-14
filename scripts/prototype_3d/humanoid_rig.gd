extends RefCounted
## Stable skinned mesh. Poses move bones; topology and surface detail never change.
const Pose = preload("res://scripts/continuous_body_pose.gd")
var skeleton := Skeleton3D.new()
var rest: Array[Transform3D] = []
var posed: Array[Transform3D] = []
var parents: Array[int] = []
var names: Dictionary = {}
var neutral: Dictionary
var arm_rest: Array[Dictionary] = []

func initialize(actor: Node3D, mesh_instance: MeshInstance3D) -> void:
 neutral = Pose.sample(&"",&"idle",0)
 bone("pelvis",-1,Vector3(0,26.9,0))
 bone("chest",0,Vector3(0,41,0))
 bone("neck",1,Vector3(0,48,0))
 bone("head",2,Vector3(0,55.1,0))
 for side in 2:
  var arm := Pose.joint(neutral.shoulders[side],neutral.hands[side],Pose.UPPER_ARM,Pose.FOREARM,Vector3(-0.35 if side==0 else 0.35,-1,0))
  arm_rest.append(arm)
  var start := rest.size()
  bone("upper_arm_%d"%side,1,arm.root)
  bone("forearm_%d"%side,start,arm.joint)
  bone("hand_%d"%side,start+1,arm.end)
 for side in 2:
  var leg: Dictionary = neutral.legs[side]
  var start := rest.size()
  bone("thigh_%d"%side,0,leg.root)
  bone("shin_%d"%side,start,leg.joint)
  bone("foot_%d"%side,start+1,leg.end)
 actor.add_child(skeleton)
 mesh_instance.reparent(skeleton)
 mesh_instance.skeleton = NodePath("..")
 var skin := Skin.new()
 for i in rest.size(): skin.add_bind(i,rest[i].affine_inverse())
 mesh_instance.skin = skin
 var arrays: Array = mesh_instance.mesh.surface_get_arrays(0)
 var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
 arrays[Mesh.ARRAY_NORMAL] = smooth_normals(vertices)
 var tags: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
 var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
 var texture_uv := PackedVector2Array()
 var indices := PackedInt32Array(); var weights := PackedFloat32Array()
 for i in vertices.size():
  var blend := bindings(vertices[i],int(tags[i].x))
  texture_uv.append(material_uv(vertices[i],colors[i]))
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
 arrays[Mesh.ARRAY_COLOR] = colors
 var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 mesh_instance.mesh = mesh
 # Animated limbs may extend beyond the standing bounds.
 mesh_instance.custom_aabb = AABB(Vector3(-30,-10,-35),Vector3(60,90,70))

func smooth_normals(vertices: PackedVector3Array) -> PackedVector3Array:
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

func bone(label: String, parent: int, position: Vector3) -> void:
 var index := skeleton.get_bone_count(); skeleton.add_bone(label)
 names[label] = index; parents.append(parent)
 var transform := Transform3D(Basis.IDENTITY,position)
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
 if vertex.distance_squared_to(first) <= vertex.distance_squared_to(second):
  var t := top.distance_to(first)/top.distance_to(middle)
  return pair(start,start+1,smoothstep(0.7,1.0,t)*0.5)
 var t := middle.distance_to(second)/middle.distance_to(end)
 if t < 0.3: return pair(start,start+1,0.5+0.5*smoothstep(0,0.3,t))
 return pair(start+1,start+2,smoothstep(0.78,1.0,t))

func bindings(vertex: Vector3,tag: int) -> Array:
 if tag in [1,2]: return limb_binding(vertex,4+(tag-1)*3,arm_rest[tag-1])
 if vertex.y < 26.0:
  var side := 0 if vertex.x < 0 else 1
  var result := limb_binding(vertex,10+side*3,neutral.legs[side])
  if vertex.y > 23:
   var pelvis_weight := smoothstep(23,26,vertex.y)
   return pair(10+side*3,0,pelvis_weight)
  return result
 if vertex.y >= 49.0: return pair(3,3,0)
 if vertex.y > 45: return pair(1,2,smoothstep(45,48,vertex.y))
 return pair(0,1,smoothstep(28,40,vertex.y))

func orient(index: int,root: Vector3,end: Vector3,rest_end: Vector3) -> void:
 var original := rest[index].origin.direction_to(rest_end)
 var current := root.direction_to(end)
 posed[index] = Transform3D(Basis(Quaternion(original,current)),root)

func apply(pose: Dictionary,hands: Array[Vector3]) -> void:
 var torso: Transform3D = pose.body
 for i in 3: posed[i] = Transform3D(torso.basis,torso*rest[i].origin)
 # The skull stays attached to the neck, with only a small counter-rotation.
 var skull_basis := Basis.IDENTITY.slerp(torso.basis,0.2)
 var neck: Vector3 = torso*Vector3(0,48.5,0)
 posed[3] = Transform3D(skull_basis,neck+skull_basis*Vector3(0,6.6,0))
 for side in 2:
  var arm := Pose.joint(pose.shoulders[side],hands[side],Pose.UPPER_ARM,Pose.FOREARM,Vector3(-0.35 if side==0 else 0.35,-1,0))
  var start := 4+side*3
  orient(start,arm.root,arm.joint,arm_rest[side].joint)
  orient(start+1,arm.joint,arm.end,arm_rest[side].end)
  posed[start+2] = Transform3D(posed[start+1].basis,arm.end)
  var leg: Dictionary = pose.legs[side]; start = 10+side*3
  orient(start,leg.root,leg.joint,neutral.legs[side].joint)
  orient(start+1,leg.joint,leg.end,neutral.legs[side].end)
  posed[start+2] = Transform3D(Basis(Vector3.RIGHT,leg.pitch),leg.end)
 for i in posed.size():
  var parent := parents[i]
  skeleton.set_bone_pose(i,posed[parent].affine_inverse()*posed[i] if parent >= 0 else posed[i])
