extends SceneTree
const Controller=preload("res://scripts/prototype_3d/distance_optimization.gd")
const Policy=preload("res://scripts/prototype_3d/distance_quality.gd")
class CameraRig extends Node3D:
 var camera:=Camera3D.new()
 func _init():add_child(camera)
class World extends Node3D:
 var player:=Node3D.new()
 var camera_rig:=CameraRig.new()
 var environment_content:Node3D
 var paused:=false
 var loading_state:=false
 func _init():add_child(player);add_child(camera_rig)
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func ticks(controller,count:int=6) -> void:
 for i in count:controller._process(1.0/60)
func run():
 var world:=World.new();root.add_child(world)
 var controller:=Controller.new();world.add_child(controller);controller.configure(world);controller.set_process(false)
 var mesh:=BoxMesh.new();var nodes:Array[MeshInstance3D]=[]
 for i in 60:
  var node:=MeshInstance3D.new();node.mesh=mesh;node.position=Vector3(0,0,-10);world.add_child(node);controller.register(weakref(node));nodes.append(node)
 ticks(controller,1)
 var changed:=0
 for entry in controller.entries.values():
  if not entry.state.is_empty():changed+=1
 require(changed>0 and changed<60,"A frame samples only its share of the sweep")
 ticks(controller,5)
 for entry in controller.entries.values():require(entry.quality==100,"Every object is sampled within a tenth second under normal load")
 var started:float=controller.quality_clock
 ticks(controller,2)
 var cursor_before:int=controller.cursor
 for i in 12:
  var node:MeshInstance3D=nodes.pop_front();controller.unregister(node.get_instance_id());node.free()
 require(controller.cursor==mini(cursor_before,controller.scheduled.size()),"Unloading old chunks preserves progress instead of restarting the sweep")
 for i in 9:
  var node:=MeshInstance3D.new();node.mesh=mesh;world.add_child(node);controller.register(weakref(node));nodes.append(node)
 ticks(controller)
 require(controller.scheduled.size()==controller.entries.size(),"Streaming keeps one schedule slot per live entry")
 for entry in controller.entries.values():require(entry.sampled_at>started,"Removal and insertion do not starve the remaining entries")
 var node:=nodes[0];var entry:Dictionary=controller.entries[node.get_instance_id()]
 node.position=Vector3(0,0,-50);ticks(controller)
 require(entry.quality==80,"Staggered sampling preserves the fifty-metre distance threshold")
 node.position.z=50;ticks(controller)
 require(entry.quality==50,"The opposite camera hemisphere retains its fifty-percent cap")
 world.camera_rig.camera.rotation.y=PI
 var expected:Dictionary=entry.state.duplicate(true);var sampled:float=entry.sampled_at
 for i in 24:
  ticks(controller,1)
  if entry.sampled_at!=sampled:
   var percent:=Policy.advance(expected,50,false,entry.sampled_at-sampled)
   require(entry.quality==percent,"Recovery uses each object's elapsed time and the original ten-point steps")
   sampled=entry.sampled_at
 require(entry.quality==80,"Recovery stops at the current distance budget")
 var clock:float=controller.quality_clock;var state:Dictionary=entry.state.duplicate(true)
 world.paused=true;controller._process(5)
 require(controller.quality_clock==clock and entry.state==state,"Pausing does not accumulate hidden recovery time")
 world.loading_state=true;ticks(controller)
 require(controller.quality_clock>clock,"Initial loading can still prepare visual budgets while paused")
 world.paused=false;world.loading_state=false
 var parent:=Node3D.new();world.add_child(parent);node.reparent(parent);parent.position=Vector3(0,0,-70);ticks(controller)
 require(entry.quality==100,"Cached local centres still follow a moving parent transform")
 for target in nodes:
  controller.unregister(target.get_instance_id());target.free()
 ticks(controller)
 require(controller.scheduled.is_empty() and controller.entries.is_empty() and controller.cursor==0,"An emptied streaming window leaves no stale schedule references")
 world.free()
 print("%s: %d quality scheduling, streaming and recovery checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
