extends SceneTree
const Policy=preload("res://scripts/prototype_3d/distance_quality.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 if DisplayServer.get_name()=="headless":print("SKIP: GPU grass quality requires a native renderer");quit();return
 root.size=Vector2i(128,128)
 var view:=SubViewport.new();view.size=Vector2i(128,64);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 var camera:=Camera3D.new();camera.position=Vector3(0,0,3);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2;view.add_child(camera)
 var code:String=load("res://shaders/prototype_3d/grass_batch.gdshader").code
 code=code.replace("render_mode cull_disabled;","render_mode cull_disabled, unshaded;")
 code=code.replace("vec3 center=(MODEL_MATRIX*vec4(UV2.x,0.01,UV2.y,1.0)).xyz;","vec3 center=vec3(0.0);")
 code=code.substr(0,code.find("void fragment()"))+"void fragment() { ALBEDO=vec3(exp2(-mip_bias)); }"
 var gpu:=ShaderMaterial.new();gpu.shader=Shader.new();gpu.shader.code=code
 var reference:=ShaderMaterial.new();reference.shader=Shader.new();reference.shader.code="shader_type spatial; render_mode unshaded; uniform float budget=1.0; void fragment() { ALBEDO=vec3(budget); }"
 for side in 2:
  var mesh:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(.7,.7);mesh.mesh=quad;mesh.position.x=-.5 if side==0 else .5;mesh.material_override=gpu if side==0 else reference;view.add_child(mesh)
 var history:=PackedVector4Array();var directions:=PackedVector4Array();var state:Dictionary={}
 var points:Array=[]
 for distance in [0,29,30,39,40,49,50,64,65,74,75,89,90,120]:points.append({"distance":float(distance),"rear":false})
 points.append({"distance":60.0,"rear":true})
 for i in 8:points.append({"distance":60.0,"rear":false})
 for i in 18:points.append({"distance":51.0 if i%3==0 else 28.0,"rear":i%4==0})
 for sample in points:
  var observer:=Vector3(0,0,-sample.distance);var forward:=Vector3.FORWARD if sample.rear else Vector3.BACK
  var percent:=Policy.advance(state,sample.distance,sample.rear and sample.distance>=50,.1)
  history.append(Vector4(observer.x,observer.y,observer.z,.1));directions.append(Vector4(forward.x,forward.y,forward.z,0))
  if history.size()>8:history.remove_at(0);directions.remove_at(0)
  var positions:=history.duplicate();var axes:=directions.duplicate();positions.resize(8);axes.resize(8)
  gpu.set_shader_parameter("observers",positions);gpu.set_shader_parameter("forwards",axes);gpu.set_shader_parameter("history_count",history.size());reference.set_shader_parameter("budget",percent/100.0)
  for frame in 2:await process_frame;await RenderingServer.frame_post_draw
  var picture:=view.get_texture().get_image()
  var actual:=picture.get_pixel(48,32);var expected:=picture.get_pixel(80,32)
  require(absf(actual.r-expected.r)<=2.0/255,"GPU grass quality follows distance, rear cap and gradual recovery: "+str(sample))
 view.free();print("%s: %d GPU grass budget and recovery comparisons"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
