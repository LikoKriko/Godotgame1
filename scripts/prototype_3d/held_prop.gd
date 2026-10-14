extends Node3D
## Solid category-specific props, all rooted at the same palm socket.
const Meshes=preload("res://scripts/prototype_3d/prop_mesh.gd")
var family:StringName=&""
var item_id:StringName=&""
var string_segments:Array[MeshInstance3D]=[]
var nocked:Node3D
var liquid:MeshInstance3D
var item_nodes:Dictionary={}
func configure(value:StringName) -> void:
 family=value
 var wood:=Meshes.material(&"wood",Color("a27a4e"));var stone:=Meshes.material(&"stone",Color("c6c1b6"));var rope:=Meshes.material(&"rope",Color("c5bc82"))
 if family in [&"pickaxe",&"sword"]:
  var top:=27.0 if family==&"pickaxe" else 10.0
  for x in [-0.55,0.55]:Meshes.segment(self,Vector3(x,-4,0),Vector3(x,top,0),0.72,wood)
  if family==&"pickaxe":
   Meshes.slab(self,PackedVector2Array([Vector2(-13,18),Vector2(-11,23),Vector2(-5,26),Vector2(0,25),Vector2(5,27),Vector2(10,24),Vector2(12,21),Vector2(5,23),Vector2(0,21),Vector2(-6,20)]),1.25,stone)
   Meshes.bindings(self,22)
  else:
   Meshes.slab(self,PackedVector2Array([Vector2(-3,9),Vector2(-5.6,15),Vector2(-3,23),Vector2(0,29),Vector2(3.7,24),Vector2(5.4,14),Vector2(3,9)]),0.95,stone)
   Meshes.bindings(self,7.5);Meshes.bindings(self,1.5,1.45)
 elif family==&"bow":
  var previous:=Vector3(0,-14,-4)
  for i in range(1,17):
   var t:=i/16.0;var point:=Vector3(0,lerpf(-14,14,t),sin(t*PI)*4-4)
   Meshes.segment(self,previous,point,0.45 if i in [1,16] else 0.65,wood);previous=point
  Meshes.bindings(self,0,1.0)
  for i in 2:string_segments.append(Meshes.segment(self,Vector3.ZERO,Vector3.UP,0.11,rope))
  nocked=make_arrow();add_child(nocked);nocked.hide()
 elif family==&"bottle":
  Meshes.sphere(self,Vector3(0,1,0),Vector3(2.8,4.4,1.7),Meshes.material(&"leather",Color("ac713b")))
  Meshes.segment(self,Vector3(0,4,0),Vector3(0,7,0),0.85,wood);Meshes.bindings(self,4.3,1.0)
  Meshes.segment(self,Vector3(-2.2,-1.7,1.5),Vector3(2.2,-1.7,1.5),0.16,rope)
  liquid=Meshes.sphere(self,Vector3(0,1,1.65),Vector3(1.7,2.3,0.12),Meshes.material(&"plain",Color("477a8d")));liquid.hide()
 elif family==&"food":
  var apple:=Node3D.new();add_child(apple);item_nodes[&"apple"]=apple
  Meshes.sphere(apple,Vector3.ZERO,Vector3(1.8,1.9,1.6),Meshes.material(&"plain",Color("ac3e2f")))
  Meshes.segment(apple,Vector3(0,1.6,0),Vector3(0.2,2.5,0),0.16,wood)
  var berries:=Node3D.new();add_child(berries);item_nodes[&"berries"]=berries
  for i in 5:Meshes.sphere(berries,Vector3(sin(i*2.4),float(i%2)*0.7,cos(i*2.4))*0.9,Vector3.ONE*0.85,Meshes.material(&"plain",Color("505378")))
  var ration:=Node3D.new();add_child(ration);item_nodes[&"ration"]=ration
  Meshes.sphere(ration,Vector3.ZERO,Vector3(2.7,1.4,1.1),Meshes.material(&"leather",Color("b69b65")))
func update_pose(state:StringName,phase:float,support:Vector3,nock_visible:bool=false) -> void:
 if family!=&"bow":return
 var pull:=clampf(phase,0,1) if state==&"draw" else 0.0
 var hand:=support if state==&"draw" else Vector3(0,0,-4)
 Meshes.orient_segment(string_segments[0],Vector3(0,-14,-4),hand,0.11)
 Meshes.orient_segment(string_segments[1],hand,Vector3(0,14,-4),0.11)
 nocked.visible=nock_visible and state==&"draw"
 nocked.position=hand; nocked.rotation=Vector3.ZERO
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
