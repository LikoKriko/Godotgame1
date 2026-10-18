extends SceneTree
## Bake handle cross sections once; never scan tool geometry during animation.
func _initialize():call_deferred("run")
func run():
 var shafts:Dictionary={}
 for family in [&'axe',&'pickaxe']:
  var mesh:Mesh=load('res://assets/models/meshy/'+String(family)+'/model.res')
  var sections:Array[Vector3]=[]
  for height in [0.0,4.95]:
   var samples:Array[Vector2]=[]
   for surface in mesh.get_surface_count():
    var vertices:PackedVector3Array=mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
    for point in vertices:
     if absf(point.y-height)<.60 and absf(point.x)<2.5:samples.append(Vector2(point.x,point.z))
   assert(not samples.is_empty())
   var bounds:=Rect2(samples[0],Vector2.ZERO)
   for point in samples:bounds=bounds.expand(point)
   var center:=bounds.get_center();var distances:Array[float]=[]
   for point in samples:distances.append(point.distance_to(center))
   distances.sort()
   sections.append(Vector3(center.x,center.y,distances[int((distances.size()-1)*.95)]))
  shafts[family]=sections
 shafts[&'sword']=[Vector3(0,0,1.20),Vector3(0,0,1.20)]
 var data:=Resource.new();data.set_meta('shafts',shafts)
 assert(ResourceSaver.save(data,'res://data/animation/characters/hand_grips.tres')==OK)
 var actor=load('res://scripts/prototype_3d/survivor_model.gd').new();root.add_child(actor)
 var palms:Dictionary={}
 for family in [&'axe',&'pickaxe',&'sword']:
  actor.family_override=family;actor.animate(&'idle',0,true)
  var offsets:Array[Basis]=[]
  for side in 2:offsets.append(actor.grip_socket.basis.inverse()*actor.rig.posed[6+side*3].basis.orthonormalized())
  palms[family]=offsets
 data.set_meta('palms',palms)
 assert(ResourceSaver.save(data,'res://data/animation/characters/hand_grips.tres')==OK)
 actor.free();print(shafts);quit()
