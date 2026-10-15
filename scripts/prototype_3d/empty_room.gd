extends Node3D
## A small streamed fragment: shared empty timber floor, no separate viewport.
func _ready() -> void:
 var mesh:=BoxMesh.new();mesh.size=Vector3(4,0.04,4)
 var floor_mesh:=MeshInstance3D.new();floor_mesh.mesh=mesh;floor_mesh.position.y=-0.01
 floor_mesh.material_override=preload("res://scripts/prototype_3d/prop_mesh.gd").material(&"wood",Color("715534"));add_child(floor_mesh)
 var body:=StaticBody3D.new();body.position.y=-0.01;add_child(body)
 var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=mesh.size;collision.shape=shape;body.add_child(collision)
