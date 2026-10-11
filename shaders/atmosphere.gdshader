shader_type canvas_item;
render_mode unshaded;

void fragment() {
	float distance_to_center = length((UV - vec2(0.5)) * vec2(1.0, 0.8));
	float vignette = smoothstep(0.18, 0.62, distance_to_center);
	COLOR = vec4(0.028, 0.018, 0.055, vignette * 0.40);
}
