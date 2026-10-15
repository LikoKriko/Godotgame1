shader_type spatial;
uniform sampler2D bark : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D leaves : source_color, filter_nearest_mipmap, repeat_disable;
void fragment() {
 bool leaf=UV2.x>0.5;
 vec3 detail=leaf?texture(leaves,UV).rgb:texture(bark,UV).rgb;
 // Restrained pixel grain supplements the geometry; it does not replace leaves
 // with a painted sphere or borrow skin/cloth textures from another species.
 float grain=dot(detail,vec3(0.2126,0.7152,0.0722));
 ALBEDO=COLOR.rgb*(leaf?(0.80+grain*0.28):(0.55+grain*0.50));
 ROUGHNESS=0.98;
}
