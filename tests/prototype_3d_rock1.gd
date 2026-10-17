extends SceneTree
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run() -> void:
 var layout=preload("res://scripts/prototype_3d/world_layout.gd").new();layout.generate(73129)
 var sampler=preload("res://scripts/terrain_sampler.gd").new();sampler.configure(73129,preload("res://scripts/terrain_profile.gd").new())
 var stream=preload("res://scripts/prototype_3d/stream_layout.gd").new();stream.configure(73129,sampler)
 var records:Array=layout.records.duplicate();var extended:=0
 for x in range(2,8):
  for z in range(2,8):
   for record in stream.chunk(Vector2i(x,z),false).resources:
    if record.kind==1:records.append(record);extended+=1
 require(extended>0,"Test covers rocks generated beyond the original clearing")
 var count:=0
 for record in records:
  if record.kind!=1:continue
  count+=1
  require(record.height==1.0 and not record.hand_collectable,"Every world rock1 is one metre and not a hand-carried pebble")
 var rock=preload("res://scripts/prototype_3d/rock.gd").new();root.add_child(rock);rock.configure()
 var visual:MeshInstance3D=rock.visual.get_child(0)
 require(absf(visual.mesh.get_aabb().size.y*visual.scale.y*rock.scale.y-1)<.000001,"Native mesh and world instance are exactly one metre high")
 require((visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size()/3==5163,"Runtime uses the optimized source")
 require(rock.get_child(0).shape.size.is_equal_approx(visual.mesh.get_aabb().size*Vector3(.86,.94,.86)),"Collision follows the optimized geometry at its only world size")
 var hits:int=rock.health
 for i in hits:require(rock.hit(),"Mining still accepts valid hits")
 require(rock.health==0 and not rock.visible and rock.collision_layer==0,"Depleted rock stops rendering and blocking")
 rock.queue_free();await process_frame
 print("%s: %d rock1 checks across %d world records"%["PASS" if failures==0 else "FAIL",checks,count]);quit(1 if failures else 0)
