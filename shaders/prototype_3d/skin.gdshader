shader_type spatial;
render_mode cull_disabled;
void fragment() {
 ALBEDO = COLOR.rgb;
 ROUGHNESS = 0.95;
}
