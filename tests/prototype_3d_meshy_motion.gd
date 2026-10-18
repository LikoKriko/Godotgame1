extends SceneTree
## Regression coverage for the actual imported feet, fingers and falling skin.

const Clips=preload("res://scripts/prototype_3d/survivor_animation.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();root.add_child(actor)
 var mesh:Mesh=actor.mesh_node.mesh
 var arrays:Array=mesh.surface_get_arrays(0)
 var source_arrays:Array=actor.IMPORTED_SKIN.surface_get_arrays(0)
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
 var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var hashes:=PackedStringArray()
 for i in arrays.size():
  if i in [Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS]:continue
  var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(var_to_bytes(source_arrays[i]));hashes.append(hash.finish().hex_encode())
 require("|".join(hashes).sha256_text()==JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/prototype_3d/meshy/source.json")).runtime_geometry_sha256,"All published source geometry, normals, tangents, UVs and topology remain byte-identical")
 require(preload("res://scripts/prototype_3d/human_skin_weights.gd").correct(source_arrays.duplicate(true))==0,"The baked torso correction is stable when applied again")
 var seeds:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/prototype_3d/meshy/rig_seeds.json"))
 for i in 16:
  var point:Array=seeds[i].a
  require(actor.rig.rest[i].origin.distance_to(Vector3(point[0],point[1],point[2]))<.001,"Bind joints retain the published Meshy heat rig")
 # Coarse coverage of the complete surface, with denser probes on real soles.
 var probes:Array[int]=[];var back:Dictionary={};var scapula:Dictionary={};var upper_arms:Dictionary={};var forearms:Dictionary={};var elbows:Dictionary={}
 for i in vertices.size():
  var point:Vector3=vertices[i]
  # The inner arm at y=41 has x=5.4; it must move with the humerus.
  # Cover the actual ribs plus the previously omitted upper trapezius instead.
  var back_width:=4.65 if point.y<43 else (4.4 if point.y<47 else 3.8)
  if i%7==0 and point.y>40 and point.y<50.8 and absf(point.x)<back_width and point.z<.6:back[i]=true
  if i%7==0 and point.y>46.5 and point.y<50.5 and absf(point.x)>4.4 and absf(point.x)<5.4 and point.z<.2:scapula[i]=true
  if i%23==0 and point.y>40.5 and point.y<42.5 and absf(point.x)>5.35:
   var start:=4 if point.x<0 else 7
   var bind_nearest:=Geometry3D.get_closest_point_to_segment(point,actor.rig.rest[start].origin,actor.rig.rest[start+1].origin)
   upper_arms[i]=[start,point.distance_to(bind_nearest)]
  if i%23==0 and point.y>31.5 and point.y<34 and absf(point.x)>7.2:
   var start:=5 if point.x<0 else 8
   var nearest:=Geometry3D.get_closest_point_to_segment(point,actor.rig.rest[start].origin,actor.rig.rest[start+1].origin)
   forearms[i]=[start,point.distance_to(nearest)]
  if i%23==0 and point.y>37 and point.y<39 and absf(point.x)>6.2:
   var joint:=5 if point.x<0 else 8
   elbows[i]=[joint,point.distance_to(actor.rig.rest[joint].origin)]
  if i%397==0 or (point.y<3 and i%23==0) or back.has(i) or upper_arms.has(i) or forearms.has(i) or elbows.has(i) or scapula.has(i):probes.append(i)
 for family in Clips.FAMILIES:
  actor.family_override=family
  for state in Clips.STATES:
   # E temporarily stows equipment in the actual player path.
   if state in [&"pickup",&"pickup_walk"] and family!=&"":continue
   for frame in 9:
    var phase:=frame/8.0
    actor.aim_contact=Vector3(4,3,20) if state in [&"pickup",&"pickup_walk"] else Vector3(0,38,32)
    var direction:=Vector3(1,0,1).normalized() if state in [&"walk",&"run",&"crouch_walk"] else Vector3.ZERO
    actor.animate(state,phase,family==&"axe",0,phase,direction)
    actor.rig.skeleton.force_update_all_bone_transforms()
    var skeleton_error:=0.0
    for bone in actor.rig.posed.size():
     var actual:Transform3D=actor.rig.skeleton.get_bone_global_pose(bone)
     var expected:Transform3D=actor.rig.posed[bone]
     skeleton_error=maxf(skeleton_error,actual.origin.distance_to(expected.origin))
     for axis in 3:skeleton_error=maxf(skeleton_error,actual.basis[axis].distance_to(expected.basis[axis]))
    require(skeleton_error<.0001,"Skin probes use the same bone transforms as the rendered Skeleton3D")
    var minimum:=INF;var back_error:=0.0;var scapular_extension:=0.0;var arm_expansion:=0.0;var forearm_expansion:=0.0;var elbow_expansion:=0.0
    for index in probes:
     var point:=Vector3.ZERO
     for slot in 4:
      var bone:int=bones[index*4+slot]
      point+=(actor.rig.posed[bone]*(actor.rig.rest[bone].affine_inverse()*vertices[index]))*weights[index*4+slot]
     minimum=minf(minimum,point.y)
     if upper_arms.has(index):
      var start:int=upper_arms[index][0]
      var center:=Geometry3D.get_closest_point_to_segment(point,actor.rig.posed[start].origin,actor.rig.posed[start+1].origin)
      arm_expansion=maxf(arm_expansion,point.distance_to(center)-float(upper_arms[index][1]))
     if forearms.has(index):
      var start:int=forearms[index][0]
      var center:=Geometry3D.get_closest_point_to_segment(point,actor.rig.posed[start].origin,actor.rig.posed[start+1].origin)
      forearm_expansion=maxf(forearm_expansion,point.distance_to(center)-float(forearms[index][1]))
     if elbows.has(index):
      var joint:int=elbows[index][0]
      elbow_expansion=maxf(elbow_expansion,point.distance_to(actor.rig.posed[joint].origin)-float(elbows[index][1]))
     if scapula.has(index):scapular_extension=maxf(scapular_extension,(actor.last_pose.body.affine_inverse()*point).distance_to(vertices[index]))
     if back.has(index):back_error=maxf(back_error,(actor.last_pose.body.affine_inverse()*point).distance_to(vertices[index]))
    # Packed skin precision and the source sole margin allow 3.3 mm at scale.
    require(minimum>=-.12,"Imported skin clears floor: %s / %s / %.3f (%.3f)"%[family,state,phase,minimum])
    require(arm_expansion<.3,"Actual upper-arm skin must retain its original thickness: %s / %s (%.3f)"%[family,state,arm_expansion])
    require(forearm_expansion<.3,"Forearm skin retains its thickness: %s / %s (%.3f)"%[family,state,forearm_expansion])
    require(elbow_expansion<.15,"Elbow skin cannot fan out: %s / %s (%.3f)"%[family,state,elbow_expansion])
    require(scapular_extension<1.0,"Scapular surface follows the chest instead of stretching with the humerus: %s %s (%.3f)"%[family,state,scapular_extension])
    require(back_error<.5,"The shoulder blades remain on the rib cage: %s / %s (%.3f)"%[family,state,back_error])
    if state==&"death":
     require(not actor.axe.visible,"Death releases the axe visual and its grasp constraint")
     for prop in actor.held_props.values():require(not prop.visible,"Death hides the carried prop while the hands settle")
 require(actor.mesh_node.mesh==mesh and mesh==actor.AXILLA_SKIN,"Every action shares the derived axillary surface")
 actor.family_override=&"";actor.aim_contact=Vector3(4,3,20);actor.animate(&"pickup",.5,false)
 require(actor.rig.posed[9].origin.distance_to(actor.aim_contact)<.03,"Wrist rotation clears the fingers without moving the E contact")
 actor.free();print("%s: %d Meshy bind, visible skin support, pickup wrist and death equipment checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
