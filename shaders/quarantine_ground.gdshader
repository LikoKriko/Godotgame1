shader_type canvas_item;
render_mode unshaded;

uniform float map_seed = 73129.0;
varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

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
	// Continuous woodland soil: restrained grass and earth, independent of cells.
	vec2 position = floor(world_position);
	float vegetation = smooth_noise(position / 290.0);
	float grain = (hash(floor(position / 2.0)) - 0.5) * 0.010;
	vec3 earth = vec3(0.30, 0.29, 0.235);
	vec3 grass = vec3(0.265, 0.325, 0.235);
	vec3 ground = mix(earth, grass, smoothstep(0.12, 0.88, vegetation));
	// Gently winding trails stay inside the map's clear central corridors.
	float horizontal_bend = 24.0 * sin(position.x / 210.0) + 10.0 * sin(position.x / 93.0);
	float vertical_bend = 24.0 * sin(position.y / 245.0) - 10.0 * sin(position.y / 110.0);
	float distance_to_path = min(abs(position.y - horizontal_bend), abs(position.x - vertical_bend));
	float edge_noise = (smooth_noise(position / 38.0) - 0.5) * 12.0;
	float path_width = 44.0 + smooth_noise(position / 180.0) * 12.0;
	float path = 1.0 - smoothstep(path_width - 4.0, path_width + 14.0, distance_to_path + edge_noise);
	float path_edge = (1.0 - smoothstep(path_width + 14.0, path_width + 27.0, distance_to_path + edge_noise)) - path;
	ground -= vec3(0.013, 0.017, 0.011) * path_edge;
	float soil_variation = (smooth_noise(position / 65.0) - 0.5) * 0.020;
	ground = mix(ground, vec3(0.355, 0.325, 0.265) + vec3(soil_variation), path);
	// Low-contrast light and shade hint at small rises without obscuring props.
	float slope = smooth_noise((position + vec2(-12.0, -18.0)) / 110.0) - smooth_noise((position + vec2(12.0, 18.0)) / 110.0);
	ground += vec3(slope * 0.035 + grain);
	// Sparse, finer grass blades and small pebbles avoid a repeated tile pattern.
	vec2 detail_cell = floor(position / 18.0);
	vec2 detail_point = fract(position / 18.0) * 18.0;
	float random = hash(detail_cell + vec2(19.0, 7.0));
	vec2 center = vec2(4.0 + random * 10.0, 4.0 + hash(detail_cell + 41.0) * 10.0);
	vec2 offset = detail_point - center;
	float blade = step(abs(offset.x + offset.y * 0.35), 0.85) * step(abs(offset.y), 2.6);
	float tuft = blade * step(0.74, random) * (1.0 - path);
	ground += vec3(-0.012, 0.018, -0.008) * tuft;
	float pebble = (1.0 - smoothstep(0.7, 1.6, length(offset * vec2(0.9, 1.25)))) * step(0.90, random);
	ground += vec3(0.025, 0.021, 0.014) * pebble;
	float leaf = step(abs(offset.x - offset.y), 0.7) * step(abs(offset.y), 1.5) * step(random, 0.035) * (1.0 - path);
	ground += vec3(0.025, 0.003, -0.013) * leaf;
	COLOR = vec4(ground, 1.0);
}
