shader_type spatial;
// Only the three leader rings at the root junction sample both UV unwraps.
// The rest of the branching tree uses the transferred bark directly.
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D metallic_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D delivered_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D delivered_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D delivered_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D delivered_metallic : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float branch_normal_strength = 0.25;
uniform float source_normal_strength = 0.65;

void fragment() {
 vec3 albedo = texture(albedo_map, UV).rgb;
 float roughness = texture(roughness_map, UV).r;
 float metallic = texture(metallic_map, UV).r;
 vec3 detail = texture(normal_map, UV).rgb * 2.0 - 1.0;
 detail.xy *= branch_normal_strength;
 vec3 shading = normalize(TANGENT * detail.x + BINORMAL * detail.y + NORMAL * detail.z);
 float blend = COLOR.a;
 // Evaluate derivatives before the conditional.
 vec3 dp1 = dFdx(VERTEX), dp2 = dFdy(VERTEX);
 vec2 duv1 = dFdx(UV2), duv2 = dFdy(UV2);
 if (blend > 0.0001) {
  albedo = mix(albedo, texture(delivered_albedo, UV2).rgb, blend);
  roughness = mix(roughness, texture(delivered_roughness, UV2).r, blend);
  metallic = mix(metallic, texture(delivered_metallic, UV2).r, blend);
  float det = duv1.x * duv2.y - duv1.y * duv2.x;
  if (abs(det) > 0.00000001) {
   vec3 t0 = (dp1 * duv2.y - dp2 * duv1.y) / det;
   vec3 b0 = (dp2 * duv1.x - dp1 * duv2.x) / det;
   vec3 t = normalize(t0 - NORMAL * dot(NORMAL, t0));
   vec3 b = normalize(cross(NORMAL, t)) * sign(dot(cross(NORMAL, t), b0));
   vec3 original = texture(delivered_normal, UV2).rgb * 2.0 - 1.0;
   original.xy *= source_normal_strength;
   shading = normalize(mix(shading, normalize(t * original.x + b * original.y + NORMAL * original.z), blend));
  }
 }
 ALBEDO = albedo;
 ROUGHNESS = roughness;
 METALLIC = metallic;
 NORMAL_MAP = normalize(vec3(dot(shading, TANGENT), dot(shading, BINORMAL), dot(shading, NORMAL))) * 0.5 + 0.5;
 NORMAL_MAP_DEPTH = 1.0;
}
