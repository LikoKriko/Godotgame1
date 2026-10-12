shader_type spatial;
render_mode unshaded, cull_disabled;
uniform bool protect_bow_arm = false;
uniform bool debug_left_arm = false;
uniform sampler2D body_mask : filter_nearest;
uniform sampler2D head_reference : filter_nearest;
uniform vec4 reference_rect;
void fragment() {
	if (protect_bow_arm && UV.x > 0.5 && UV.x < 1.5 && texture(body_mask,SCREEN_UV).a > 0.5) discard;
	float diffuse = max(dot(normalize(NORMAL), normalize(vec3(-0.25,0.7,0.6))),0.0);
	float light = 0.80 + floor(diffuse*4.0)/4.0*0.25;
	vec3 skin = COLOR.rgb;
	if (UV.x > 2.5) {
		vec4 paint = texture(head_reference,reference_rect.xy+UV2*reference_rect.zw);
		if (paint.a < 0.22) discard;
		skin = paint.rgb;
		// Harmonize face skin with the body palette while retaining eye/hair art.
		if (paint.r > 0.52 && paint.g > 0.30 && paint.r > paint.g*1.15 && paint.g > paint.b*1.15) {
			float shade = clamp(paint.r/0.88,0.65,1.22);
			skin = COLOR.rgb*shade;
		}
	}
	ALBEDO = debug_left_arm && UV.x > 0.5 && UV.x < 1.5 ? vec3(1,0,1) : skin * light;
}
