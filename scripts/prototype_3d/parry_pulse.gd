extends Node3D
## A gentle white ring at each hand, emitted only on a confirmed parry.
const SECONDS := 0.32
var elapsed := SECONDS
var rings: Array[MeshInstance3D] = []
var paints: Array[StandardMaterial3D] = []
func _ready() -> void:
 for side in 2:
  var ring:=MeshInstance3D.new();var mesh:=TorusMesh.new()
  mesh.inner_radius=1.2;mesh.outer_radius=1.5;mesh.rings=24;mesh.ring_segments=6
  ring.mesh=mesh;ring.rotation.x=PI/2
  var paint:=StandardMaterial3D.new();paint.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  paint.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;paint.albedo_color=Color(1,1,1,0)
  paint.no_depth_test=false;ring.material_override=paint;add_child(ring);rings.append(ring);paints.append(paint)
 hide()
func update_hands(hands: Array) -> void:
 for side in rings.size(): rings[side].position=hands[side]
func play() -> void:
 elapsed=0;show()
func _process(delta: float) -> void:
 if elapsed>=SECONDS: return
 elapsed=minf(SECONDS,elapsed+delta)
 var phase:=elapsed/SECONDS
 for side in rings.size():
  rings[side].scale=Vector3.ONE*lerpf(0.85,2.1,phase)
  paints[side].albedo_color=Color(1,1,1,sin(phase*PI)*0.62)
 if elapsed>=SECONDS:hide()
