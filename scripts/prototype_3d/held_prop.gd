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
  for x in [-0.55,0.55]:Meshes.polyline(self,PackedVector3Array([Vector3(x,-4,0),Vector3(x*1.1,3,0.15),Vector3(x*0.9,top*0.6,-0.1),Vector3(x,top,0)]),PackedFloat32Array([0.65,0.72,0.67,0.72]),wood)
  if family==&"pickaxe":
   # Broad chipped rear stone and tapered working point from pico1_3d.png.
   Meshes.beveled_blade(self,PackedVector2Array([Vector2(-13,18),Vector2(-13.5,19.5),Vector2(-12.2,22),Vector2(-10,24),Vector2(-7,25.4),Vector2(-4,25.8),Vector2(-1.1,24.7),Vector2(-1.5,21),Vector2(-4,19.5),Vector2(-8,18.2),Vector2(-11,17.8)]),1.8,stone)
   Meshes.beveled_blade(self,PackedVector2Array([Vector2(1.1,25),Vector2(2.8,26.7),Vector2(5.2,26.3),Vector2(7.8,25.2),Vector2(10,23.7),Vector2(12,21),Vector2(9,21.7),Vector2(6,22),Vector2(3.1,21),Vector2(1.2,21.4)]),1.6,stone)
   var binding:=Meshes.material(&"rope",Color("b9b47c"))
   for z in [-2.0,2.0]:
    for offset in [-0.55,0.0,0.55]:
     Meshes.segment(self,Vector3(-2.5,25+offset,z),Vector3(2.4,20+offset,z),0.28,binding)
     Meshes.segment(self,Vector3(-2.4,20+offset,z),Vector3(2.5,25+offset,z),0.28,binding)
   Meshes.bindings(self,18.7,1.7)
  else:
   Meshes.beveled_blade(self,PackedVector2Array([Vector2(-1.8,9),Vector2(-3,13.5),Vector2(-3.2,16),Vector2(-2.6,20.5),Vector2(-1.5,25),Vector2(0,29),Vector2(1.7,25.5),Vector2(2.6,21.8),Vector2(3.1,16),Vector2(2.9,13),Vector2(1.8,9)]),0.55,stone)
   Meshes.bindings(self,7.5);Meshes.bindings(self,1.5,1.45)
 elif family==&"bow":
  var points:=PackedVector3Array();var radii:=PackedFloat32Array()
  for i in 13:
   var t:=i/12.0;points.append(Vector3(0,lerpf(-14,14,t),sin(t*PI)*4-4))
   radii.append(0.32 if i in [0,12] else (0.72 if i in [5,6,7] else 0.48))
  Meshes.polyline(self,points,radii,wood,6)
  for y in [-12.5,12.5]:Meshes.bindings(self,y,0.55)
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
