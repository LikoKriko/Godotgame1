extends SceneTree
## Inspect all visible skin vertices, including toes and knees between keys.
const Clips=preload("res://scripts/prototype_3d/survivor_animation.gd")
var failures:=0
var checks:=0
var vertices:PackedVector3Array
var bones:PackedInt32Array
var weights:PackedFloat32Array
func require(value:bool,message:String):
 checks+=1
 if not value:
  failures+=1
  if failures<15:push_error(message)
func _initialize():call_deferred("run")
func floor_height(actor) -> float:
 var matrices:Array[Transform3D]=[]
 for bone in actor.rig.posed.size():matrices.append(actor.rig.posed[bone]*actor.rig.rest[bone].affine_inverse())
 var low:=INF
 for i in vertices.size():
  var point:=Vector3.ZERO
  for slot in 4:point+=(matrices[bones[i*4+slot]]*vertices[i])*weights[i*4+slot]
  low=minf(low,point.y)
 return low
func anatomy(actor):
 for side in 2:
  var arm:=4+side*3;var leg:=10+side*3
  require(absf(actor.rig.posed[arm].origin.distance_to(actor.rig.posed[arm+1].origin)-10)<.0001,"Humerus never stretches")
  require(absf(actor.rig.posed[arm+1].origin.distance_to(actor.rig.posed[arm+2].origin)-9)<.0001,"Forearm never stretches")
  for bone in [leg,leg+1]:require(absf(actor.rig.posed[bone].origin.distance_to(actor.rig.posed[bone+1].origin)-14.5)<.0001,"Thigh and shin never stretch")
 for bone in [2,3]:require(absf(actor.rig.posed[bone].origin.distance_to(actor.rig.posed[bone-1].origin)-actor.rig.rest[bone].origin.distance_to(actor.rig.rest[bone-1].origin))<.0001,"Neck/head remain attached at the original length")
func run():
 var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();root.add_child(actor)
 var arrays:Array=actor.mesh_node.mesh.surface_get_arrays(0);vertices=arrays[Mesh.ARRAY_VERTEX];bones=arrays[Mesh.ARRAY_BONES];weights=arrays[Mesh.ARRAY_WEIGHTS]
 var worst:=INF
 for state in Clips.SLIDE_STATES+[&"death"]:
  for frame in 61:
   actor.animate(state,frame/60.0,false)
   anatomy(actor)
   var low:=floor_height(actor);worst=minf(worst,low)
   require(low>-.08,"Complete skin clears the floor: %s %.3f %.5f"%[state,frame/60.0,low])
 for state in Clips.SLIDE_STATES+[&"run",&"crouch"]:
  actor.animate(state,.43,false)
  for frame in 37:
   actor.animate(&"death",frame/36.0,false,1.0/60)
   anatomy(actor)
   var low:=floor_height(actor);worst=minf(worst,low)
   require(low>-.10,"Interrupted prone fall clears the floor: %s %d %.5f"%[state,frame,low])
 actor.free();print("%s: %d full-skin floor and fixed anatomy checks; minimum %.6f author units"%["PASS" if failures==0 else "FAIL",checks,worst]);quit(1 if failures else 0)
