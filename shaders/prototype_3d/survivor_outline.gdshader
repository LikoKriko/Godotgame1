shader_type spatial;
render_mode cull_front, unshaded;
uniform float thickness = 0.085;
// Alpha is an outline mask, not skin transparency. Buried shoulder roots must
// not project their own dark contour onto the continuous chest surface.
void vertex() { VERTEX += NORMAL * thickness * COLOR.a; }
void fragment() { ALBEDO = vec3(0.065,0.048,0.034); }
