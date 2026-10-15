shader_type spatial;
render_mode cull_front, unshaded;
uniform float thickness = 0.085;
// Alpha is an outline mask, not skin transparency. Buried shoulder roots must
// not project their own dark contour onto the continuous chest surface.
void vertex() { VERTEX += NORMAL * thickness * COLOR.a; }
void fragment() {
 // Zero-width roots otherwise leave coplanar black backfaces on the chest.
 // This mask belongs only to the outline pass; the skin stays fully opaque.
 if (COLOR.a < 0.98) { discard; }
 ALBEDO = vec3(0.065,0.048,0.034);
}
