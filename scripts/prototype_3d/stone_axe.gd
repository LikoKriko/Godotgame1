extends Node3D
## Supplied Meshy axe, with real palm and cutting-edge anchors.
const IMPORTED=preload("res://assets/models/meshy/axe/model.res")
const Anchors=preload("res://assets/models/meshy/axe/anchors.gd")
const GRIP:=Vector3(0,4,0)
const CONTACT:=Anchors.TIP+GRIP
func _ready() -> void:build()
func build() -> void:
 if get_child_count()>0:return
 var mesh:=MeshInstance3D.new();mesh.mesh=IMPORTED;mesh.position=GRIP;add_child(mesh)
