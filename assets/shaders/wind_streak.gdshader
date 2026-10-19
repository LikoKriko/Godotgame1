shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, world_vertex_coords, shadows_disabled;
uniform vec3 wind_direction = vec3(0.0, 0.0, -1.0);
uniform vec2 observer;
uniform float visible_radius = 10.0;
uniform float streak_length = 0.65;
uniform float streak_width = 0.012;
uniform float opacity = 0.018;
uniform float visibility_weight = 1.0;
uniform vec3 tint : source_color = vec3(0.78, 0.82, 0.8);
varying vec3 streak_world;
void vertex() {
 vec3 center = MODEL_MATRIX[3].xyz;
 vec3 side = cross(wind_direction, CAMERA_POSITION_WORLD - center);
 if (dot(side, side) < 0.0001) { side = cross(wind_direction, vec3(0.0, 1.0, 0.0)); }
 side = normalize(side);
 VERTEX = center + wind_direction * (UV.y - 0.5) * streak_length + side * (UV.x - 0.5) * streak_width;
 streak_world = VERTEX;
}
void fragment() {
 float radius = length(streak_world.xz - observer);
 float radial = 1.0 - smoothstep(visible_radius * 0.60, visible_radius, radius);
 float along = sin(clamp(UV.y, 0.0, 1.0) * 3.14159265);
 float across = smoothstep(0.0, 0.4, UV.x) * (1.0 - smoothstep(0.6, 1.0, UV.x));
 ALBEDO = tint;
 ALPHA = opacity * visibility_weight * radial * along * across * COLOR.a;
}
