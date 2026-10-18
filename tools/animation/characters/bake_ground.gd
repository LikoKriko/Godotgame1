extends SceneTree
func _initialize():call_deferred("run")
func run():
 var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();root.add_child(actor);actor.ground_enabled=false
 var arrays:Array=actor.mesh_node.mesh.surface_get_arrays(0);var v:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var ids:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var w:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var chosen:Dictionary={}
 var entries:Array=load("res://scripts/prototype_3d/survivor_animation.gd").SLIDE_STATES.duplicate()
 entries.append_array([&"idle",&"run",&"crouch",&"action"])
 for entry in entries:
  actor.family_override=&"sword" if entry==&"action" else &""
  actor.animate(entry,.43,false);actor.family_override=&""
  for frame in 121:
   actor.animate(&"death",frame*.005 if frame<=60 else .3+(frame-60)/60.0*.7,false,1.0/60 if entry!=&"idle" else 0.0)
   var matrices:Array[Transform3D]=[]
   for bone in actor.rig.posed.size():matrices.append(actor.rig.posed[bone]*actor.rig.rest[bone].affine_inverse())
   var low:=INF;var index:=0
   for i in v.size():
    var point:=Vector3.ZERO
    for slot in 4:point+=(matrices[ids[i*4+slot]]*v[i])*w[i*4+slot]
    if point.y<low:low=point.y;index=i
   chosen[index]=true
  print("Supports captured: ",entry)
 # Keep the neighbouring source vertices too, so small phase/frame-rate
 # differences cannot move the true support to an unrepresented triangle.
 var selected:=chosen.duplicate()
 var triangles:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 for triangle in range(0,triangles.size(),3):
  if chosen.has(triangles[triangle]) or chosen.has(triangles[triangle+1]) or chosen.has(triangles[triangle+2]):
   for corner in 3:selected[triangles[triangle+corner]]=true
 chosen=selected
 var vertices:=chosen.keys();vertices.sort()
 var profile:=Resource.new();profile.set_meta("vertices",PackedInt32Array(vertices))
 assert(ResourceSaver.save(profile,"res://assets/characters/prototype_3d/motion/ground_supports.res",ResourceSaver.FLAG_COMPRESS)==OK)
 print("Baked ",vertices.size()," actual skin supports")
 actor.free();quit()
