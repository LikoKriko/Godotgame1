extends StaticBody3D
## Four real legs cast their shadows directly onto the ground.
const Meshes=preload("res://scripts/prototype_3d/prop_mesh.gd")
const SIZE:=Vector3(1.2,0.875,0.7)
const PARTS:=[
 [Vector3(0,0.82,0),Vector3(1.2,0.11,0.7)],
 [Vector3(-0.48,0.4,-0.24),Vector3(0.09,0.8,0.09)],
 [Vector3(-0.48,0.4,0.24),Vector3(0.09,0.8,0.09)],
 [Vector3(0.48,0.4,-0.24),Vector3(0.09,0.8,0.09)],
 [Vector3(0.48,0.4,0.24),Vector3(0.09,0.8,0.09)],
 [Vector3(0,0.23,-0.24),Vector3(1.0,0.07,0.06)],
 [Vector3(0,0.23,0.24),Vector3(1.0,0.07,0.06)]
]
var uid:=-1
func _ready() -> void:
 add_to_group("prototype_workbenches");set_meta("physical_height",SIZE.y)
 var wood:Material=Meshes.material(&"wood",Color("7f6240")).duplicate();wood.next_pass=wood.next_pass.duplicate();wood.next_pass.set_shader_parameter("thickness",0.003)
 for record in PARTS:part(record[0],record[1],wood)
func part(point:Vector3,size:Vector3,paint:Material) -> void:
 var mesh:=BoxMesh.new();mesh.size=size
 var visual:=MeshInstance3D.new();visual.mesh=mesh;visual.material_override=paint;visual.position=point;add_child(visual)
 var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;collision.shape=shape;collision.position=point;add_child(collision)
