shader_type spatial;
render_mode cull_disabled;
uniform sampler2D painted_materials : source_color, filter_linear_mipmap, repeat_disable;
uniform bool use_painted_materials = false;
void fragment() {
 ALBEDO = COLOR.rgb;
 if (use_painted_materials && UV2.x >= 0.0) {
  vec3 painted = texture(painted_materials,UV2).rgb;
  // Retain the authored palette; the atlas adds local hand-painted detail.
  vec3 reference = UV2.y >= 0.5 ? (UV2.x >= 0.5 ? vec3(0.502,0.329,0.169) : vec3(0.259,0.169,0.118)) : (UV2.x >= 0.5 ? vec3(0.376,0.302,0.2) : vec3(0.816,0.549,0.333));
  ALBEDO = COLOR.rgb * clamp(painted / max(reference,vec3(0.08)),vec3(0.72),vec3(1.28));
 }
 ROUGHNESS = 0.95;
}
