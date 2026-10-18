shader_type sky;
render_mode disable_fog;
uniform vec3 zenith : source_color;
uniform vec3 horizon : source_color;
void sky() {
 float height = clamp(EYEDIR.y, 0.0, 1.0);
 COLOR = mix(horizon, zenith, pow(height, 0.55));
}
