shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
	float diffuse = max(dot(normalize(NORMAL), normalize(vec3(-0.25,0.7,0.6))),0.0);
	float light = 0.80 + floor(diffuse*4.0)/4.0*0.25;
	ALBEDO = COLOR.rgb * light;
}
