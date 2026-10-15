extends SceneTree
## Tests the rendered skin (CPU skinning), not just reachable hand/foot targets.
const Clips=preload("res://scripts/prototype_3d/survivor_animation.gd")
const Kinematics=preload("res://scripts/prototype_3d/human_kinematics.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func deform(point:Vector3,ids:PackedInt32Array,weights:PackedFloat32Array,index:int,rig:RefCounted) -> Vector3:
 var result:=Vector3.ZERO
 for slot in 4:
  var bone:int=ids[index*4+slot]
  result+=(rig.posed[bone]*(rig.rest[bone].affine_inverse()*point))*weights[index*4+slot]
 return result
func run():
 var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();root.add_child(actor)
 var arrays:Array=actor.mesh_node.mesh.surface_get_arrays(0)
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var ids:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
 var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var probes:Array=[]
 for collar in range(20,24):
  var selected:Array[int]=[]
  for i in vertices.size():
   var weight:=0.0
   for j in 4:
    if ids[i*4+j]==collar:weight+=weights[i*4+j]
   if weight>0.90 and selected.size()<24:selected.append(i)
  require(selected.size()>=8,"Every elbow/knee has a real weighted skin ring")
  probes.append(selected)
 actor.family_override=&"";actor.animate(&"idle",0,false)
 var rest_error:=0.0
 for i in range(0,vertices.size(),17):rest_error=maxf(rest_error,vertices[i].distance_to(deform(vertices[i],ids,weights,i,actor.rig)))
 require(rest_error<0.003,"Mesh and skeleton share the neutral bind pose within packed skin-weight precision")
 for family in Clips.FAMILIES:
  actor.family_override=family
  for state in Clips.STATES:
   var previous:Array=[]
   for frame in 33:
    var phase:=frame/32.0
    actor.aim_contact=Vector3(0,38,40);actor.animate(state,phase,family==&"axe",0,phase)
    for side in 2:
     var root:Vector3=actor.rig.posed[4+side*3].origin
     var elbow:Vector3=actor.rig.posed[5+side*3].origin
     var hand:Vector3=actor.rig.posed[6+side*3].origin
     var angle:=rad_to_deg((root-elbow).angle_to(hand-elbow))
     require(angle>=49.9 and angle<=180.0,"Elbows cannot reverse or flex beyond the authored anatomical limit")
     require(absf(root.distance_to(elbow)-10)<0.001 and absf(elbow.distance_to(hand)-9)<0.001,"All actions preserve humerus/forearm lengths")
    for collar in range(20,24):
     var minimum:=1.0
     for index:int in probes[collar-20]:
      var bind_local:Vector3=actor.rig.rest[collar].affine_inverse()*vertices[index]
      var posed_local:Vector3=actor.rig.posed[collar].affine_inverse()*deform(vertices[index],ids,weights,index,actor.rig)
      if bind_local.length()>0.1:minimum=minf(minimum,posed_local.length()/bind_local.length())
     require(minimum>0.70,"Strong flexion retains at least 70% of hinge skin radius")
    var current:Array=[]
    for bone in [4,5,6,7,8,9,10,11,13,14]:
     var basis:Basis=actor.rig.posed[bone].basis
     require(basis.determinant()>0.8 and basis.determinant()<1.2,"Joint roll never becomes a reflection or collapses")
     current.append(basis.orthonormalized())
    # Exclude the intentional phase-end reset of nonlooping actions.
    if not previous.is_empty() and frame<32:
     var maximum:=0.0
     for i in current.size():maximum=maxf(maximum,previous[i].get_rotation_quaternion().angle_to(current[i].get_rotation_quaternion()))
     require(maximum<0.8,"Pose rotation discontinuity: %s / %s / frame %d, %.1f degrees"%[family,state,frame,rad_to_deg(maximum)])
    previous=current
 actor.free();print("%s: %d human bind, skin-volume, hinge and pose-continuity checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
