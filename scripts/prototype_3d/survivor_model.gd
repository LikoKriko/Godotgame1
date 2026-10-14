extends "res://tools/continuous_actor.gd"
## Real surfaces replace the authoring billboard skull and flat tool. The body,
## shorts and anatomical IK remain the same continuous authoring geometry.
const HAIR := Color8(66,43,30)
const GRIP_HEIGHT := 4.0
var axe: Node3D
var solid_material: ShaderMaterial
var cached_poses: Dictionary = {}
var cache_order: Array[String] = []
func _ready() -> void:
 super._ready()
 pose_direction_override = -1
 body_material.shader = preload("res://shaders/prototype_3d/skin.gdshader")
 var outline := ShaderMaterial.new(); outline.shader = preload("res://shaders/prototype_3d/outline.gdshader")
 body_material.next_pass = outline
 tool.hide()
 axe = preload("res://scripts/prototype_3d/stone_axe.gd").new(); add_child(axe)
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
func animate(state: StringName, phase: float, equipped: bool) -> void:
 var item: StringName = &"axe" if equipped else &""
 var frames := 48 if state in [&"walk",&"run"] else 32
 var frame := mini(frames-1,floori(clampf(phase,0,1)*frames))
 var key := "%s:%s:%d" % [item,state,frame]
 if not cached_poses.has(key):
  build(item,item,state,frame/float(frames-1),4)
  cached_poses[key] = {"mesh":mesh_node.mesh,"pose":last_pose.duplicate(true),"axe_transform":axe.transform,"error":grip_error}
 if key in cache_order: cache_order.erase(key)
 cache_order.append(key)
 while cache_order.size() > 64: cached_poses.erase(cache_order.pop_front())
 var sample: Dictionary = cached_poses[key]
 mesh_node.mesh = sample.mesh; mesh_node.basis = Basis.IDENTITY
 last_pose = sample.pose; grip_error = sample.error
 axe.transform = sample.axe_transform; axe.visible = equipped
 tool.hide(); core_mesh.hide()
