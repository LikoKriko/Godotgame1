shader_type canvas_item;
render_mode unshaded;

uniform float map_seed = 73129.0;
varying vec2 world_position;
uniform vec4 stone_patch_0;
uniform vec4 stone_patch_1;
uniform vec4 stone_patch_2;
uniform vec4 stone_patch_3;
float patch_mask(vec2 p, vec4 patch) {
	return 1.0-smoothstep(0.85,1.06,length((p-patch.xy)/max(patch.zw,vec2(1.0))));
}

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
	vec3 earth = vec3(0.245, 0.270, 0.205);
	vec3 grass = vec3(0.235, 0.295, 0.205);
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
	// Short blades form an even carpet. Random centers and leaning strands
	// break the cell layout; muted gray-green edges keep props readable.
	float rocky = max(max(patch_mask(position,stone_patch_0),patch_mask(position,stone_patch_1)),max(patch_mask(position,stone_patch_2),patch_mask(position,stone_patch_3)))*(1.0-path);
	float stone_grain = hash(floor(position/5.0));
	vec2 gravel = fract(position/8.0)-vec2(0.5);
	float shape = max(abs(gravel.x)*0.9,abs(gravel.y)*1.2);
	float pebble = 1.0-smoothstep(0.29,0.40,shape+abs(gravel.x+gravel.y)*0.15);
	vec3 stone_color = mix(vec3(0.258,0.270,0.254),vec3(0.308,0.318,0.299),pebble)+vec3((stone_grain-0.5)*0.025);
	ground = mix(ground,stone_color,rocky);
	float coverage = (1.0 - path)*(1.0-rocky);
	vec2 cell = floor(position / 9.0);
	float edge = 0.0;
	float lit = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = cell + vec2(float(x), float(y));
			float random = hash(neighbor + 19.0);
			vec2 center = (neighbor + vec2(hash(neighbor + 4.0), hash(neighbor + 31.0))) * 9.0;
			vec2 offset = position - center;
			float height = 2.0 + random * 3.0;
			float lean = (hash(neighbor + 47.0) - 0.5) * 0.9;
			float strand = abs(offset.x + offset.y * lean);
			float stem = step(-height, offset.y) * step(offset.y, 0.0);
			edge = max(edge, step(strand, 0.85) * stem);
			lit = max(lit, step(strand, 0.42) * stem * step(-height+0.8, offset.y));
			float side = abs(offset.x - 1.7 + offset.y * (lean - 0.55));
			edge = max(edge, step(side, 0.65) * stem * step(-height+1.0,offset.y));
		}
	}
	ground = mix(ground,vec3(0.205,0.237,0.209),edge*coverage*0.46);
	ground += vec3(0.025,0.032,0.012)*lit*coverage;
	COLOR = vec4(ground, 1.0);
}
