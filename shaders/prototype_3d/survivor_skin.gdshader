shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Original UV maps. Vertex alpha marks skin only; hair/cloth retain full detail.
uniform sampler2D albedo_map : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_nearest_mipmap, repeat_enable;
uniform sampler2D roughness_map : hint_default_white, filter_nearest_mipmap, repeat_enable;
uniform sampler2D metallic_map : hint_default_black, filter_nearest_mipmap, repeat_enable;
uniform float skin_normal_strength : hint_range(0.0,1.0) = 0.15;
void fragment() {
 ALBEDO = texture(albedo_map, UV).rgb;
 ROUGHNESS = texture(roughness_map, UV).r;
 METALLIC = texture(metallic_map, UV).r;
 NORMAL_MAP = texture(normal_map, UV).rgb;
 NORMAL_MAP_DEPTH = mix(1.0, skin_normal_strength, COLOR.a);
}
