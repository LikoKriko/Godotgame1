extends MeshInstance3D
## Shared billboard indicator for timed creature states.
var paint:=ShaderMaterial.new()
func _ready() -> void:
 var quad:=QuadMesh.new();quad.size=Vector2(0.27,0.27);mesh=quad
 paint.shader=preload("res://shaders/prototype_3d/status_pie.gdshader");material_override=paint;hide()
func show_status(remaining:float,total:float,color:Color,camera:Camera3D) -> void:
 visible=remaining>0
 if not visible:return
 paint.set_shader_parameter("remaining",clampf(remaining/maxf(total,0.001),0,1));paint.set_shader_parameter("status_color",color)
 global_basis=camera.global_basis.orthonormalized()
