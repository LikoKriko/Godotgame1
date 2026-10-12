shader_type canvas_item;
uniform float head_bottom = -22.0;
varying float world_y;
void vertex() { world_y = (MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).y; }
void fragment() { if (world_y < head_bottom) { discard; } }
