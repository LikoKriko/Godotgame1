extends Node3D
## Chipped cutting silhouette, bevels and split angular wood; anchors never move.
const Meshes=preload("res://scripts/prototype_3d/prop_mesh.gd")
const GRIP:=Vector3(0,4,0)
const CONTACT:=Vector3(11,24,0)
func _ready() -> void:build()
func build() -> void:
 var wood:=Meshes.material(&"wood",Color("93633c"));var stone:=Meshes.material(&"stone",Color("9c978e"));var rope:=Meshes.material(&"rope",Color("b5ab78"))
 for side in [-1,1]:
  Meshes.polyline(self,PackedVector3Array([Vector3(side*0.6,0,0),Vector3(side*0.7,8,0.15),Vector3(side*0.45,17,-0.1),Vector3(side*0.75,25,0),Vector3(side*0.9,31.5,0.35)]),PackedFloat32Array([0.75,0.8,0.7,0.9,0.68]),wood)
 var polygon:=PackedVector2Array([Vector2(0,21),Vector2(1.5,29),Vector2(4.1,29.6),Vector2(6.6,28.8),Vector2(8.5,27.5),Vector2(9.8,25.8),Vector2(11,24),Vector2(10.4,22.4),Vector2(8.5,19.5),Vector2(6.2,18.9),Vector2(3.8,19.6),Vector2(2,20)])
 Meshes.beveled_blade(self,polygon,1.1,stone)
 Meshes.bindings(self,22.2,1.7)
 for side in [-1,1]:Meshes.segment(self,Vector3(-1.8,20.1,side*1.2),Vector3(4.2,28.1,side*1.2),0.32,rope)
