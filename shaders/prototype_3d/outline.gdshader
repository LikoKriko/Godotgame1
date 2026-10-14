shader_type spatial;
render_mode cull_front, unshaded;
uniform float thickness = 0.16;
void vertex() { VERTEX += NORMAL * thickness; }
void fragment() { ALBEDO = vec3(0.065,0.048,0.034); }
