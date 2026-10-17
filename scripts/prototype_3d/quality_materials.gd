extends RefCounted
## Mip bias implements a resolution budget without making texture copies each tick.
var shaders:Dictionary={}
var variants:Dictionary={}
var uniform_names:Dictionary={}
func forget(source:Material) -> void:
 if source==null:return
 var prefix:=str(source.get_instance_id())+":"
 for key in variants.keys():
  if key.begins_with(prefix):variants.erase(key)
const PARAM:=&"distance_quality"
static func bias(percent:int) -> float:return -log(maxf(.01,percent/100.0))/log(2.0)
func material(source:Material,percent:int,current:Material=null) -> Material:
 if source==null:return null
 if source is ShaderMaterial and current is ShaderMaterial and current!=source:
  for name in parameters(source.shader):source.set_shader_parameter(name,current.get_shader_parameter(name))
 if percent>=100:return source
 var key:=str(source.get_instance_id())+":"+str(percent)
 if variants.has(key):
  var result:ShaderMaterial=variants[key]
  if source is ShaderMaterial:copy_parameters(source,result)
  return result
 var result:=ShaderMaterial.new()
 if source is ShaderMaterial:
  var id:int=source.shader.get_instance_id()
  if not shaders.has(id):
   var shader:=Shader.new()
   var code:String=source.shader.code
   code=code.replace("filter_nearest,","filter_nearest_mipmap,").replace("filter_nearest;","filter_nearest_mipmap;")
   code=code.replace("shader_type spatial;","shader_type spatial;\nuniform float distance_quality = 1.0;")
   # GLES requires a separate function for samplers with different hints.
   var samplers:=RegEx.new();samplers.compile("uniform\\s+sampler2D\\s+(\\w+)[^;]*;")
   var helpers:="\n"
   for sampler in samplers.search_all(code):
    var name:String=sampler.get_string(1)
    var calls:=RegEx.new();calls.compile("\\btexture\\s*\\(\\s*"+name+"\\s*,")
    code=calls.sub(code,"quality_texture_"+name+"(",true)
    helpers+="vec4 quality_texture_%s(vec2 uv) { return texture(%s,uv,-log2(max(distance_quality,0.01))); }\n"%[name,name]
   var declarations:=RegEx.new();declarations.compile("uniform\\s+[^;]*;")
   var uniforms:=declarations.search_all(code)
   var insertion:int=uniforms[-1].get_end()
   code=code.insert(insertion,helpers)
   shader.code=code;shaders[id]=shader
  result.shader=shaders[id];copy_parameters(source,result)
 elif source is StandardMaterial3D:
  result.shader=standard_shader(source)
  standard_parameters(source,result)
 else:return source
 result.set_shader_parameter(PARAM,percent/100.0)
 result.set_meta("distance_quality_variant",true)
 result.render_priority=source.render_priority
 if source.next_pass!=null:result.next_pass=material(source.next_pass,percent)
 variants[key]=result
 return result
func parameters(shader:Shader) -> Array[StringName]:
 var id:=shader.get_instance_id()
 if not uniform_names.has(id):
  var names:Array[StringName]=[]
  for uniform in shader.get_shader_uniform_list():names.append(uniform.name)
  uniform_names[id]=names
 return uniform_names[id]
func copy_parameters(source:ShaderMaterial,target:ShaderMaterial) -> void:
 for name in parameters(source.shader):target.set_shader_parameter(name,source.get_shader_parameter(name))
static func channel(value:int) -> Vector4:
 return [Vector4(1,0,0,0),Vector4(0,1,0,0),Vector4(0,0,1,0),Vector4(0,0,0,1),Vector4(.333333,.333333,.333333,0)][clampi(value,0,4)]
func standard_shader(source:StandardMaterial3D) -> Shader:
 var key:="standard:%d:%d:%d:%d:%s"%[source.cull_mode,source.shading_mode,source.transparency,source.texture_filter,source.texture_repeat]
 if shaders.has(key):return shaders[key]
 var modes:="cull_back" if source.cull_mode==0 else ("cull_front" if source.cull_mode==1 else "cull_disabled")
 if source.shading_mode==0:modes+=",unshaded"
 var shader:=Shader.new()
 shader.code="""shader_type spatial;
render_mode %s;
uniform float distance_quality = 1.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool vertex_tint = false;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform sampler2D albedo_map : source_color, filter_nearest_mipmap;
uniform sampler2D metallic_map : filter_linear_mipmap;
uniform sampler2D roughness_map : filter_linear_mipmap;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap;
uniform sampler2D emission_map : source_color, filter_linear_mipmap;
uniform bool has_albedo = false;
uniform bool has_metallic = false;
uniform bool has_roughness = false;
uniform bool has_normal = false;
uniform bool has_emission = false;
uniform float metal = 0.0;
uniform float rough = 1.0;
uniform float normal_strength = 1.0;
uniform float specular = 0.5;
uniform vec4 metallic_channel = vec4(1.0,0.0,0.0,0.0);
uniform vec4 roughness_channel = vec4(1.0,0.0,0.0,0.0);
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_energy = 1.0;
uniform float alpha_threshold = 0.5;
void fragment() {
 vec2 uv=UV*uv_scale.xy+uv_offset.xy;
 float bias=-log2(max(distance_quality,0.01));
 vec4 color=tint;
 if(vertex_tint) color*=COLOR;
 if(has_albedo) color*=texture(albedo_map,uv,bias);
 ALBEDO=color.rgb;
 METALLIC=metal*(has_metallic?dot(texture(metallic_map,uv,bias),metallic_channel):1.0);
 ROUGHNESS=rough*(has_roughness?dot(texture(roughness_map,uv,bias),roughness_channel):1.0);
 SPECULAR=specular;
 if(has_normal) { NORMAL_MAP=texture(normal_map,uv,bias).rgb; NORMAL_MAP_DEPTH=normal_strength; }
 if(has_emission) EMISSION=emission_color*emission_energy*texture(emission_map,uv,bias).rgb;
 %s
}
"""%[modes,("ALPHA=color.a; ALPHA_SCISSOR_THRESHOLD=alpha_threshold;" if source.transparency==2 else ("ALPHA=color.a;" if source.transparency!=0 else ""))]
 var filtering:="filter_nearest_mipmap" if source.texture_filter%2==0 else "filter_linear_mipmap"
 var repeat:="repeat_enable" if source.texture_repeat else "repeat_disable"
 shader.code=shader.code.replace("filter_nearest_mipmap;",filtering+", "+repeat+";").replace("filter_linear_mipmap;",filtering+", "+repeat+";")
 shaders[key]=shader
 return shader
static func standard_parameters(source:StandardMaterial3D,target:ShaderMaterial) -> void:
 var parameters:={"tint":source.albedo_color,"vertex_tint":source.vertex_color_use_as_albedo,"uv_scale":source.uv1_scale,"uv_offset":source.uv1_offset,"metal":source.metallic,"rough":source.roughness,"specular":source.metallic_specular,"normal_strength":source.normal_scale,"metallic_channel":channel(source.metallic_texture_channel),"roughness_channel":channel(source.roughness_texture_channel),"alpha_threshold":source.alpha_scissor_threshold,"emission_color":source.emission,"emission_energy":source.emission_energy_multiplier}
 for name in parameters:target.set_shader_parameter(name,parameters[name])
 for row in [["albedo","albedo_texture"],["metallic","metallic_texture"],["roughness","roughness_texture"],["normal","normal_texture"],["emission","emission_texture"]]:
  var texture:Texture2D=source.get(row[1])
  target.set_shader_parameter(row[0]+"_map",texture)
  target.set_shader_parameter("has_"+row[0],texture!=null and (row[0]!="normal" or source.normal_enabled) and (row[0]!="emission" or source.emission_enabled))
