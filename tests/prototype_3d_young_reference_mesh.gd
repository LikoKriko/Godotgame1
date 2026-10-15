extends SceneTree
## Inspect the actual skinned surface, material projections and all creature
## actions. Artistic identity is assessed with the four-view comparison sheet.
const Model=preload("res://scripts/prototype_3d/young_model.gd")
const Motion=preload("res://scripts/prototype_3d/young_pose.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func deform(point:Vector3,index:int,ids:PackedInt32Array,weights:PackedFloat32Array,actor:Node3D) -> Vector3:
 var result:=Vector3.ZERO
 for slot in 4:
  var bone:int=ids[index*4+slot]
  result+=(actor.posed[bone]*(actor.rest[bone].affine_inverse()*point))*weights[index*4+slot]
 return result
func run() -> void:
 var actor:=Model.new();root.add_child(actor)
 var second:=Model.new();root.add_child(second)
 require(actor.mesh_node.mesh==second.mesh_node.mesh,"Repeated enemies share the detailed bind mesh, not duplicate fur geometry")
 require(actor.skeleton!=second.skeleton,"Shared geometry cannot couple the poses of separate enemies")
 var mesh:Mesh=actor.mesh_node.mesh
 var data:Array=mesh.surface_get_arrays(0)
 var vertices:PackedVector3Array=data[Mesh.ARRAY_VERTEX]
 var ids:PackedInt32Array=data[Mesh.ARRAY_BONES]
 var weights:PackedFloat32Array=data[Mesh.ARRAY_WEIGHTS]
 var tags:PackedVector2Array=data[Mesh.ARRAY_TEX_UV]
 var front_back:PackedFloat32Array=data[Mesh.ARRAY_CUSTOM0]
 var sides:PackedFloat32Array=data[Mesh.ARRAY_CUSTOM1]
 var blends:PackedFloat32Array=data[Mesh.ARRAY_CUSTOM2]
 require(front_back.size()==vertices.size()*4 and sides.size()==front_back.size() and blends.size()==front_back.size(),"Four paintings and bind-space blend weights cover every vertex")
 var valid:=true;var texture_valid:=true
 var regions:Dictionary={};var probes:Array[int]=[]
 for i in vertices.size():
  var sum:=0.0;var paint_sum:=0.0
  valid=valid and vertices[i].is_finite()
  for slot in 4:
   var index:=i*4+slot
   sum+=weights[index];paint_sum+=blends[index]
   valid=valid and ids[index]>=0 and ids[index]<14 and weights[index]>=0
   texture_valid=texture_valid and is_finite(front_back[index]) and is_finite(sides[index]) and blends[index]>=0
  valid=valid and absf(sum-1)<0.0001
  texture_valid=texture_valid and paint_sum<=1.0001
  var part:=int(tags[i].x)
  regions[part]=regions.get(part,0)+1
  if i%251==0:probes.append(i)
 require(valid,"Every detailed vertex has finite position and normalized, valid skeletal bindings")
 require(texture_valid,"Paintings remain finite and blended without negative or amplified weights")
 require(regions.size()==10,"Head, torso, both arms/legs, both paws and fists all have deformable geometry")
 var bounds:=mesh.get_aabb()
 require(bounds.position.y>=-0.0001,"Bind-pose fur and paw volumes cannot protrude below the ground plane")
 # Front sheet measures approximately 454 px wide by 385 px high.
 require(absf(bounds.size.x/bounds.size.y-454.0/385.0)<0.06,"Whole-body width/height follows the front reference silhouette")
 actor.animate(&"attack",0,true)
 var rest_error:=0.0
 for index in probes:rest_error=maxf(rest_error,vertices[index].distance_to(deform(vertices[index],index,ids,weights,actor)))
 require(rest_error<0.001,"The four-view reference stance is also the neutral skin bind pose")
 # Inspect deformed torso/head envelopes: a bind-pose-only ratio missed the
 # oversized hump caused by the old quadruped lean.
 for state in [&"idle",&"walk",&"run"]:
  for frame in 9:
   actor.animate(state,frame/8.0,true)
   var envelopes:Array[AABB]=[AABB(),AABB()]
   var started:=[false,false]
   for index in probes:
    var part:=int(tags[index].x)
    if part>1:continue
    var point:=deform(vertices[index],index,ids,weights,actor)
    if not started[part]:envelopes[part]=AABB(point,Vector3.ZERO);started[part]=true
    else:envelopes[part]=envelopes[part].expand(point)
   require(envelopes[0].end.y<envelopes[1].end.y-1.0,"The quadruped back stays below the head rather than forming a giant hump")
   require(envelopes[0].size.x<envelopes[1].size.x*0.9,"The torso remains narrower than the cheek/head silhouette")
   require(envelopes[0].size.z<envelopes[1].size.z*1.15,"The posed torso does not dominate the side silhouette")
 var first_second:Transform3D=second.skeleton.get_bone_pose(0)
 for state in preload("res://scripts/prototype_3d/animation_review.gd").YOUNG_STATES:
  for left in [false,true]:
   for frame in 17:
    actor.animate(state,frame/16.0,left)
    var skin_valid:=true
    for index in probes:
     var p:=deform(vertices[index],index,ids,weights,actor)
     skin_valid=skin_valid and p.is_finite() and p.length()<90
    require(skin_valid,"Detailed skin remains finite and attached in %s / %s / %d"%[state,left,frame])
    for side in 2:
     var arm:=8+side*3
     require(absf(actor.posed[arm].origin.distance_to(actor.posed[arm+1].origin)-Motion.ARM_A)<0.001,"The reconstructed arm retains its upper bone length")
     require(absf(actor.posed[arm+1].origin.distance_to(actor.posed[arm+2].origin)-Motion.ARM_B)<0.001,"The reconstructed arm retains its lower bone length")
 require(actor.mesh_node.mesh==mesh,"Animations never rebuild the detailed fur mesh")
 require(second.skeleton.get_bone_pose(0).is_equal_approx(first_second),"Animating one enemy never changes another enemy's skeleton")
 print("Geometry: ",Model.geometry_counts,"; vertices=",vertices.size(),"; triangles=",vertices.size()/3)
 actor.free();second.free()
 print("%s: %d detailed creature mesh, bind, material and animation checks"%["PASS" if failures==0 else "FAIL",checks])
 quit(1 if failures else 0)
