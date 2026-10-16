shader_type spatial;
render_mode cull_back;
uniform sampler2D normal_ground : filter_nearest, repeat_disable;
uniform sampler2D dark_ground : filter_nearest, repeat_disable;
uniform sampler2D vegetation_ground : filter_nearest, repeat_disable;
uniform sampler2D dirt_ground : filter_nearest, repeat_disable;
uniform uint seed_value = 73129u;
uniform vec3 ambient_tint = vec3(1.0);
uniform vec3 thresholds = vec3(0.57,0.64,0.70);
uniform float region_scale = 720.0;
uniform float transition_width = 0.028;
uniform float texture_span = 144.0;
uniform float pixel_step = 1.0;
uniform bool existing_paths = false;
uniform int influence_count = 0;
uniform vec4 influence_rects[32];
uniform vec2 influence_types[32];
uniform sampler2D biome_mask : filter_linear, repeat_disable;
uniform vec2 mask_origin;
uniform vec2 mask_size;
uniform float mask_step = 8.0;
varying vec2 world_position;
void vertex() {world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xz/(1.75/64.0);}
float hash_at(vec2 p) {
 uint n = (uint(int(p.x))*374761393u) ^ (uint(int(p.y))*668265263u) ^ seed_value;
 n = (n ^ (n >> 13u))*1274126177u; n = n ^ (n >> 16u);
 return float(n & 0x00ffffffu)/16777215.0;
}
float noise_at(vec2 p) {
 vec2 cell = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
 return mix(mix(hash_at(cell),hash_at(cell+vec2(1.0,0.0)),f.x),mix(hash_at(cell+vec2(0.0,1.0)),hash_at(cell+vec2(1.0)),f.x),f.y);
}
float field(vec2 p) { p /= region_scale; return noise_at(p)*0.70+noise_at(p*2.17+vec2(37.0,19.0))*0.22+noise_at(p*5.31+vec2(-11.0,73.0))*0.08; }
// Shared overlapping sample anchors never reach the rectangular source edges.
// Sampling is nearest and pixel-aligned; blending changes colors, not pixel geometry.
vec3 quilt(vec2 point,vec4 weights) {
 vec2 warp = vec2(noise_at(point/210.0),noise_at(point/210.0+79.0))*0.30-0.15;
 vec2 p = point/texture_span+warp;
 vec2 cell = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
 vec3 color = vec3(0.0);
 for(int y=0;y<2;y++) {
  for(int x=0;x<2;x++) {
   vec2 anchor = cell+vec2(float(x),float(y));
   vec2 local = p-anchor;
   float rotation = floor(hash_at(anchor+97.0)*4.0);
   if(rotation >= 3.0) local = vec2(local.y,-local.x);
   else if(rotation >= 2.0) local = -local;
   else if(rotation >= 1.0) local = vec2(-local.y,local.x);
   vec2 offset = vec2(hash_at(anchor+17.0),hash_at(anchor+51.0))*0.16-0.08;
   vec2 uv = 0.5+local*0.28+offset;
   float weight = (x==0 ? 1.0-f.x : f.x)*(y==0 ? 1.0-f.y : f.y);
   vec3 sample_color = vec3(0.0);
   if(weights.x>0.001) sample_color += texture(normal_ground,uv).rgb*weights.x;
   if(weights.y>0.001) sample_color += texture(dark_ground,uv).rgb*weights.y;
   if(weights.z>0.001) sample_color += texture(vegetation_ground,uv).rgb*weights.z;
   if(weights.w>0.001) sample_color += texture(dirt_ground,uv).rgb*weights.w;
   color += sample_color*weight;
  }
 }
 return color;
}
void fragment() {
 vec2 p=floor(world_position/pixel_step)*pixel_step;
 vec2 uv=((p-mask_origin)/mask_step+0.5)/mask_size;
 vec4 weights=textureLod(biome_mask,uv,0.0);
 ALBEDO=quilt(p,weights)*ambient_tint;
 ROUGHNESS=1.0;
}
