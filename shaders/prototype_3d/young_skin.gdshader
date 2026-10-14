shader_type spatial;
render_mode cull_disabled;
uniform sampler2D materials : source_color, filter_nearest_mipmap, repeat_disable;
void fragment(){
 ALBEDO=COLOR.rgb;
 if(UV2.x>=0.0){
  vec3 reference=UV2.y>=0.5 ? (UV2.x>=0.5 ? vec3(0.725,0.502,0.427) : vec3(0.604,0.608,0.255)) : (UV2.x>=0.5 ? vec3(0.667,0.635,0.529) : vec3(0.518,0.376,0.314));
  ALBEDO*=clamp(texture(materials,UV2).rgb/max(reference,vec3(0.08)),vec3(0.72),vec3(1.28));
 }
 ROUGHNESS=0.97;
}
