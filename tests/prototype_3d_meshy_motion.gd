extends SceneTree
## Regression coverage for the actual imported feet, fingers and falling skin.
const GEOMETRY_HASH="00142f59b7ca696b2906b5c581e141e03d153618c3e245d7de2364045a19cbca"
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
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
 var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var hashes:=PackedStringArray()
 for i in arrays.size():
  if i in [Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS]:continue
  var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(var_to_bytes(arrays[i]));hashes.append(hash.finish().hex_encode())
 require("|".join(hashes).sha256_text()==GEOMETRY_HASH,"All published source geometry, normals, tangents, UVs and topology remain byte-identical")
 require(preload("res://scripts/prototype_3d/human_skin_weights.gd").correct(arrays.duplicate(true))==0,"The baked torso correction is stable when applied again")
 var seeds:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/prototype_3d/meshy/rig_seeds.json"))
 for i in 16:
  var point:Array=seeds[i].a
  require(actor.rig.rest[i].origin.distance_to(Vector3(point[0],point[1],point[2]))<.001,"Bind joints retain the published Meshy heat rig")
 # Coarse coverage of the complete surface, with denser probes on real soles.
 var probes:Array[int]=[];var back:Dictionary={}
 for i in vertices.size():
  var point:Vector3=vertices[i]
  if i%7==0 and point.y>40 and point.y<49 and absf(point.x)<5.8 and point.z<.6:back[i]=true
  if i%397==0 or (point.y<3 and i%23==0) or back.has(i):probes.append(i)
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
    var minimum:=INF;var back_error:=0.0
    for index in probes:
     var point:=Vector3.ZERO
     for slot in 4:
      var bone:int=bones[index*4+slot]
      point+=(actor.rig.posed[bone]*(actor.rig.rest[bone].affine_inverse()*vertices[index]))*weights[index*4+slot]
     minimum=minf(minimum,point.y)
     if back.has(index):back_error=maxf(back_error,(actor.last_pose.body.affine_inverse()*point).distance_to(vertices[index]))
    # Packed skin precision and the source sole margin allow 3.3 mm at scale.
    require(minimum>=-.12,"Imported skin clears floor: %s / %s / %.3f (%.3f)"%[family,state,phase,minimum])
    require(back_error<.5,"The shoulder blades remain on the rib cage: %s / %s (%.3f)"%[family,state,back_error])
    if state==&"death":
     require(not actor.axe.visible,"Death releases the axe visual and its grasp constraint")
     for prop in actor.held_props.values():require(not prop.visible,"Death hides the carried prop while the hands settle")
 require(actor.mesh_node.mesh==mesh and mesh==load("res://assets/characters/prototype_3d/meshy/survivor_skin.res"),"Every action reuses the published original Meshy resource")
 actor.family_override=&"";actor.aim_contact=Vector3(4,3,20);actor.animate(&"pickup",.5,false)
 require(actor.rig.posed[9].origin.distance_to(actor.aim_contact)<.03,"Wrist rotation clears the fingers without moving the E contact")
 actor.free();print("%s: %d Meshy bind, visible skin support, pickup wrist and death equipment checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
