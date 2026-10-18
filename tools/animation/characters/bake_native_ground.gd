extends SceneTree
## Capture actual native skin supports, across all three composite surfaces.
func _initialize():call_deferred("run")
func run():
 var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();root.add_child(actor);actor.native.ground_enabled=false
 var surfaces:Array=[];var mesh:Mesh=actor.mesh_node.mesh;var skin:Skin=actor.mesh_node.skin
 for s in mesh.get_surface_count():surfaces.append(mesh.surface_get_arrays(s))
 var selected:Dictionary={}
 var entries:Array=load("res://scripts/prototype_3d/survivor_animation.gd").SLIDE_STATES.duplicate();entries.append_array([&"idle",&"run",&"crouch"])
 for entry in entries:
  actor.family_override=&"";actor.animate(entry,.43,false)
  for frame in 41:
   actor.animate(&"death",frame/40.0,false,1.0/60.0)
   var matrices:Array[Transform3D]=[]
   for bind in skin.get_bind_count():matrices.append(actor.native.posed[skin.get_bind_bone(bind)]*skin.get_bind_pose(bind))
   var low:=INF;var winner:=Vector2i.ZERO
   for surface in surfaces.size():
    var arrays:Array=surfaces[surface];var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var ids:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var slots:int=ids.size()/points.size()
    for i in points.size():
     var point:=Vector3.ZERO
     for slot in slots:
      if weights[i*slots+slot]>0:point+=(matrices[ids[i*slots+slot]]*points[i])*weights[i*slots+slot]
     if point.y<low:low=point.y;winner=Vector2i(surface,i)
   selected[winner]=true
  print("Native supports captured: ",entry)
 var neighbors:=selected.duplicate()
 for surface in surfaces.size():
  var indices:PackedInt32Array=surfaces[surface][Mesh.ARRAY_INDEX]
  for triangle in range(0,indices.size(),3):
   if selected.has(Vector2i(surface,indices[triangle])) or selected.has(Vector2i(surface,indices[triangle+1])) or selected.has(Vector2i(surface,indices[triangle+2])):
    for slot in 3:neighbors[Vector2i(surface,indices[triangle+slot])]=true
 var profile:=Resource.new();profile.set_meta("vertices",neighbors.keys())
 assert(ResourceSaver.save(profile,"res://assets/characters/prototype_3d/composite/ground_supports.tres")==OK)
 print("Baked ",neighbors.size()," native skin supports")
 actor.free();quit()
