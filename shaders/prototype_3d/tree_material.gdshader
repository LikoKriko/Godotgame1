shader_type spatial;
uniform sampler2D bark : source_color, filter_nearest_mipmap, repeat_disable;
uniform sampler2D leaves : source_color, filter_nearest_mipmap, repeat_disable;
void fragment(){
 bool leaf=COLOR.g>COLOR.r*1.03;
 vec3 detail=leaf ? texture(leaves,UV*0.44+vec2(0.03,0.53)).rgb : texture(bark,UV*0.44+vec2(0.53,0.03)).rgb;
 ALBEDO=COLOR.rgb*(0.88+dot(detail,vec3(0.2126,0.7152,0.0722))*0.24);
 ROUGHNESS=1.0;
}
