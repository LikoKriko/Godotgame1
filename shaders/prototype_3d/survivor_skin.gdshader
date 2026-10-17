shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
// Source UV maps stay intact. R: hair, G: face, A: body skin.
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_map : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D metallic_map : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D face_detail_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float skin_normal_strength : hint_range(0.0,1.0) = 0.15;
uniform float face_normal_strength : hint_range(0.0,1.0) = 0.4;
uniform float face_detail_strength : hint_range(0.0,0.2) = 0.055;
void fragment() {
 if (!FRONT_FACING) { NORMAL = -NORMAL; }
 vec3 texel = texture(albedo_map, UV).rgb;
 // Repair skin-colored projection flecks only inside the baked hair mask.
 float misplaced_skin = smoothstep(0.25,0.40,texel.r)*smoothstep(0.35,0.45,texel.g/max(texel.r,0.0001));
 vec3 hair_color = vec3(0.035,0.012,0.005)*(0.9+0.2*texel.r);
 ALBEDO = mix(texel,hair_color,COLOR.r*misplaced_skin);
 ROUGHNESS = texture(roughness_map, UV).r;
 METALLIC = texture(metallic_map, UV).r;
 ROUGHNESS = mix(ROUGHNESS,max(ROUGHNESS,0.85),COLOR.r);
 METALLIC *= 1.0-COLOR.r;
 vec3 normal = texture(normal_map, UV).rgb;
 vec2 detail = (texture(face_detail_map,UV*12.0).rg*2.0-1.0)*face_detail_strength*COLOR.g;
 NORMAL_MAP = vec3(clamp(normal.rg+detail*0.5,vec2(0.0),vec2(1.0)),normal.b);
 NORMAL_MAP_DEPTH = mix(mix(1.0,skin_normal_strength,COLOR.a),face_normal_strength,COLOR.g);
}
