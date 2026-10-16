extends Node3D
## Solid category-specific props, all rooted at the same palm socket.
const Meshes=preload("res://scripts/prototype_3d/prop_mesh.gd")
var family:StringName=&""
var item_id:StringName=&""
var string_segments:Array[Node3D]=[]
var imported_bow:MeshInstance3D
var rest_nock:=Vector3(0,0,-4)
var string_top:=Vector3(0,11.3,-5.627856)
var string_bottom:=Vector3(0,-12.5,-5.627856)
var nocked:Node3D
var liquid:MeshInstance3D
var item_nodes:Dictionary={}
func configure(value:StringName) -> void:
 family=value
 var wood:=Meshes.material(&"wood",Color("a27a4e"));var stone:=Meshes.material(&"stone",Color("c6c1b6"));var rope:=Meshes.material(&"rope",Color("c5bc82"))
 if family==&"pickaxe":
  var model:=MeshInstance3D.new();model.mesh=preload("res://assets/models/meshy/pickaxe/model.res");add_child(model)
 elif family==&"sword":
  for x in [-0.55,0.55]:Meshes.polyline(self,PackedVector3Array([Vector3(x,-4,0),Vector3(x*1.1,3,0.15),Vector3(x*0.9,6,-0.1),Vector3(x,10,0)]),PackedFloat32Array([0.65,0.72,0.67,0.72]),wood)
  Meshes.beveled_blade(self,PackedVector2Array([Vector2(-1.8,9),Vector2(-3,13.5),Vector2(-3.2,16),Vector2(-2.6,20.5),Vector2(-1.5,25),Vector2(0,29),Vector2(1.7,25.5),Vector2(2.6,21.8),Vector2(3.1,16),Vector2(2.9,13),Vector2(1.8,9)]),0.55,stone)
  Meshes.bindings(self,7.5);Meshes.bindings(self,1.5,1.45)
 elif family==&"bow":
  imported_bow=MeshInstance3D.new();imported_bow.mesh=preload("res://assets/models/meshy/bow/deformable.res");imported_bow.custom_aabb=AABB(Vector3(-25,-25,-40),Vector3(50,50,55));add_child(imported_bow)
  rest_nock=imported_bow.mesh.get_meta("rest_nock")
  # Logical contact anchors only; the actual rope belongs to the supplied mesh.
  for i in 2:
   var anchor:=Node3D.new();anchor.name="StringContact%d"%i;add_child(anchor);string_segments.append(anchor)
  nocked=make_arrow();add_child(nocked);nocked.hide()
 elif family==&"bottle":
  var bottle:=MeshInstance3D.new()
  bottle.mesh=preload("res://assets/items/prototype_3d/bottle_meshy/bottle.res")
  add_child(bottle)
 elif family==&"food":
  var apple:=Node3D.new();add_child(apple);item_nodes[&"apple"]=apple
  Meshes.sphere(apple,Vector3.ZERO,Vector3(1.8,1.9,1.6),Meshes.material(&"plain",Color("ac3e2f")))
  Meshes.segment(apple,Vector3(0,1.6,0),Vector3(0.2,2.5,0),0.16,wood)
  var berries:=Node3D.new();add_child(berries);item_nodes[&"berries"]=berries
  for i in 5:Meshes.sphere(berries,Vector3(sin(i*2.4),float(i%2)*0.7,cos(i*2.4))*0.9,Vector3.ONE*0.85,Meshes.material(&"plain",Color("505378")))
  var ration:=Node3D.new();add_child(ration);item_nodes[&"ration"]=ration
  Meshes.sphere(ration,Vector3.ZERO,Vector3(2.7,1.4,1.1),Meshes.material(&"leather",Color("b69b65")))
func update_pose(state:StringName,phase:float,support:Vector3,nock_visible:bool=false,target:Vector3=Vector3.INF) -> void:
 if family!=&"bow":return
 var pull:=clampf(phase,0,1) if state==&"draw" else 0.0
 var hand:=rest_nock
 if state==&"draw":hand=hand.lerp(support,smoothstep(.08,.26,phase))
 if state==&"bow_release":hand.z+=sin(phase*PI*6)*exp(-phase*5)*.8
 Meshes.orient_segment(string_segments[0],string_bottom,hand,0.11)
 Meshes.orient_segment(string_segments[1],hand,string_top,0.11)
 var displacement:=hand-rest_nock
 for axis in 3:imported_bow.set_blend_shape_value(axis,displacement[axis])
 imported_bow.set_blend_shape_value(3,smoothstep(1,12,maxf(0,-displacement.z)))
 nocked.visible=nock_visible and state==&"draw" and phase>=.26
 nocked.position=hand; nocked.rotation=Vector3.ZERO
 if state==&"draw" and target.is_finite():nocked.basis=Basis.looking_at(target-hand,Vector3.UP,true)
 # The arrow is a solid shaft, not a one-pixel screen-space line.
 nocked.scale=Vector3.ONE*lerpf(0.95,1,pull)
func show_item(id:StringName,water_ml:int=0) -> void:
 item_id=id
 for key in item_nodes:item_nodes[key].visible=key==id
 if liquid!=null:liquid.visible=water_ml>0;liquid.scale.y=1.0 if water_ml>=500 else 0.5
static func make_arrow() -> Node3D:
 var node:=Node3D.new();var wood:=Meshes.material(&"wood",Color("ba935f"))
 Meshes.segment(node,Vector3.ZERO,Vector3(0,0,23),0.16,wood)
 var head:=Meshes.slab(node,PackedVector2Array([Vector2(-1.1,20),Vector2(0,24),Vector2(1.1,20),Vector2(0,21)]),0.25,Meshes.material(&"stone",Color("c4c0b5")))
 head.rotation.x=PI/2
 for sign_side in [-1,1]:
  Meshes.segment(node,Vector3(0,0,1),Vector3(sign_side*1.3,0,3.5),0.25,Meshes.material(&"plain",Color("cbc3a5")))
 return node
