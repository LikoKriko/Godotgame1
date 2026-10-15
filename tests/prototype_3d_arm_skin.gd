extends SceneTree
## Check interpolated runtime UVs against the actual front/back paintings.
## The photographed silhouette must never become a dark stripe on arm skin.
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();root.add_child(actor)
 var arrays:Array=actor.mesh_node.mesh.surface_get_arrays(0)
 var tags:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
 var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
 var rear:PackedFloat32Array=arrays[Mesh.ARRAY_CUSTOM0]
 var photos:Array[Image]=[actor.FRONT_REFERENCE.get_image(),actor.BACK_REFERENCE.get_image()]
 var samples:=0;var dark:=0
 for face in range(0,tags.size(),3):
  if int(tags[face].x) not in [1,2]:continue
  for side in 2:
   var coordinates:Array[Vector2]=[]
   for corner in 3:
    var i:=face+corner
    coordinates.append(uv[i] if side==0 else Vector2(rear[i*4],rear[i*4+1]))
   for bary:Vector3 in [Vector3.ONE/3,Vector3(.8,.1,.1),Vector3(.1,.8,.1),Vector3(.1,.1,.8)]:
    var point:=coordinates[0]*bary.x+coordinates[1]*bary.y+coordinates[2]*bary.z
    # Reproduce the pixel quantization used by skin.gdshader, not just UV corners.
    var pixel:=Vector2i(int(floor(point.x*1086/2))*2+1,int(floor(point.y*1448/2))*2+1)
    var color:=photos[side].get_pixelv(pixel)
    samples+=1
    if color.r<0.32 or color.r<color.g*1.06 or color.r<color.b*1.20:dark+=1
 checks+=1
 if samples<1000 or dark>0:
  failures+=1;push_error("Arm paint samples include %d dark/neutral border pixels out of %d"%[dark,samples])
 actor.free()
 print("%s: %d checks, %d front/back arm skin samples, %d border pixels"%["PASS" if failures==0 else "FAIL",checks,samples,dark])
 quit(1 if failures else 0)
