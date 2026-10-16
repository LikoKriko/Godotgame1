shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 distance_to_edge = abs(UV - vec2(0.5)) * 2.0;
	float edge = max(distance_to_edge.x, distance_to_edge.y);
	float vignette = smoothstep(0.96, 1.0, edge);
	COLOR = vec4(0.025, 0.030, 0.023, vignette * 0.18);
}
