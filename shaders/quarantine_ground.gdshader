shader_type canvas_item;
render_mode unshaded;
uniform vec3 ambient_tint = vec3(1.0);

uniform float map_seed = 73129.0;
varying vec2 world_position;
uniform vec4 dirt_patch_0;
uniform vec4 dirt_patch_1;
uniform vec4 dirt_patch_2;
uniform vec4 dirt_patch_3;
uniform sampler2D grass_reference : filter_nearest, repeat_enable;
uniform sampler2D soil_reference : filter_nearest, repeat_enable;
uniform sampler2D dirt_reference_a : filter_nearest, repeat_enable;
uniform sampler2D dirt_reference_b : filter_nearest, repeat_enable;
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

// Shared corner samples meet with identical weights at cell boundaries. Each
// sample rotates and offsets the reference, avoiding visible tile joins.
vec3 quilt(sampler2D source, vec2 p, float span, vec4 region) {
	vec2 tile = floor(p / span);
	vec2 blend = fract(p / span);
	blend = blend * blend * (3.0 - 2.0 * blend);
	vec3 result = vec3(0.0);
	for (int y = 0; y < 2; y++) {
		for (int x = 0; x < 2; x++) {
			vec2 anchor = tile + vec2(float(x),float(y));
			float rotation = floor(hash(anchor + 173.0) * 4.0);
			vec2 uv = p / span;
			if (rotation < 1.0) uv = uv;
			else if (rotation < 2.0) uv = vec2(-uv.y,uv.x);
			else if (rotation < 3.0) uv = -uv;
			else uv = vec2(uv.y,-uv.x);
			uv = fract(uv + vec2(hash(anchor + 17.0),hash(anchor + 71.0)));
			float weight = (x == 0 ? 1.0 - blend.x : blend.x) * (y == 0 ? 1.0 - blend.y : blend.y);
			result += texture(source,region.xy + uv * region.zw).rgb * weight;
		}
	}
	return result;
}

void fragment() {
	// Continuous woodland soil: restrained grass and earth, independent of cells.
	vec2 position = floor(world_position);
	float grain = (hash(floor(position / 2.0)) - 0.5) * 0.010;
	vec3 reference = quilt(grass_reference,position,144.0,vec4(0.0,0.0,1.0,1.0));
	vec3 ground = mix(vec3(0.245,0.302,0.207),reference,0.36);
	// Quiet two-unit blades bridge the large soil color and the tuft sprites.
	vec2 blade_cell = floor(position/vec2(4.0,6.0));
	vec2 blade_pixel = mod(position,vec2(4.0,6.0));
	float fine_blade = step(0.70,hash(blade_cell+91.0))*step(abs(blade_pixel.x-1.0),0.5)*step(blade_pixel.y,2.0);
	ground += vec3(-0.006,0.009,-0.003)*fine_blade;
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
	if (path > 0.0) {
		vec3 trail = quilt(soil_reference,position,90.0,vec4(0.04,0.44,0.88,0.12));
		ground = mix(ground,trail + vec3(soil_variation),path);
	}
	// Low-contrast light and shade hint at small rises without obscuring props.
	float slope = smooth_noise((position + vec2(-12.0, -18.0)) / 110.0) - smooth_noise((position + vec2(12.0, 18.0)) / 110.0);
	ground += vec3(slope * 0.035 + grain);
	float dirt = max(max(patch_mask(position,dirt_patch_0),patch_mask(position,dirt_patch_1)),max(patch_mask(position,dirt_patch_2),patch_mask(position,dirt_patch_3))) * (1.0-path);
	if (dirt > 0.0) {
		vec3 a = quilt(dirt_reference_a,position,100.0,vec4(0.43,0.30,0.10,0.36));
		vec3 b = quilt(dirt_reference_b,position,100.0,vec4(0.46,0.46,0.10,0.10));
		ground = mix(ground,mix(a,b,smooth_noise(position/310.0)),dirt);
	}
	COLOR = vec4(ground*ambient_tint, 1.0);
}
