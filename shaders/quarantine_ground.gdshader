shader_type canvas_item;
render_mode unshaded;

uniform vec2 map_size = vec2(2048.0, 1536.0);
uniform vec2 map_origin = vec2(-1024.0, -768.0);
uniform float map_seed = 73129.0;

float hash(vec2 position) {
	return fract(sin(dot(position, vec2(127.1, 311.7)) + map_seed * 0.013) * 43758.5453);
}

float smooth_noise(vec2 position) {
	vec2 cell = floor(position);
	vec2 blend = fract(position);
	blend = blend * blend * (3.0 - 2.0 * blend);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), blend.x), blend.y);
}

void fragment() {
	// World-space detail spans the entire yard, independent of collision cells.
	vec2 position = floor((UV * map_size + map_origin) / 3.0) * 3.0;
	float dust = (smooth_noise(position / 230.0) - 0.5) * 0.018;
	float grain = (hash(floor(position / 3.0)) - 0.5) * 0.006;
	vec3 charcoal = vec3(0.135, 0.143, 0.162);
	COLOR = vec4(charcoal + vec3(dust + grain), 1.0);
}
