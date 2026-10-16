extends Node3D
## Short sword tip ribbon and contact flash; no unrelated particle emitters.
var game
var samples:Array[Dictionary]=[]
var ribbon:=MeshInstance3D.new()
var flashes:Array[Dictionary]=[]
var paint:=StandardMaterial3D.new()
func _ready() -> void:
 paint.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;paint.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;paint.vertex_color_use_as_albedo=true;paint.cull_mode=BaseMaterial3D.CULL_DISABLED
 ribbon.material_override=paint;add_child(ribbon)
func track_tip(point:Vector3,active:bool) -> void:
 if active:samples.append({"point":point,"age":0.0})
 elif samples.size()>0:samples[-1].age=maxf(0.06,samples[-1].age)
func flash(point:Vector3) -> void:
 var node:=MeshInstance3D.new();var mesh:=SphereMesh.new();mesh.radius=0.025;mesh.height=0.05;mesh.radial_segments=8;mesh.rings=4;node.mesh=mesh
 var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.albedo_color=Color("eee5c4");node.material_override=material;add_child(node);node.global_position=point
 flashes.append({"node":node,"age":0.0,"paint":material})
func _process(delta:float) -> void:
 if game!=null and game.paused:return
 for sample in samples:sample.age+=delta
 samples=samples.filter(func(sample):return sample.age<0.1)
 var surface:=ImmediateMesh.new()
 if samples.size()>1:
  surface.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
  for sample in samples:
   var point:Vector3=sample.point
   var width:=Vector3.UP*0.018
   surface.surface_set_color(Color(0.92,0.89,0.76,(1-sample.age/0.1)*0.38));surface.surface_add_vertex(point-width);surface.surface_add_vertex(point+width)
  surface.surface_end()
 ribbon.mesh=surface
 for entry in flashes.duplicate():
  entry.age+=delta;entry.node.scale=Vector3.ONE*(1+entry.age*10);entry.paint.albedo_color.a=maxf(0,1-entry.age/0.12)
  if entry.age>=0.12:entry.node.queue_free();flashes.erase(entry)
