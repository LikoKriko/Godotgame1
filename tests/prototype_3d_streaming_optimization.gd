extends SceneTree
const Cover=preload("res://scripts/prototype_3d/ground_cover.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var shapes:Array=[]
 for variant in 15:shapes.append(Cover.mesh_for(variant).surface_get_arrays(0))
 var records:Array=[{"position":Vector2(1290,412),"variant":0,"width":16.0},{"position":Vector2(1300,435),"variant":2,"width":11.0},{"position":Vector2(1320,460),"variant":0,"width":18.0}]
 var origin:=Vector2(32,0);var data:Dictionary=Cover.build_arrays(records,origin,shapes)
 require(data.arrays[Mesh.ARRAY_VERTEX].size()==63,"Every original blade remains in the merged draw surface")
 var counts:Dictionary={};var index:=0
 for record in records:
  var variant:int=record.variant;var i:int=counts.get(variant,0);counts[variant]=i+1
  var rotation:=Basis(Vector3.UP,float(i%13)*.57)
  var basis:=rotation.scaled(Vector3.ONE*(record.width*Cover.UNIT/.4))
  var point:Vector2=record.position*Cover.UNIT
  for v in 21:
   var expected:Vector3=basis*shapes[variant][Mesh.ARRAY_VERTEX][v]+Vector3(point.x,.01,point.y)
   require((data.arrays[Mesh.ARRAY_VERTEX][index]+data.origin).distance_to(expected)<.00001,"Baking preserves each tuft's position, shape, rotation and scale")
   require(data.arrays[Mesh.ARRAY_TEX_UV][index]==shapes[variant][Mesh.ARRAY_TEX_UV][v],"Original grass UVs are preserved")
   index+=1
 var sampler=preload("res://scripts/terrain_sampler.gd").new();sampler.configure(73129,preload("res://scripts/terrain_profile.gd").new())
 var layout=preload("res://scripts/prototype_3d/stream_layout.gd").new();layout.configure(73129,sampler)
 var worker=preload("res://scripts/prototype_3d/chunk_builder.gd").new();worker.configure(layout)
 for key in [Vector2i(12,-9),Vector2i(-18,15)]:
  var exact:Dictionary=layout.chunk(key);worker.request(key)
  var ready:Dictionary={};var deadline:=Time.get_ticks_msec()+5000
  while ready.is_empty() and Time.get_ticks_msec()<deadline:ready=worker.collect();await process_frame
  require(not ready.is_empty() and ready.key==key,"The background job completes the requested coordinate")
  if ready.is_empty():continue
  require(var_to_str(ready.data.resources)==var_to_str(exact.resources),"Worker preserves every resource ID, type, position and reward")
  require(var_to_str(ready.data.grass)==var_to_str(exact.grass),"Worker preserves the exact seeded grass distribution")
  require(ready.data.grass_mesh.arrays[Mesh.ARRAY_VERTEX].size()==exact.grass.size()*21,"Only packed geometry data is returned from the worker")
 worker.request(Vector2i(40,40));worker.finish()
 require(worker.worker==null and worker.result.is_empty(),"Unload joins an active job without leaving stale results")
 var plant=preload("res://scripts/prototype_3d/gatherable.gd")
 for kind in [4,5]:
  var a=plant.new();var b=plant.new();root.add_child(a);root.add_child(b)
  var record:Dictionary={"kind":kind,"variant":2,"hits":1,"yield":3}
  a.configure(record);b.configure(record)
  var ma:MeshInstance3D=a.find_children("*","MeshInstance3D",true,false)[0]
  var mb:MeshInstance3D=b.find_children("*","MeshInstance3D",true,false)[0]
  require(ma.mesh==mb.mesh,"Matching static plants share their baked mesh rather than recreating components")
  a.free();b.free()
 var rock=preload("res://scripts/prototype_3d/rock.gd").new();root.add_child(rock);rock.configure()
 require(not rock.is_processing(),"Settled resource rocks do not run per-frame callbacks")
 rock.hit();require(rock.is_processing(),"A hit wakes the existing shake animation")
 rock._process(.3);require(not rock.is_processing() and is_zero_approx(rock.visual.rotation.z),"The final shake frame restores rest and suspends its callback")
 rock.free()
 print("%s: %d worker, geometry, sharing and idle-resource checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
