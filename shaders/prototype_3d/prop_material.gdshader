shader_type spatial;
uniform sampler2D source : source_color, filter_nearest_mipmap, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0);
uniform vec4 patch = vec4(0.44,0.44,0.53,0.03);
void fragment(){
 vec3 detail=texture(source,UV*patch.xy+patch.zw).rgb;
 float value=dot(detail,vec3(0.2126,0.7152,0.0722));
 ALBEDO=tint*mix(0.83,1.13,value);
 ROUGHNESS=1.0;
}
